# UploadRepositoryImpl - Clean Architecture Infrastructure Layer
# Concrete implementation for TestFlight and App Store Connect upload operations

require 'open3'
require 'json'
require 'net/http'
require 'uri'
require 'fileutils'
require_relative '../../domain/repositories/upload_repository'

class UploadRepositoryImpl
  include UploadRepository

  UPLOAD_TIMEOUT = 1800  # 30 minutes for upload operations
  STATUS_CHECK_TIMEOUT = 60  # 1 minute for status checks
  PROCESSING_CHECK_INTERVAL = 30  # Check every 30 seconds
  MAX_RETRY_ATTEMPTS = 3
  
  # Upload methods in priority order
  UPLOAD_METHODS = %w[altool transporter pilot].freeze
  
  # TestFlight processing states
  PROCESSING_STATES = %w[
    PROCESSING_UPLOAD_RECEIVED PROCESSING_STARTED PROCESSING_IN_PROGRESS 
    PROCESSING_COMPLETE PROCESSING_FAILED READY_FOR_BETA_TESTING
  ].freeze
  
  attr_reader :logger, :upload_strategies
  
  # Initialize UploadRepository implementation
  # @param logger [Logger, nil] Optional logger for operations
  # @param upload_strategies [Array<String>] Upload strategies to use in order
  def initialize(logger: nil, upload_strategies: nil)
    @logger = logger
    @upload_strategies = upload_strategies || UPLOAD_METHODS
    @active_uploads = {}
    
    validate_upload_tools
  end
  
  # TestFlight Upload Operations Implementation
  
  # Upload IPA to TestFlight
  # @param ipa_path [String] Path to .ipa file
  # @param api_credentials [ApiCredentials] App Store Connect API credentials
  # @param options [Hash] Upload options (enhanced mode, metadata, etc.)
  # @return [UploadResult] Upload result with status and metadata
  def upload_to_testflight(ipa_path, api_credentials, options = {})
    log_info("Starting TestFlight upload: #{File.basename(ipa_path)}")
    
    # Validate inputs
    validation_result = validate_upload_inputs(ipa_path, api_credentials)
    unless validation_result.valid?
      return create_failed_upload_result("Validation failed: #{validation_result.errors.join(', ')}")
    end
    
    # Generate upload ID
    upload_id = generate_upload_id
    upload_start_time = Time.now
    
    @active_uploads[upload_id] = {
      status: 'initiating',
      ipa_path: ipa_path,
      api_credentials: api_credentials,
      options: options,
      start_time: upload_start_time
    }
    
    # Try each upload method in order
    last_error = nil
    @upload_strategies.each do |method|
      log_info("Attempting upload using #{method}")
      
      begin
        result = attempt_upload_with_method(method, ipa_path, api_credentials, options, upload_id)
        
        if result.success?
          upload_duration = Time.now - upload_start_time
          @active_uploads.delete(upload_id)
          
          log_info("Upload successful via #{method} (#{upload_duration.round(1)}s)")
          return result.with_metadata(
            upload_id: upload_id,
            upload_method: method,
            upload_duration: upload_duration,
            enhanced_mode: options[:enhanced] || false
          )
        else
          last_error = result.error
          log_error("#{method} upload failed: #{result.error}")
        end
      rescue => e
        last_error = e.message
        log_error("#{method} upload error: #{e.message}")
      end
    end
    
    # All methods failed
    @active_uploads.delete(upload_id)
    create_failed_upload_result("All upload methods failed. Last error: #{last_error}")
  end
  
  # Upload to TestFlight with metadata
  # @param ipa_path [String] Path to .ipa file
  # @param api_credentials [ApiCredentials] App Store Connect API credentials
  # @param metadata [TestFlightMetadata] Upload metadata and options
  # @return [UploadResult] Upload result with detailed information
  def upload_with_metadata(ipa_path, api_credentials, metadata)
    options = {
      enhanced: true,
      changelog: metadata.changelog,
      description: metadata.description,
      auto_notify: metadata.auto_notify,
      beta_groups: metadata.beta_groups,
      external_testing: metadata.external_testing
    }
    
    upload_to_testflight(ipa_path, api_credentials, options)
  end
  
  # Status Operations Implementation
  
  # Get upload status by upload ID
  # @param upload_id [String] Upload identifier
  # @return [UploadStatus] Current upload status and progress
  def get_upload_status(upload_id)
    upload_info = @active_uploads[upload_id]
    
    if upload_info.nil?
      return UploadStatus.new(
        upload_id: upload_id,
        status: 'not_found',
        progress: 0,
        message: 'Upload not found or completed'
      )
    end
    
    elapsed_time = Time.now - upload_info[:start_time]
    estimated_progress = calculate_upload_progress(elapsed_time, upload_info[:status])
    
    UploadStatus.new(
      upload_id: upload_id,
      status: upload_info[:status],
      progress: estimated_progress,
      message: get_status_message(upload_info[:status]),
      elapsed_time: elapsed_time
    )
  end
  
  # Get build processing status
  # @param app_identifier [String] Bundle identifier
  # @param build_number [String, Integer] Build number
  # @param api_credentials [ApiCredentials] App Store Connect API credentials
  # @return [ProcessingStatus] Build processing status
  def get_processing_status(app_identifier, build_number, api_credentials)
    log_info("Checking processing status for #{app_identifier} build #{build_number}")
    
    # Use App Store Connect API to check build status
    api_result = query_app_store_connect_api(
      endpoint: 'builds',
      params: {
        'filter[app]' => app_identifier,
        'filter[version]' => build_number.to_s
      },
      credentials: api_credentials
    )
    
    if api_result[:success] && api_result[:data]&.any?
      build_data = api_result[:data].first
      processing_state = build_data.dig('attributes', 'processingState')
      
      ProcessingStatus.new(
        app_identifier: app_identifier,
        build_number: build_number,
        processing_state: processing_state,
        ready_for_testing: processing_state == 'PROCESSING_COMPLETE',
        processing_complete: %w[PROCESSING_COMPLETE PROCESSING_FAILED].include?(processing_state),
        error_details: extract_processing_errors(build_data)
      )
    else
      ProcessingStatus.new(
        app_identifier: app_identifier,
        build_number: build_number,
        processing_state: 'UNKNOWN',
        ready_for_testing: false,
        processing_complete: false,
        error_details: api_result[:error] || 'Build not found'
      )
    end
  rescue => e
    log_error("Error checking processing status: #{e.message}")
    ProcessingStatus.new(
      app_identifier: app_identifier,
      build_number: build_number,
      processing_state: 'ERROR',
      ready_for_testing: false,
      processing_complete: false,
      error_details: e.message
    )
  end
  
  # Wait for processing completion
  # @param app_identifier [String] Bundle identifier
  # @param build_number [String, Integer] Build number
  # @param api_credentials [ApiCredentials] App Store Connect API credentials
  # @param timeout [Integer] Timeout in seconds (default: 600)
  # @return [ProcessingResult] Final processing result
  def wait_for_processing(app_identifier, build_number, api_credentials, timeout = 600)
    log_info("Waiting for processing completion (timeout: #{timeout}s)")
    
    start_time = Time.now
    last_status = nil
    
    while (Time.now - start_time) < timeout
      status = get_processing_status(app_identifier, build_number, api_credentials)
      
      # Log status changes
      if last_status.nil? || last_status.processing_state != status.processing_state
        log_info("Processing status: #{status.processing_state}")
        last_status = status
      end
      
      # Check if processing is complete
      if status.processing_complete?
        duration = Time.now - start_time
        
        return ProcessingResult.new(
          success: status.ready_for_testing?,
          final_status: status.processing_state,
          duration: duration,
          ready_for_testing: status.ready_for_testing?,
          error_details: status.error_details
        )
      end
      
      # Wait before next check
      sleep(PROCESSING_CHECK_INTERVAL)
    end
    
    # Timeout reached
    duration = Time.now - start_time
    ProcessingResult.new(
      success: false,
      final_status: 'TIMEOUT',
      duration: duration,
      ready_for_testing: false,
      error_details: "Processing check timed out after #{timeout} seconds"
    )
  end
  
  # TestFlight Query Operations Implementation
  
  # Get recent TestFlight builds
  # @param app_identifier [String] Bundle identifier
  # @param api_credentials [ApiCredentials] App Store Connect API credentials
  # @param limit [Integer] Maximum number of builds to return
  # @return [Array<TestFlightBuild>] Array of recent builds
  def get_testflight_builds(app_identifier, api_credentials, limit = 10)
    log_info("Fetching TestFlight builds for #{app_identifier}")
    
    api_result = query_app_store_connect_api(
      endpoint: 'builds',
      params: {
        'filter[app]' => app_identifier,
        'limit' => limit.to_s,
        'sort' => '-uploadedDate'
      },
      credentials: api_credentials
    )
    
    if api_result[:success] && api_result[:data]
      builds = api_result[:data].map do |build_data|
        parse_testflight_build(build_data)
      end
      
      log_info("Found #{builds.length} TestFlight builds")
      builds
    else
      log_error("Failed to fetch TestFlight builds: #{api_result[:error]}")
      []
    end
  rescue => e
    log_error("Error fetching TestFlight builds: #{e.message}")
    []
  end
  
  # Get latest TestFlight build
  # @param app_identifier [String] Bundle identifier
  # @param api_credentials [ApiCredentials] App Store Connect API credentials
  # @return [TestFlightBuild, nil] Latest build or nil if none found
  def get_latest_build(app_identifier, api_credentials)
    builds = get_testflight_builds(app_identifier, api_credentials, 1)
    builds.first
  end
  
  # Get build by version and build number
  # @param app_identifier [String] Bundle identifier
  # @param version [String] Marketing version
  # @param build_number [String, Integer] Build number
  # @param api_credentials [ApiCredentials] App Store Connect API credentials
  # @return [TestFlightBuild, nil] Matching build or nil if not found
  def get_build(app_identifier, version, build_number, api_credentials)
    log_info("Looking for build #{version}(#{build_number})")
    
    api_result = query_app_store_connect_api(
      endpoint: 'builds',
      params: {
        'filter[app]' => app_identifier,
        'filter[version]' => build_number.to_s
      },
      credentials: api_credentials
    )
    
    if api_result[:success] && api_result[:data]&.any?
      build_data = api_result[:data].find do |build|
        build.dig('attributes', 'version') == build_number.to_s
      end
      
      build_data ? parse_testflight_build(build_data) : nil
    else
      nil
    end
  rescue => e
    log_error("Error fetching specific build: #{e.message}")
    nil
  end
  
  # Validation Operations Implementation
  
  # Validate IPA before upload
  # @param ipa_path [String] Path to .ipa file
  # @return [ValidationResult] IPA validation result
  def validate_ipa(ipa_path)
    issues = []
    warnings = []
    
    # Check file existence
    unless File.exist?(ipa_path)
      issues << "IPA file not found: #{ipa_path}"
      return ValidationResult.new(valid: false, errors: issues, warnings: warnings)
    end
    
    # Check file size
    file_size = File.size(ipa_path)
    if file_size < 1024 * 1024  # Less than 1MB
      warnings << "IPA file seems unusually small: #{file_size} bytes"
    elsif file_size > 4 * 1024 * 1024 * 1024  # Greater than 4GB
      issues << "IPA file too large: #{file_size} bytes (4GB limit)"
    end
    
    # Check file extension
    unless ipa_path.end_with?('.ipa')
      warnings << "File does not have .ipa extension"
    end
    
    # Check file permissions
    unless File.readable?(ipa_path)
      issues << "IPA file is not readable"
    end
    
    ValidationResult.new(
      valid: issues.empty?,
      errors: issues,
      warnings: warnings
    )
  end
  
  # Validate API credentials
  # @param api_credentials [ApiCredentials] Credentials to validate
  # @return [ValidationResult] Credentials validation result
  def validate_api_credentials(api_credentials)
    issues = []
    warnings = []
    
    # Check required fields
    unless api_credentials.api_key_id
      issues << "API Key ID is required"
    end
    
    unless api_credentials.api_issuer_id
      issues << "API Issuer ID is required"
    end
    
    unless api_credentials.api_key_path
      issues << "API Key path is required"
    end
    
    # Check API key file
    if api_credentials.api_key_path
      unless File.exist?(api_credentials.api_key_path)
        issues << "API key file not found: #{api_credentials.api_key_path}"
      end
      
      unless api_credentials.api_key_path.end_with?('.p8')
        warnings << "API key file should have .p8 extension"
      end
    end
    
    ValidationResult.new(
      valid: issues.empty?,
      errors: issues,
      warnings: warnings
    )
  end
  
  # Repository Information Implementation
  
  # Get repository type/source information
  # @return [String] Repository type identifier
  def repository_type
    'multi_strategy'
  end
  
  # Check if repository is available/accessible
  # @return [Boolean] True if upload service is accessible
  def available?
    @upload_strategies.any? { |strategy| strategy_available?(strategy) }
  end
  
  # Get service status information
  # @return [ServiceStatus] Upload service status and capabilities
  def get_service_status
    strategy_status = @upload_strategies.map do |strategy|
      {
        name: strategy,
        available: strategy_available?(strategy),
        version: get_strategy_version(strategy)
      }
    end
    
    ServiceStatus.new(
      available: available?,
      strategies: strategy_status,
      active_uploads: @active_uploads.length
    )
  end
  
  private
  
  # Validate upload inputs
  def validate_upload_inputs(ipa_path, api_credentials)
    issues = []
    
    # Validate IPA
    ipa_validation = validate_ipa(ipa_path)
    issues.concat(ipa_validation.errors) unless ipa_validation.valid?
    
    # Validate credentials
    creds_validation = validate_api_credentials(api_credentials)
    issues.concat(creds_validation.errors) unless creds_validation.valid?
    
    ValidationResult.new(valid: issues.empty?, errors: issues, warnings: [])
  end
  
  # Attempt upload with specific method
  def attempt_upload_with_method(method, ipa_path, api_credentials, options, upload_id)
    @active_uploads[upload_id][:status] = "uploading_#{method}"
    
    case method
    when 'altool'
      upload_with_altool(ipa_path, api_credentials, options)
    when 'transporter'
      upload_with_transporter(ipa_path, api_credentials, options)
    when 'pilot'
      upload_with_pilot(ipa_path, api_credentials, options)
    else
      create_failed_upload_result("Unknown upload method: #{method}")
    end
  end
  
  # Upload using altool (Apple's command line tool)
  def upload_with_altool(ipa_path, api_credentials, options)
    log_info("Uploading with altool")
    
    cmd = [
      'xcrun altool',
      '--upload-app',
      '--type ios',
      "--file '#{ipa_path}'",
      "--apiKey #{api_credentials.api_key_id}",
      "--apiIssuer #{api_credentials.api_issuer_id}",
      '--verbose'
    ].join(' ')
    
    output, status = run_command_with_timeout(cmd, UPLOAD_TIMEOUT)
    
    if status.success?
      create_successful_upload_result("Upload successful via altool", output)
    else
      create_failed_upload_result("altool upload failed: #{extract_altool_error(output)}")
    end
  end
  
  # Upload using Transporter (Apple's newer tool)
  def upload_with_transporter(ipa_path, api_credentials, options)
    log_info("Uploading with Transporter")
    
    cmd = [
      'xcrun iTMSTransporter',
      '-m upload',
      "-f '#{ipa_path}'",
      "-k #{api_credentials.api_key_id}",
      "-p #{api_credentials.api_issuer_id}",
      '-v eXtreme'
    ].join(' ')
    
    output, status = run_command_with_timeout(cmd, UPLOAD_TIMEOUT)
    
    if status.success? && !output.include?('ERROR')
      create_successful_upload_result("Upload successful via Transporter", output)
    else
      create_failed_upload_result("Transporter upload failed: #{extract_transporter_error(output)}")
    end
  end
  
  # Upload using fastlane pilot
  def upload_with_pilot(ipa_path, api_credentials, options)
    log_info("Uploading with fastlane pilot")
    
    # Create temporary API key file reference
    api_key_env = "FASTLANE_API_KEY_PATH=#{api_credentials.api_key_path}"
    
    cmd = [
      api_key_env,
      'fastlane pilot upload',
      "--ipa '#{ipa_path}'",
      "--api_key_path '#{api_credentials.api_key_path}'",
      '--skip_waiting_for_build_processing',
      '--verbose'
    ].join(' ')
    
    output, status = run_command_with_timeout(cmd, UPLOAD_TIMEOUT)
    
    if status.success?
      create_successful_upload_result("Upload successful via pilot", output)
    else
      create_failed_upload_result("pilot upload failed: #{extract_pilot_error(output)}")
    end
  end
  
  # Query App Store Connect API
  def query_app_store_connect_api(endpoint:, params:, credentials:)
    # This would implement actual App Store Connect API calls
    # For now, we'll simulate API responses
    {
      success: true,
      data: simulate_api_response(endpoint, params),
      error: nil
    }
  rescue => e
    {
      success: false,
      data: nil,
      error: e.message
    }
  end
  
  # Parse TestFlight build from API response
  def parse_testflight_build(build_data)
    attributes = build_data['attributes'] || {}
    
    TestFlightBuild.new(
      build_id: build_data['id'],
      version: attributes['version'],
      build_number: attributes['version'],
      processing_state: attributes['processingState'],
      uploaded_date: Time.parse(attributes['uploadedDate'] || Time.now.iso8601),
      app_identifier: attributes['bundleId'],
      size: attributes['downloadableSize'],
      ready_for_testing: attributes['processingState'] == 'PROCESSING_COMPLETE'
    )
  rescue => e
    log_error("Error parsing TestFlight build: #{e.message}")
    nil
  end
  
  # Utility methods
  
  def generate_upload_id
    "upload_#{Time.now.strftime('%Y%m%d_%H%M%S')}_#{SecureRandom.hex(4)}"
  end
  
  def calculate_upload_progress(elapsed_time, status)
    case status
    when 'initiating' then 5
    when /uploading/ then [20 + (elapsed_time / 30).to_i, 90].min
    when 'processing' then 95
    when 'complete' then 100
    else 0
    end
  end
  
  def get_status_message(status)
    case status
    when 'initiating' then 'Preparing for upload...'
    when /uploading_(.+)/ then "Uploading via #{$1}..."
    when 'processing' then 'Processing on Apple servers...'
    when 'complete' then 'Upload complete'
    else 'Unknown status'
    end
  end
  
  def extract_altool_error(output)
    error_lines = output.lines.select { |line| line.include?('ERROR') || line.include?('Error') }
    error_lines.first&.strip || 'Unknown altool error'
  end
  
  def extract_transporter_error(output)
    error_lines = output.lines.select { |line| line.include?('ERROR') || line.include?('Error') }
    error_lines.first&.strip || 'Unknown Transporter error'
  end
  
  def extract_pilot_error(output)
    error_lines = output.lines.select { |line| line.include?('[ERROR]') || line.include?('Error:') }
    error_lines.first&.strip || 'Unknown pilot error'
  end
  
  def extract_processing_errors(build_data)
    processing_errors = build_data.dig('attributes', 'processingErrors') || []
    processing_errors.map { |error| error['message'] }.join('; ')
  end
  
  def strategy_available?(strategy)
    case strategy
    when 'altool'
      system('which xcrun > /dev/null 2>&1') && system('xcrun altool --help > /dev/null 2>&1')
    when 'transporter'
      system('which xcrun > /dev/null 2>&1') && system('xcrun iTMSTransporter -help > /dev/null 2>&1')
    when 'pilot'
      system('which fastlane > /dev/null 2>&1')
    else
      false
    end
  end
  
  def get_strategy_version(strategy)
    case strategy
    when 'altool'
      output, _ = run_command_with_timeout('xcrun altool --version', 5) rescue 'unknown'
      output.strip
    when 'transporter'
      'iTMSTransporter'
    when 'pilot'
      output, _ = run_command_with_timeout('fastlane --version', 5) rescue 'unknown'
      output.lines.first&.strip || 'unknown'
    else
      'unknown'
    end
  end
  
  def validate_upload_tools
    available_tools = @upload_strategies.select { |strategy| strategy_available?(strategy) }
    
    if available_tools.empty?
      log_error("No upload tools available. Please install Xcode command line tools and/or fastlane")
    else
      log_info("Available upload tools: #{available_tools.join(', ')}")
    end
  end
  
  def simulate_api_response(endpoint, params)
    case endpoint
    when 'builds'
      [{
        'id' => 'build_123',
        'attributes' => {
          'version' => params['filter[version]'] || '1.0.0',
          'bundleId' => params['filter[app]'] || 'com.example.app',
          'processingState' => 'PROCESSING_COMPLETE',
          'uploadedDate' => Time.now.iso8601,
          'downloadableSize' => 15_728_640
        }
      }]
    else
      []
    end
  end
  
  def create_successful_upload_result(message, output = '')
    UploadResult.new(
      success: true,
      message: message,
      upload_logs: output.lines,
      error: nil
    )
  end
  
  def create_failed_upload_result(error_message, output = '')
    UploadResult.new(
      success: false,
      message: 'Upload failed',
      upload_logs: output.lines,
      error: error_message
    )
  end
  
  def run_command_with_timeout(command, timeout = 30)
    log_debug("Executing: #{command.gsub(/apiKey \w+/, 'apiKey [REDACTED]')}")
    
    output = ""
    status = nil
    
    Open3.popen3(command) do |stdin, stdout, stderr, wait_thr|
      stdin.close
      
      begin
        Timeout.timeout(timeout) do
          output = stdout.read + stderr.read
          status = wait_thr.value
        end
      rescue Timeout::Error
        Process.kill('TERM', wait_thr.pid)
        raise "Upload command timed out after #{timeout} seconds"
      end
    end
    
    [output, status]
  end
  
  # Logging methods
  
  def log_info(message)
    @logger&.info("[UploadRepository] #{message}")
  end
  
  def log_error(message)
    @logger&.error("[UploadRepository] #{message}")
  end
  
  def log_debug(message)
    @logger&.debug("[UploadRepository] #{message}")
  end
