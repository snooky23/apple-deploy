# DeploymentHistory Domain Entity - Clean Architecture Domain Layer
# Pure business object representing deployment audit trails and historical tracking

require 'date'
require 'digest'

class DeploymentHistory
  # Deployment Status Values
  DEPLOYMENT_STATUSES = %w[initiated building uploading processing completed failed].freeze
  
  # Deployment Types
  DEPLOYMENT_TYPES = %w[testflight app_store ad_hoc enterprise].freeze
  
  # Business Rules and Constraints
  MAX_LOG_ENTRY_LENGTH = 10000
  MAX_ERROR_MESSAGE_LENGTH = 5000
  MAX_DEPLOYMENT_DURATION = 7200  # 2 hours maximum
  
  # Retention and Archival Rules
  DEFAULT_RETENTION_DAYS = 365    # 1 year
  COMPLIANCE_RETENTION_DAYS = 2555  # 7 years for enterprise compliance
  
  attr_reader :deployment_id, :team_id, :app_identifier, :deployment_type, :status,
              :marketing_version, :build_number, :initiated_by, :initiated_at,
              :completed_at, :duration, :ipa_path, :ipa_size, :testflight_url,
              :build_logs, :error_details, :metadata, :checksum
  
  # Initialize DeploymentHistory entity
  # @param deployment_id [String] Unique deployment identifier
  # @param team_id [String] Apple Developer Team ID
  # @param app_identifier [String] Bundle identifier
  # @param deployment_type [String] Type of deployment ('testflight', 'app_store', 'ad_hoc', 'enterprise')
  # @param status [String] Current deployment status
  # @param marketing_version [String] App marketing version
  # @param build_number [String, Integer] App build number
  # @param initiated_by [String] Email of person who initiated deployment
  # @param initiated_at [Time, String, nil] When deployment started (optional, defaults to now)
  # @param completed_at [Time, String, nil] When deployment completed (optional)
  # @param duration [Float, nil] Deployment duration in seconds (optional)
  # @param ipa_path [String, nil] Path to IPA file (optional)
  # @param ipa_size [Integer, nil] Size of IPA file in bytes (optional)
  # @param testflight_url [String, nil] TestFlight URL after upload (optional)
  # @param build_logs [Array<String>, nil] Build log entries (optional)
  # @param error_details [Hash, nil] Error information if deployment failed (optional)
  # @param metadata [Hash, nil] Additional deployment metadata (optional)
  def initialize(deployment_id:, team_id:, app_identifier:, deployment_type:, status:,
                 marketing_version:, build_number:, initiated_by:, initiated_at: nil,
                 completed_at: nil, duration: nil, ipa_path: nil, ipa_size: nil,
                 testflight_url: nil, build_logs: nil, error_details: nil, metadata: nil)
    validate_initialization_parameters(deployment_id, team_id, app_identifier, deployment_type, 
                                     status, marketing_version, build_number, initiated_by)
    
    @deployment_id = deployment_id.to_s.strip
    @team_id = team_id.to_s.strip
    @app_identifier = app_identifier.to_s.strip
    @deployment_type = deployment_type.to_s.downcase
    @status = status.to_s.downcase
    @marketing_version = marketing_version.to_s.strip
    @build_number = build_number.to_s
    @initiated_by = initiated_by.to_s.strip.downcase
    @initiated_at = initiated_at ? parse_time(initiated_at) : Time.now
    @completed_at = completed_at ? parse_time(completed_at) : nil
    @duration = duration
    @ipa_path = ipa_path&.to_s&.strip
    @ipa_size = ipa_size
    @testflight_url = testflight_url&.to_s&.strip
    @build_logs = build_logs ? build_logs.dup : []
    @error_details = error_details ? error_details.dup : {}
    @metadata = metadata ? metadata.dup : {}
    @checksum = calculate_checksum
  end
  
  # Business Logic Methods
  
  # Check if deployment is currently in progress
  # @return [Boolean] True if deployment is not yet completed or failed
  def in_progress?
    %w[initiated building uploading processing].include?(@status)
  end
  
  # Check if deployment completed successfully
  # @return [Boolean] True if deployment reached completed status
  def successful?
    @status == 'completed'
  end
  
  # Check if deployment failed
  # @return [Boolean] True if deployment status is failed
  def failed?
    @status == 'failed'
  end
  
  # Check if deployment is for TestFlight
  # @return [Boolean] True if deployment type is testflight
  def testflight_deployment?
    @deployment_type == 'testflight'
  end
  
  # Check if deployment is for App Store
  # @return [Boolean] True if deployment type is app_store
  def app_store_deployment?
    @deployment_type == 'app_store'
  end
  
  # Check if deployment is enterprise distribution
  # @return [Boolean] True if deployment type is enterprise
  def enterprise_deployment?
    @deployment_type == 'enterprise'
  end
  
  # Duration and Timing Analysis
  
  # Calculate deployment duration if not set
  # @return [Float, nil] Duration in seconds, nil if not completed
  def calculate_duration
    return @duration if @duration
    return nil unless @completed_at
    @completed_at - @initiated_at
  end
  
  # Get deployment duration in human-readable format
  # @return [String] Formatted duration (e.g., "5m 32s")
  def formatted_duration
    duration = calculate_duration
    return "In Progress" unless duration
    
    minutes = (duration / 60).to_i
    seconds = (duration % 60).to_i
    
    if minutes > 0
      "#{minutes}m #{seconds}s"
    else
      "#{seconds}s"
    end
  end
  
  # Check if deployment exceeded reasonable time limits
  # @return [Boolean] True if deployment took too long
  def excessive_duration?
    duration = calculate_duration
    return false unless duration
    duration > MAX_DEPLOYMENT_DURATION
  end
  
  # Build Information and Artifacts
  
  # Get IPA size in human-readable format
  # @return [String] Formatted file size (e.g., "45.2 MB")
  def formatted_ipa_size
    return "Unknown" unless @ipa_size
    
    units = %w[B KB MB GB]
    size = @ipa_size.to_f
    unit_index = 0
    
    while size >= 1024 && unit_index < units.length - 1
      size /= 1024
      unit_index += 1
    end
    
    format("%.1f %s", size, units[unit_index])
  end
  
  # Check if IPA file still exists at recorded path
  # @return [Boolean] True if IPA file exists
  def ipa_file_exists?
    return false unless @ipa_path
    File.exist?(@ipa_path)
  end
  
  # Get build identifier string for tracking
  # @return [String] Formatted build identifier
  def build_identifier
    "#{@app_identifier} v#{@marketing_version} (#{@build_number})"
  end
  
  # Logging and Error Management
  
  # Add log entry to deployment history
  # @param log_entry [String] Log message to add
  # @return [DeploymentHistory] New deployment history with added log
  def add_log_entry(log_entry)
    raise ArgumentError, "Log entry cannot be nil or empty" if log_entry.nil? || log_entry.strip.empty?
    
    if log_entry.length > MAX_LOG_ENTRY_LENGTH
      log_entry = log_entry[0, MAX_LOG_ENTRY_LENGTH] + "... [truncated]"
    end
    
    timestamped_entry = "[#{Time.now.strftime('%H:%M:%S')}] #{log_entry}"
    new_logs = @build_logs + [timestamped_entry]
    
    with_updated_logs(new_logs)
  end
  
  # Set error details for failed deployment
  # @param error_type [String] Type of error
  # @param error_message [String] Error message
  # @param error_context [Hash, nil] Additional error context
  # @return [DeploymentHistory] New deployment history with error details
  def with_error(error_type, error_message, error_context = nil)
    if error_message.length > MAX_ERROR_MESSAGE_LENGTH
      error_message = error_message[0, MAX_ERROR_MESSAGE_LENGTH] + "... [truncated]"
    end
    
    new_error_details = {
      type: error_type.to_s,
      message: error_message.to_s,
      timestamp: Time.now.iso8601,
      context: error_context || {}
    }
    
    with_updated_error_details(new_error_details)
  end
  
  # Status Management
  
  # Update deployment status
  # @param new_status [String] New status to set
  # @param completion_time [Time, nil] Completion time if finishing
  # @return [DeploymentHistory] New deployment history with updated status
  def with_status(new_status, completion_time = nil)
    unless DEPLOYMENT_STATUSES.include?(new_status.to_s.downcase)
      raise ArgumentError, "Invalid status: #{new_status}"
    end
    
    # Auto-set completion time for terminal statuses
    if %w[completed failed].include?(new_status.to_s.downcase) && completion_time.nil?
      completion_time = Time.now
    end
    
    # Calculate duration when completing
    calculated_duration = nil
    if completion_time
      calculated_duration = completion_time - @initiated_at
    end
    
    self.class.new(
      deployment_id: @deployment_id,
      team_id: @team_id,
      app_identifier: @app_identifier,
      deployment_type: @deployment_type,
      status: new_status,
      marketing_version: @marketing_version,
      build_number: @build_number,
      initiated_by: @initiated_by,
      initiated_at: @initiated_at,
      completed_at: completion_time,
      duration: calculated_duration,
      ipa_path: @ipa_path,
      ipa_size: @ipa_size,
      testflight_url: @testflight_url,
      build_logs: @build_logs,
      error_details: @error_details,
      metadata: @metadata
    )
  end
  
  # Mark deployment as completed successfully
  # @param testflight_url [String, nil] TestFlight URL if applicable
  # @return [DeploymentHistory] New deployment history marked as completed
  def complete(testflight_url = nil)
    result = with_status('completed')
    return result unless testflight_url
    
    result.with_testflight_url(testflight_url)
  end
  
  # Mark deployment as failed
  # @param error_type [String] Type of failure
  # @param error_message [String] Error message
  # @return [DeploymentHistory] New deployment history marked as failed
  def fail(error_type, error_message)
    with_error(error_type, error_message).with_status('failed')
  end
  
  # Metadata Management
  
  # Get metadata value
  # @param key [String, Symbol] Metadata key
  # @return [Object] Metadata value or nil
  def get_metadata(key)
    @metadata[key.to_s] || @metadata[key.to_sym]
  end
  
  # Set metadata value (returns new instance)
  # @param key [String, Symbol] Metadata key
  # @param value [Object] Metadata value
  # @return [DeploymentHistory] New instance with updated metadata
  def with_metadata(key, value)
    new_metadata = @metadata.dup
    new_metadata[key.to_s] = value
    
    with_updated_metadata(new_metadata)
  end
  
  # Update TestFlight URL
  # @param url [String] TestFlight URL
  # @return [DeploymentHistory] New instance with TestFlight URL
  def with_testflight_url(url)
    self.class.new(
      deployment_id: @deployment_id,
      team_id: @team_id,
      app_identifier: @app_identifier,
      deployment_type: @deployment_type,
      status: @status,
      marketing_version: @marketing_version,
      build_number: @build_number,
      initiated_by: @initiated_by,
      initiated_at: @initiated_at,
      completed_at: @completed_at,
      duration: @duration,
      ipa_path: @ipa_path,
      ipa_size: @ipa_size,
      testflight_url: url,
      build_logs: @build_logs,
      error_details: @error_details,
      metadata: @metadata
    )
  end
  
  # Compliance and Retention
  
  # Check if deployment should be archived based on age
  # @param retention_days [Integer] Days to retain (default: DEFAULT_RETENTION_DAYS)
  # @return [Boolean] True if deployment is old enough to archive
  def should_archive?(retention_days = DEFAULT_RETENTION_DAYS)
    age_in_days = (Date.today - @initiated_at.to_date).to_i
    age_in_days > retention_days
  end
  
  # Check if deployment must be kept for compliance
  # @return [Boolean] True if deployment must be retained for compliance
  def compliance_retention_required?
    enterprise_deployment? || app_store_deployment?
  end
  
  # Get retention period based on compliance requirements
  # @return [Integer] Days to retain deployment
  def retention_period
    compliance_retention_required? ? COMPLIANCE_RETENTION_DAYS : DEFAULT_RETENTION_DAYS
  end
  
  # Comparison and Equality
  
  # Check equality with another deployment
  # @param other [DeploymentHistory] Other deployment to compare
  # @return [Boolean] True if deployments are equal
  def ==(other)
    return false unless other.is_a?(DeploymentHistory)
    @deployment_id == other.deployment_id
  end
  
  # Generate hash for deployment (useful for Set operations)
  # @return [Integer] Hash value
  def hash
    @deployment_id.hash
  end
  
  # Compare deployments for sorting (by initiated_at, newest first)
  # @param other [DeploymentHistory] Other deployment to compare
  # @return [Integer] -1, 0, or 1 for sorting
  def <=>(other)
    return 0 unless other.is_a?(DeploymentHistory)
    other.initiated_at <=> @initiated_at  # Reverse order (newest first)
  end
  
  # Serialization and Display
  
  # Convert deployment to hash representation
  # @return [Hash] Deployment data as hash
  def to_hash
    {
      deployment_id: @deployment_id,
      team_id: @team_id,
      app_identifier: @app_identifier,
      deployment_type: @deployment_type,
      status: @status,
      marketing_version: @marketing_version,
      build_number: @build_number,
      initiated_by: @initiated_by,
      initiated_at: @initiated_at.iso8601,
      completed_at: @completed_at&.iso8601,
      duration: calculate_duration,
      ipa_path: @ipa_path,
      ipa_size: @ipa_size,
      testflight_url: @testflight_url,
      build_logs: @build_logs,
      error_details: @error_details,
      metadata: @metadata,
      checksum: @checksum,
      analysis: {
        formatted_duration: formatted_duration,
        formatted_ipa_size: formatted_ipa_size,
        excessive_duration: excessive_duration?,
        ipa_file_exists: ipa_file_exists?,
        build_identifier: build_identifier,
        retention_period: retention_period,
        should_archive: should_archive?
      }
    }
  end
  
  # Convert to audit log format
  # @return [String] Formatted audit log entry
  def to_audit_log
    status_emoji = case @status
                  when 'completed' then '✅'
                  when 'failed' then '❌'
                  when 'processing' then '⏳'
                  else '🔄'
                  end
    
    "#{status_emoji} [#{@initiated_at.strftime('%Y-%m-%d %H:%M:%S')}] " \
    "#{build_identifier} → #{@deployment_type.upcase} " \
    "by #{@initiated_by} (#{formatted_duration})"
  end
  
  # String representation of deployment
  # @return [String] Human-readable deployment description
  def to_s
    "Deployment #{@deployment_id}: #{build_identifier} → #{@deployment_type} (#{@status})"
  end
  
  # Detailed string representation
  # @return [String] Detailed deployment information
  def inspect
    "#<DeploymentHistory:#{object_id} id='#{@deployment_id}' app='#{@app_identifier}' " \
    "version=#{@marketing_version}(#{@build_number}) status=#{@status} type=#{@deployment_type}>"
  end
  
  # Class Methods
  
  class << self
    # Generate unique deployment ID
    # @param team_id [String] Team ID
    # @param app_identifier [String] App identifier
    # @return [String] Unique deployment ID
    def generate_deployment_id(team_id, app_identifier)
      timestamp = Time.now.strftime('%Y%m%d_%H%M%S')
      random_suffix = SecureRandom.hex(4).upcase
      app_prefix = app_identifier.split('.').last.upcase[0, 4] rescue 'APP'
      
      "#{team_id}_#{app_prefix}_#{timestamp}_#{random_suffix}"
    end
    
    # Create deployment from upload result
    # @param upload_result [Hash] Upload result data
    # @return [DeploymentHistory] Deployment history entity
    def from_upload_result(upload_result)
      new(
        deployment_id: upload_result[:deployment_id] || generate_deployment_id(upload_result[:team_id], upload_result[:app_identifier]),
        team_id: upload_result[:team_id],
        app_identifier: upload_result[:app_identifier],
        deployment_type: upload_result[:deployment_type] || 'testflight',
        status: upload_result[:success] ? 'completed' : 'failed',
        marketing_version: upload_result[:marketing_version],
        build_number: upload_result[:build_number],
        initiated_by: upload_result[:initiated_by],
        initiated_at: upload_result[:initiated_at],
        completed_at: upload_result[:completed_at],
        duration: upload_result[:duration],
        ipa_path: upload_result[:ipa_path],
        ipa_size: upload_result[:ipa_size],
        testflight_url: upload_result[:testflight_url],
        build_logs: upload_result[:build_logs],
        error_details: upload_result[:error_details],
        metadata: upload_result[:metadata]
      )
    end
  end
  
  private
  
  # Validate initialization parameters
  def validate_initialization_parameters(deployment_id, team_id, app_identifier, deployment_type, 
                                       status, marketing_version, build_number, initiated_by)
    raise ArgumentError, "Deployment ID cannot be nil or empty" if deployment_id.nil? || deployment_id.to_s.strip.empty?
    raise ArgumentError, "Team ID cannot be nil or empty" if team_id.nil? || team_id.to_s.strip.empty?
    raise ArgumentError, "App identifier cannot be nil or empty" if app_identifier.nil? || app_identifier.to_s.strip.empty?
    raise ArgumentError, "Initiated by cannot be nil or empty" if initiated_by.nil? || initiated_by.to_s.strip.empty?
    
    unless team_id.to_s.match?(/^[A-Z0-9]{10}$/)
      raise ArgumentError, "Invalid team ID format: #{team_id}"
    end
    
    unless DEPLOYMENT_TYPES.include?(deployment_type.to_s.downcase)
      raise ArgumentError, "Invalid deployment type: #{deployment_type}. Must be one of: #{DEPLOYMENT_TYPES.join(', ')}"
    end
    
    unless DEPLOYMENT_STATUSES.include?(status.to_s.downcase)
      raise ArgumentError, "Invalid status: #{status}. Must be one of: #{DEPLOYMENT_STATUSES.join(', ')}"
    end
    
    unless initiated_by.to_s.match?(/\A[^@\s]+@[^@\s]+\z/)
      raise ArgumentError, "Invalid email format for initiated_by: #{initiated_by}"
    end
  end
  
  # Parse time from various formats
  def parse_time(time_input)
    case time_input
    when Time
      time_input
    when DateTime
      time_input.to_time
    when String
      Time.parse(time_input)
    else
      raise ArgumentError, "Invalid time format: #{time_input.class}"
    end
  end
  
  # Calculate deployment checksum for integrity verification
  def calculate_checksum
    data = "#{@deployment_id}:#{@team_id}:#{@app_identifier}:#{@marketing_version}:#{@build_number}:#{@initiated_at.iso8601}"
    Digest::SHA256.hexdigest(data)[0, 12]  # First 12 characters for brevity
  end
  
  # Create new instance with updated logs
  def with_updated_logs(new_logs)
    self.class.new(
      deployment_id: @deployment_id,
      team_id: @team_id,
      app_identifier: @app_identifier,
      deployment_type: @deployment_type,
      status: @status,
      marketing_version: @marketing_version,
      build_number: @build_number,
      initiated_by: @initiated_by,
      initiated_at: @initiated_at,
      completed_at: @completed_at,
      duration: @duration,
      ipa_path: @ipa_path,
      ipa_size: @ipa_size,
      testflight_url: @testflight_url,
      build_logs: new_logs,
      error_details: @error_details,
      metadata: @metadata
    )
  end
  
  # Create new instance with updated error details
  def with_updated_error_details(new_error_details)
    self.class.new(
      deployment_id: @deployment_id,
      team_id: @team_id,
      app_identifier: @app_identifier,
      deployment_type: @deployment_type,
      status: @status,
      marketing_version: @marketing_version,
      build_number: @build_number,
      initiated_by: @initiated_by,
      initiated_at: @initiated_at,
      completed_at: @completed_at,
      duration: @duration,
      ipa_path: @ipa_path,
      ipa_size: @ipa_size,
      testflight_url: @testflight_url,
      build_logs: @build_logs,
      error_details: new_error_details,
      metadata: @metadata
    )
  end
  
  # Create new instance with updated metadata
  def with_updated_metadata(new_metadata)
    self.class.new(
      deployment_id: @deployment_id,
      team_id: @team_id,
      app_identifier: @app_identifier,
      deployment_type: @deployment_type,
      status: @status,
      marketing_version: @marketing_version,
      build_number: @build_number,
      initiated_by: @initiated_by,
      initiated_at: @initiated_at,
      completed_at: @completed_at,
      duration: @duration,
      ipa_path: @ipa_path,
      ipa_size: @ipa_size,
      testflight_url: @testflight_url,
      build_logs: @build_logs,
      error_details: @error_details,
      metadata: new_metadata
    )
  end
end