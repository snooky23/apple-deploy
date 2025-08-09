# Upload To TestFlight Use Case - Clean Architecture Domain Layer
# Business workflow: Upload iOS application to TestFlight with comprehensive verification

class UploadToTestFlight
  def initialize(upload_repository:, application_repository:, team_repository:, logger:)
    @upload_repository = upload_repository
    @application_repository = application_repository
    @team_repository = team_repository
    @logger = logger
  end
  
  # Execute the use case to upload application to TestFlight
  # @param request [UploadToTestFlightRequest] Input parameters
  # @return [UploadToTestFlightResult] Result with upload status and tracking info
  def execute(request)
    @logger.info("🚀 Starting TestFlight upload for #{request.app_identifier}")
    
    begin
      # Business Logic: Validate input parameters and prerequisites
      validate_request(request)
      
      # Business Logic: Prepare upload environment and credentials
      upload_preparation = prepare_upload_environment(request)
      
      # Business Logic: Validate IPA file and extract metadata
      ipa_validation = validate_and_analyze_ipa(request)
      
      # Business Logic: Check for existing build conflicts
      conflict_check = check_for_build_conflicts(request, ipa_validation)
      
      # Business Logic: Execute TestFlight upload
      upload_result = execute_testflight_upload(request, upload_preparation, ipa_validation)
      
      # Business Logic: Verify upload success and track processing
      verification_result = verify_upload_success(request, upload_result)
      
      # Business Logic: Enhanced monitoring if requested
      monitoring_result = nil
      if request.enhanced_monitoring?
        monitoring_result = monitor_processing_status(request, upload_result)
      end
      
      # Business Logic: Generate audit trail
      audit_trail = generate_audit_trail(request, upload_result, verification_result, monitoring_result)
      
      @logger.success("🎉 TestFlight upload completed successfully")
      @logger.info("📊 Upload duration: #{format_duration(upload_result.upload_duration)}")
      @logger.info("📦 Build size: #{format_file_size(ipa_validation.ipa_size)}")
      
      UploadToTestFlightResult.new(
        success: true,
        build_id: upload_result.build_id,
        upload_duration: upload_result.upload_duration,
        processing_status: verification_result.processing_status,
        testflight_url: verification_result.testflight_url,
        audit_trail: audit_trail,
        monitoring_result: monitoring_result
      )
      
    rescue InvalidIpaError => e
      @logger.error("❌ Invalid IPA file: #{e.message}")
      UploadToTestFlightResult.new(
        success: false,
        error: e.message,
        error_type: :invalid_ipa,
        recovery_suggestion: "Ensure IPA file is properly built and code signed for distribution"
      )
      
    rescue BuildConflictError => e
      @logger.error("❌ Build version conflict: #{e.message}")
      UploadToTestFlightResult.new(
        success: false,
        error: e.message,
        error_type: :build_conflict,
        recovery_suggestion: "Update build number or marketing version to resolve conflict"
      )
      
    rescue UploadFailedError => e
      @logger.error("❌ TestFlight upload failed: #{e.message}")
      UploadToTestFlightResult.new(
        success: false,
        error: e.message,
        error_type: :upload_failed,
        recovery_suggestion: "Check network connection and Apple Developer Portal status"
      )
      
    rescue AuthenticationError => e
      @logger.error("❌ Authentication failed: #{e.message}")
      UploadToTestFlightResult.new(
        success: false,
        error: e.message,
        error_type: :authentication_error,
        recovery_suggestion: "Verify App Store Connect API credentials and permissions"
      )
      
    rescue => e
      @logger.error("❌ Unexpected error during upload: #{e.message}")
      UploadToTestFlightResult.new(
        success: false,
        error: e.message,
        error_type: :unexpected_error,
        recovery_suggestion: "Review upload configuration and system connectivity"
      )
    end
  end
  
  private
  
  # Validate input request parameters
  def validate_request(request)
    raise ArgumentError, "IPA path is required" if request.ipa_path.nil? || request.ipa_path.empty?
    raise ArgumentError, "App identifier is required" if request.app_identifier.nil? || request.app_identifier.empty?
    raise ArgumentError, "Team ID is required" if request.team_id.nil? || request.team_id.empty?
    
    # Validate IPA file exists
    unless File.exist?(request.ipa_path)
      raise InvalidIpaError, "IPA file not found at path: #{request.ipa_path}"
    end
    
    # Validate API credentials
    if request.api_key_path && !File.exist?(request.api_key_path)
      raise AuthenticationError, "API key file not found at path: #{request.api_key_path}"
    end
  end
  
  # Prepare upload environment and authenticate
  def prepare_upload_environment(request)
    @logger.info("🔧 Preparing upload environment...")
    
    # Get team information and validate permissions
    team = @team_repository.find_by_id(request.team_id)
    unless team
      raise AuthenticationError, "Team not found or access denied: #{request.team_id}"
    end
    
    # Prepare API authentication
    auth_config = prepare_authentication(request, team)
    
    # Validate upload permissions
    permissions = @upload_repository.validate_upload_permissions(
      team_id: request.team_id,
      app_identifier: request.app_identifier,
      credentials: auth_config
    )
    
    unless permissions.can_upload?
      raise AuthenticationError, "Insufficient permissions for TestFlight upload: #{permissions.error}"
    end
    
    preparation_result = {
      team: team,
      auth_config: auth_config,
      permissions: permissions,
      upload_tools: detect_available_upload_tools
    }
    
    @logger.info("✅ Upload environment prepared:")
    @logger.info("   - Team: #{team.name} (#{team.team_id})")
    @logger.info("   - Upload tools: #{preparation_result[:upload_tools].join(', ')}")
    
    preparation_result
  end
  
  # Prepare authentication configuration
  def prepare_authentication(request, team)
    if request.api_key_path
      # Use App Store Connect API authentication
      {
        type: :api_key,
        key_path: request.api_key_path,
        key_id: request.api_key_id,
        issuer_id: request.api_issuer_id,
        team_id: request.team_id
      }
    elsif request.apple_id && request.app_password
      # Use Apple ID authentication (fallback)
      {
        type: :apple_id,
        username: request.apple_id,
        password: request.app_password,
        team_id: request.team_id
      }
    else
      raise AuthenticationError, "No valid authentication method provided"
    end
  end
  
  # Detect available upload tools
  def detect_available_upload_tools
    tools = []
    
    # Check for xcrun altool
    begin
      `xcrun altool --version 2>/dev/null`
      tools << "xcrun altool" if $?.success?
    rescue
      # xcrun altool not available
    end
    
    # Check for iTMSTransporter
    begin
      `xcrun iTMSTransporter -version 2>/dev/null`
      tools << "iTMSTransporter" if $?.success?
    rescue
      # iTMSTransporter not available
    end
    
    tools << "fastlane pilot" # Always available through fastlane
    tools
  end
  
  # Validate and analyze IPA file
  def validate_and_analyze_ipa(request)
    @logger.info("🔍 Validating and analyzing IPA file...")
    
    ipa_analysis = @upload_repository.analyze_ipa(request.ipa_path)
    
    unless ipa_analysis.valid?
      raise InvalidIpaError, "IPA validation failed: #{ipa_analysis.errors.join(', ')}"
    end
    
    # Extract application metadata from IPA
    app_metadata = ipa_analysis.application_metadata
    
    # Validate app identifier matches request
    unless app_metadata.bundle_identifier == request.app_identifier
      raise InvalidIpaError, "IPA bundle identifier (#{app_metadata.bundle_identifier}) doesn't match request (#{request.app_identifier})"
    end
    
    validation_result = {
      valid: ipa_analysis.valid?,
      ipa_size: File.size(request.ipa_path),
      app_metadata: app_metadata,
      code_signing_valid: ipa_analysis.code_signing_valid?,
      distribution_ready: ipa_analysis.distribution_ready?
    }
    
    @logger.info("✅ IPA analysis completed:")
    @logger.info("   - Bundle ID: #{app_metadata.bundle_identifier}")
    @logger.info("   - Version: #{app_metadata.marketing_version} (#{app_metadata.build_number})")
    @logger.info("   - Size: #{format_file_size(validation_result[:ipa_size])}")
    @logger.info("   - Code signing: #{validation_result[:code_signing_valid] ? 'Valid' : 'Invalid'}")
    
    validation_result
  end
  
  # Check for existing build conflicts
  def check_for_build_conflicts(request, ipa_validation)
    @logger.info("🔍 Checking for build conflicts...")
    
    app_metadata = ipa_validation[:app_metadata]
    
    # Query existing builds on TestFlight
    existing_builds = @upload_repository.get_testflight_builds(
      app_identifier: request.app_identifier,
      team_id: request.team_id
    )
    
    # Check for version/build conflicts
    conflict = existing_builds.find do |build|
      build.marketing_version == app_metadata.marketing_version &&
      build.build_number == app_metadata.build_number
    end
    
    if conflict && !request.allow_version_conflicts?
      raise BuildConflictError, "Build #{app_metadata.marketing_version} (#{app_metadata.build_number}) already exists on TestFlight"
    end
    
    conflict_result = {
      has_conflict: !conflict.nil?,
      conflicting_build: conflict,
      latest_build: existing_builds.first,
      total_builds: existing_builds.length
    }
    
    if conflict_result[:has_conflict]
      @logger.warning("⚠️ Version conflict detected but proceeding due to allow_version_conflicts flag")
    else
      @logger.info("✅ No build conflicts detected")
    end
    
    if conflict_result[:latest_build]
      @logger.info("   - Latest TestFlight build: #{conflict_result[:latest_build].marketing_version} (#{conflict_result[:latest_build].build_number})")
    end
    
    conflict_result
  end
  
  # Execute TestFlight upload with multiple strategies
  def execute_testflight_upload(request, upload_preparation, ipa_validation)
    @logger.info("📤 Executing TestFlight upload...")
    
    upload_start_time = Time.now
    upload_strategies = determine_upload_strategies(upload_preparation)
    
    upload_result = nil
    last_error = nil
    
    # Try each upload strategy until one succeeds
    upload_strategies.each_with_index do |strategy, index|
      @logger.info("🔄 Attempting upload strategy #{index + 1}/#{upload_strategies.length}: #{strategy[:name]}")
      
      begin
        upload_result = execute_upload_strategy(request, strategy, ipa_validation)
        break if upload_result.success?
      rescue => e
        @logger.warning("⚠️ Upload strategy '#{strategy[:name]}' failed: #{e.message}")
        last_error = e
      end
    end
    
    upload_duration = Time.now - upload_start_time
    
    unless upload_result&.success?
      raise UploadFailedError, "All upload strategies failed. Last error: #{last_error&.message}"
    end
    
    @logger.info("✅ Upload completed successfully in #{format_duration(upload_duration)}")
    @logger.info("   - Strategy: #{upload_result.strategy}")
    @logger.info("   - Build ID: #{upload_result.build_id}")
    
    upload_result.upload_duration = upload_duration
    upload_result
  end
  
  # Determine available upload strategies
  def determine_upload_strategies(upload_preparation)
    strategies = []
    
    # Primary strategy: xcrun altool (most reliable)
    if upload_preparation[:upload_tools].include?("xcrun altool")
      strategies << {
        name: "xcrun altool",
        tool: :altool,
        priority: 1
      }
    end
    
    # Secondary strategy: iTMSTransporter
    if upload_preparation[:upload_tools].include?("iTMSTransporter")
      strategies << {
        name: "iTMSTransporter",
        tool: :transporter,
        priority: 2
      }
    end
    
    # Fallback strategy: fastlane pilot
    strategies << {
      name: "fastlane pilot",
      tool: :pilot,
      priority: 3
    }
    
    strategies.sort_by { |s| s[:priority] }
  end
  
  # Execute specific upload strategy
  def execute_upload_strategy(request, strategy, ipa_validation)
    case strategy[:tool]
    when :altool
      @upload_repository.upload_with_altool(
        ipa_path: request.ipa_path,
        api_key_path: request.api_key_path,
        api_key_id: request.api_key_id,
        api_issuer_id: request.api_issuer_id
      )
    when :transporter
      @upload_repository.upload_with_transporter(
        ipa_path: request.ipa_path,
        username: request.apple_id,
        password: request.app_password
      )
    when :pilot
      @upload_repository.upload_with_pilot(
        ipa_path: request.ipa_path,
        team_id: request.team_id,
        app_identifier: request.app_identifier
      )
    else
      raise UploadFailedError, "Unknown upload strategy: #{strategy[:tool]}"
    end
  end
  
  # Verify upload success and get initial status
  def verify_upload_success(request, upload_result)
    @logger.info("✅ Verifying upload success...")
    
    # Wait brief moment for Apple servers to register upload
    sleep(5)
    
    # Verify build appears in TestFlight
    verification = @upload_repository.verify_upload_success(
      app_identifier: request.app_identifier,
      build_id: upload_result.build_id,
      team_id: request.team_id
    )
    
    unless verification.verified?
      @logger.warning("⚠️ Upload verification incomplete - build may still be processing")
    else
      @logger.info("✅ Upload verified successfully")
    end
    
    verification_result = {
      verified: verification.verified?,
      processing_status: verification.processing_status,
      testflight_url: verification.testflight_url,
      verification_details: verification.details
    }
    
    @logger.info("   - Processing status: #{verification_result[:processing_status]}")
    
    verification_result
  end
  
  # Monitor processing status with enhanced tracking
  def monitor_processing_status(request, upload_result)
    @logger.info("👀 Starting enhanced processing monitoring...")
    
    monitoring_start_time = Time.now
    max_monitoring_duration = request.monitoring_timeout || 1800 # 30 minutes default
    
    monitoring_result = @upload_repository.monitor_processing_status(
      app_identifier: request.app_identifier,
      build_id: upload_result.build_id,
      team_id: request.team_id,
      timeout: max_monitoring_duration,
      progress_callback: ->(status) {
        @logger.info("📊 Processing status: #{status}")
      }
    )
    
    monitoring_duration = Time.now - monitoring_start_time
    
    @logger.info("✅ Monitoring completed in #{format_duration(monitoring_duration)}")
    @logger.info("   - Final status: #{monitoring_result.final_status}")
    @logger.info("   - Processing time: #{format_duration(monitoring_result.processing_duration)}")
    
    monitoring_result
  end
  
  # Generate comprehensive audit trail
  def generate_audit_trail(request, upload_result, verification_result, monitoring_result)
    @logger.info("📝 Generating audit trail...")
    
    audit_data = {
      timestamp: Time.now.iso8601,
      app_identifier: request.app_identifier,
      team_id: request.team_id,
      build_info: {
        marketing_version: upload_result.marketing_version,
        build_number: upload_result.build_number,
        build_id: upload_result.build_id
      },
      upload_info: {
        strategy: upload_result.strategy,
        duration: upload_result.upload_duration,
        ipa_size: File.size(request.ipa_path)
      },
      processing_info: {
        initial_status: verification_result[:processing_status],
        final_status: monitoring_result&.final_status,
        processing_duration: monitoring_result&.processing_duration
      },
      metadata: {
        enhanced_monitoring: request.enhanced_monitoring?,
        environment: ENV['FASTLANE_ENV'] || 'production'
      }
    }
    
    # Save audit trail to repository
    @upload_repository.save_audit_trail(audit_data)
    
    @logger.info("✅ Audit trail saved")
    
    audit_data
  end
  
  # Format file size for human-readable display
  def format_file_size(size_bytes)
    units = %w[B KB MB GB]
    size = size_bytes.to_f
    unit_index = 0
    
    while size >= 1024 && unit_index < units.length - 1
      size /= 1024
      unit_index += 1
    end
    
    format("%.1f %s", size, units[unit_index])
  end
  
  # Format duration for human-readable display
  def format_duration(duration_seconds)
    minutes = (duration_seconds / 60).to_i
    seconds = (duration_seconds % 60).to_i
    
    if minutes > 0
      "#{minutes}m #{seconds}s"
    else
      "#{seconds}s"
    end
  end