end

# Supporting classes for upload operations

class UploadResult
  attr_reader :success, :message, :upload_logs, :error, :metadata
  
  def initialize(success:, message:, upload_logs: [], error: nil, metadata: {})
    @success = success
    @message = message
    @upload_logs = upload_logs
    @error = error
    @metadata = metadata
  end
  
  def success?
    @success
  end
  
  def with_metadata(additional_metadata)
    UploadResult.new(
      success: @success,
      message: @message,
      upload_logs: @upload_logs,
      error: @error,
      metadata: @metadata.merge(additional_metadata)
    )
  end
  
  def to_hash
    {
      success: @success,
      message: @message,
      error: @error,
      metadata: @metadata
    }
  end
end

class UploadStatus
  attr_reader :upload_id, :status, :progress, :message, :elapsed_time
  
  def initialize(upload_id:, status:, progress:, message:, elapsed_time: 0)
    @upload_id = upload_id
    @status = status
    @progress = progress
    @message = message
    @elapsed_time = elapsed_time
  end
  
  def in_progress?
    !%w[complete failed not_found].include?(@status)
  end
  
  def to_hash
    {
      upload_id: @upload_id,
      status: @status,
      progress: @progress,
      message: @message,
      elapsed_time: @elapsed_time
    }
  end
end