end

# Request object for UploadToTestFlight use case
class UploadToTestFlightRequest
  attr_reader :ipa_path, :app_identifier, :team_id, :api_key_path, :api_key_id, :api_issuer_id,
              :apple_id, :app_password, :enhanced_monitoring, :monitoring_timeout, :allow_version_conflicts
  
  def initialize(ipa_path:, app_identifier:, team_id:, api_key_path: nil, api_key_id: nil,
                 api_issuer_id: nil, apple_id: nil, app_password: nil, enhanced_monitoring: false,
                 monitoring_timeout: 1800, allow_version_conflicts: false)
    @ipa_path = ipa_path
    @app_identifier = app_identifier
    @team_id = team_id
    @api_key_path = api_key_path
    @api_key_id = api_key_id
    @api_issuer_id = api_issuer_id
    @apple_id = apple_id
    @app_password = app_password
    @enhanced_monitoring = enhanced_monitoring
    @monitoring_timeout = monitoring_timeout
    @allow_version_conflicts = allow_version_conflicts
  end
  
  def enhanced_monitoring?
    @enhanced_monitoring
  end
  
  def allow_version_conflicts?
    @allow_version_conflicts
  end
end

# Result object for UploadToTestFlight use case
class UploadToTestFlightResult
  attr_reader :success, :build_id, :upload_duration, :processing_status, :testflight_url,
              :audit_trail, :monitoring_result, :error, :error_type, :recovery_suggestion
  
  def initialize(success:, build_id: nil, upload_duration: nil, processing_status: nil,
                 testflight_url: nil, audit_trail: nil, monitoring_result: nil,
                 error: nil, error_type: nil, recovery_suggestion: nil)
    @success = success
    @build_id = build_id
    @upload_duration = upload_duration
    @processing_status = processing_status
    @testflight_url = testflight_url
    @audit_trail = audit_trail
    @monitoring_result = monitoring_result
    @error = error
    @error_type = error_type
    @recovery_suggestion = recovery_suggestion
  end
  
  def success?
    @success
  end
  
  def processing_complete?
    @processing_status == "Ready to Test"
  end
  
  def processing_failed?
    @processing_status&.include?("Failed") || @processing_status&.include?("Rejected")
  end
end

# Custom exceptions for TestFlight upload
class InvalidIpaError < StandardError; end
class BuildConflictError < StandardError; end
class UploadFailedError < StandardError; end
class AuthenticationError < StandardError; end