class ProcessingStatus
  attr_reader :app_identifier, :build_number, :processing_state, :ready_for_testing, :processing_complete, :error_details
  
  def initialize(app_identifier:, build_number:, processing_state:, ready_for_testing:, processing_complete:, error_details: nil)
    @app_identifier = app_identifier
    @build_number = build_number
    @processing_state = processing_state
    @ready_for_testing = ready_for_testing
    @processing_complete = processing_complete
    @error_details = error_details
  end
  
  def ready_for_testing?
    @ready_for_testing
  end
  
  def processing_complete?
    @processing_complete
  end
  
  def failed?
    @processing_state == 'PROCESSING_FAILED'
  end
  
  def to_hash
    {
      app_identifier: @app_identifier,
      build_number: @build_number,
      processing_state: @processing_state,
      ready_for_testing: @ready_for_testing,
      processing_complete: @processing_complete,
      error_details: @error_details
    }
  end
end

class ProcessingResult
  attr_reader :success, :final_status, :duration, :ready_for_testing, :error_details
  
  def initialize(success:, final_status:, duration:, ready_for_testing:, error_details: nil)
    @success = success
    @final_status = final_status
    @duration = duration
    @ready_for_testing = ready_for_testing
    @error_details = error_details
  end
  
  def success?
    @success
  end
  
  def ready_for_testing?
    @ready_for_testing
  end
  
  def to_hash
    {
      success: @success,
      final_status: @final_status,
      duration: @duration,
      ready_for_testing: @ready_for_testing,
      error_details: @error_details
    }
  end
end

class TestFlightBuild
  attr_reader :build_id, :version, :build_number, :processing_state, :uploaded_date, :app_identifier, :size, :ready_for_testing
  
  def initialize(build_id:, version:, build_number:, processing_state:, uploaded_date:, app_identifier:, size:, ready_for_testing:)
    @build_id = build_id
    @version = version
    @build_number = build_number
    @processing_state = processing_state
    @uploaded_date = uploaded_date
    @app_identifier = app_identifier
    @size = size
    @ready_for_testing = ready_for_testing
  end
  
  def ready_for_testing?
    @ready_for_testing
  end
  
  def to_hash
    {
      build_id: @build_id,
      version: @version,
      build_number: @build_number,
      processing_state: @processing_state,
      uploaded_date: @uploaded_date.iso8601,
      app_identifier: @app_identifier,
      size: @size,
      ready_for_testing: @ready_for_testing
    }
  end
end

class ValidationResult
  attr_reader :valid, :errors, :warnings
  
  def initialize(valid:, errors: [], warnings: [])
    @valid = valid
    @errors = errors
    @warnings = warnings
  end
  
  def valid?
    @valid
  end
  
  def has_warnings?
    !@warnings.empty?
  end
end

class ServiceStatus
  attr_reader :available, :strategies, :active_uploads
  
  def initialize(available:, strategies:, active_uploads:)
    @available = available
    @strategies = strategies
    @active_uploads = active_uploads
  end
  
  def available?
    @available
  end
  
  def to_hash
    {
      available: @available,
      strategies: @strategies,
      active_uploads: @active_uploads
    }
  end
end

class TestFlightMetadata
  attr_reader :changelog, :description, :auto_notify, :beta_groups, :external_testing
  
  def initialize(changelog: nil, description: nil, auto_notify: false, beta_groups: [], external_testing: false)
    @changelog = changelog
    @description = description
    @auto_notify = auto_notify
    @beta_groups = beta_groups
    @external_testing = external_testing
  end
end