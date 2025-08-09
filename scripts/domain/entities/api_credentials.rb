# ApiCredentials Domain Entity - Clean Architecture Domain Layer
# Pure business object representing secure API credential management and validation

require 'date'
require 'digest'

class ApiCredentials
  # Credential Types
  CREDENTIAL_TYPES = %w[app_store_connect apple_id].freeze
  
  # Security Levels
  SECURITY_LEVELS = %w[low medium high].freeze
  
  # Business Rules and Security Constraints
  API_KEY_ID_LENGTH = 10
  API_KEY_ID_REGEX = /\A[A-Z0-9]{10}\z/
  API_ISSUER_ID_REGEX = /\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/
  
  # File Security Requirements
  API_KEY_EXTENSION = '.p8'
  REQUIRED_FILE_PERMISSIONS = '600'  # Owner read/write only
  MAX_KEY_FILE_SIZE = 10240  # 10KB max for P8 files
  
  # Rotation and Expiration Rules
  DEFAULT_ROTATION_DAYS = 90
  WARNING_DAYS_BEFORE_ROTATION = 14
  MAX_CREDENTIAL_AGE_DAYS = 365
  
  attr_reader :credential_id, :team_id, :credential_type, :api_key_id, :api_issuer_id,
              :api_key_path, :apple_id, :security_level, :created_at, :last_used_at,
              :rotation_due_at, :metadata, :validation_checksum
  
  # Initialize ApiCredentials entity
  # @param credential_id [String] Unique identifier for credential set
  # @param team_id [String] Apple Developer Team ID
  # @param credential_type [String] Type of credentials ('app_store_connect', 'apple_id')
  # @param api_key_id [String, nil] App Store Connect API Key ID (required for app_store_connect)
  # @param api_issuer_id [String, nil] App Store Connect API Issuer ID (required for app_store_connect)
  # @param api_key_path [String, nil] Path to P8 API key file (required for app_store_connect)
  # @param apple_id [String, nil] Apple ID email (required for apple_id type)
  # @param security_level [String] Security level ('low', 'medium', 'high')
  # @param created_at [Date, String, nil] When credentials were created (optional)
  # @param last_used_at [Time, String, nil] When credentials were last used (optional)
  # @param rotation_due_at [Date, String, nil] When credentials should be rotated (optional)
  # @param metadata [Hash, nil] Additional credential metadata (optional)
  def initialize(credential_id:, team_id:, credential_type:, api_key_id: nil, api_issuer_id: nil,
                 api_key_path: nil, apple_id: nil, security_level: 'medium', created_at: nil,
                 last_used_at: nil, rotation_due_at: nil, metadata: nil)
    validate_initialization_parameters(credential_id, team_id, credential_type, api_key_id,
                                     api_issuer_id, api_key_path, apple_id, security_level)
    
    @credential_id = credential_id.to_s.strip
    @team_id = team_id.to_s.strip
    @credential_type = credential_type.to_s.downcase
    @api_key_id = api_key_id&.to_s&.strip
    @api_issuer_id = api_issuer_id&.to_s&.strip
    @api_key_path = api_key_path&.to_s&.strip
    @apple_id = apple_id&.to_s&.strip&.downcase
    @security_level = security_level.to_s.downcase
    @created_at = created_at ? parse_date(created_at) : Date.today
    @last_used_at = last_used_at ? parse_time(last_used_at) : nil
    @rotation_due_at = rotation_due_at ? parse_date(rotation_due_at) : calculate_rotation_due_date
    @metadata = metadata ? metadata.dup : {}
    @validation_checksum = calculate_validation_checksum
  end
  
  # Business Logic Methods
  
  # Check if credentials are for App Store Connect API
  # @return [Boolean] True if credentials are for App Store Connect
  def app_store_connect?
    @credential_type == 'app_store_connect'
  end
  
  # Check if credentials are for Apple ID authentication
  # @return [Boolean] True if credentials are for Apple ID
  def apple_id_authentication?
    @credential_type == 'apple_id'
  end
  
  # Check if credentials are considered high security
  # @return [Boolean] True if security level is high
  def high_security?
    @security_level == 'high'
  end
  
  # Check if credentials require enhanced protection
  # @return [Boolean] True if credentials need extra security measures
  def enhanced_protection_required?
    high_security? || app_store_connect?
  end
  
  # Credential Validation
  
  # Validate all credential components are present and correct
  # @return [CredentialValidationResult] Comprehensive validation result
  def validate_credentials
    errors = []
    warnings = []
    
    # Validate based on credential type
    case @credential_type
    when 'app_store_connect'
      errors.concat(validate_app_store_connect_credentials)
    when 'apple_id'
      errors.concat(validate_apple_id_credentials)
    end
    
    # Common validations
    warnings.concat(validate_security_requirements)
    warnings.concat(validate_rotation_status)
    
    CredentialValidationResult.new(
      valid: errors.empty?,
      errors: errors,
      warnings: warnings,
      security_score: calculate_security_score,
      recommendations: generate_security_recommendations(errors, warnings)
    )
  end
  
  # Check if API key file exists and is accessible
  # @return [Boolean] True if API key file is present and readable
  def api_key_file_exists?
    return false unless @api_key_path
    File.exist?(@api_key_path) && File.readable?(@api_key_path)
  end
  
  # Validate API key file security
  # @return [ApiKeyFileValidation] File security validation result
  def validate_api_key_file
    return ApiKeyFileValidation.new(valid: false, error: "No API key path specified") unless @api_key_path
    return ApiKeyFileValidation.new(valid: false, error: "API key file not found") unless api_key_file_exists?
    
    file_stat = File.stat(@api_key_path)
    file_permissions = format('%o', file_stat.mode)[-3, 3]
    file_size = file_stat.size
    
    issues = []
    warnings = []
    
    # Check file permissions
    if file_permissions != REQUIRED_FILE_PERMISSIONS
      issues << "Insecure file permissions: #{file_permissions} (should be #{REQUIRED_FILE_PERMISSIONS})"
    end
    
    # Check file size
    if file_size > MAX_KEY_FILE_SIZE
      warnings << "Large key file size: #{file_size} bytes (expected < #{MAX_KEY_FILE_SIZE})"
    elsif file_size < 100
      issues << "Key file too small: #{file_size} bytes (possibly corrupted)"
    end
    
    # Check file extension
    unless @api_key_path.end_with?(API_KEY_EXTENSION)
      warnings << "Unexpected file extension (expected #{API_KEY_EXTENSION})"
    end
    
    ApiKeyFileValidation.new(
      valid: issues.empty?,
      errors: issues,
      warnings: warnings,
      file_permissions: file_permissions,
      file_size: file_size,
      secure_permissions: file_permissions == REQUIRED_FILE_PERMISSIONS
    )
  end
  
  # Usage Tracking and Analytics
  
  # Record credential usage
  # @param usage_context [Hash, nil] Context information about usage
  # @return [ApiCredentials] New credentials instance with updated usage
  def record_usage(usage_context = nil)
    new_metadata = @metadata.dup
    new_metadata['last_usage_context'] = usage_context if usage_context
    new_metadata['usage_count'] = (new_metadata['usage_count'] || 0) + 1
    
    self.class.new(
      credential_id: @credential_id,
      team_id: @team_id,
      credential_type: @credential_type,
      api_key_id: @api_key_id,
      api_issuer_id: @api_issuer_id,
      api_key_path: @api_key_path,
      apple_id: @apple_id,
      security_level: @security_level,
      created_at: @created_at,
      last_used_at: Time.now,
      rotation_due_at: @rotation_due_at,
      metadata: new_metadata
    )
  end
  
  # Get usage frequency analysis
  # @return [Hash] Usage statistics and patterns
  def usage_analytics
    usage_count = @metadata['usage_count'] || 0
    days_since_creation = (Date.today - @created_at).to_i
    days_since_last_use = @last_used_at ? (Date.today - @last_used_at.to_date).to_i : nil
    
    {
      total_usage_count: usage_count,
      days_since_creation: days_since_creation,
      days_since_last_use: days_since_last_use,
      usage_frequency: days_since_creation > 0 ? (usage_count.to_f / days_since_creation).round(2) : 0,
      recently_used: days_since_last_use && days_since_last_use <= 7,
      stale_credentials: days_since_last_use && days_since_last_use > 30
    }
  end
  
  # Rotation and Lifecycle Management
  
  # Check if credentials need rotation
  # @return [Boolean] True if rotation is due or overdue
  def rotation_due?
    Date.today >= @rotation_due_at
  end
  
  # Check if credentials are approaching rotation date
  # @return [Boolean] True if rotation is due within warning period
  def rotation_warning?
    (Date.today + WARNING_DAYS_BEFORE_ROTATION) >= @rotation_due_at
  end
  
  # Get days until rotation is due
  # @return [Integer] Days until rotation (negative if overdue)
  def days_until_rotation
    (@rotation_due_at - Date.today).to_i
  end
  
  # Check if credentials have exceeded maximum age
  # @return [Boolean] True if credentials are too old
  def expired?
    age_in_days = (Date.today - @created_at).to_i
    age_in_days > MAX_CREDENTIAL_AGE_DAYS
  end
  
  # Rotate credentials (create new instance with updated rotation date)
  # @param new_rotation_days [Integer] Days until next rotation
  # @return [ApiCredentials] New credentials instance with extended rotation date
  def rotate(new_rotation_days = DEFAULT_ROTATION_DAYS)
    new_rotation_date = Date.today + new_rotation_days
    
    self.class.new(
      credential_id: @credential_id,
      team_id: @team_id,
      credential_type: @credential_type,
      api_key_id: @api_key_id,
      api_issuer_id: @api_issuer_id,
      api_key_path: @api_key_path,
      apple_id: @apple_id,
      security_level: @security_level,
      created_at: @created_at,
      last_used_at: @last_used_at,
      rotation_due_at: new_rotation_date,
      metadata: @metadata.merge('last_rotated_at' => Date.today.iso8601)
    )
  end
  
  # Security Assessment
  
  # Calculate overall security score (0-100)
  # @return [Integer] Security score
  def calculate_security_score
    score = 50  # Base score
    
    # Credential type scoring
    score += 20 if app_store_connect?  # API keys more secure than passwords
    score -= 10 if apple_id_authentication?  # Passwords less secure
    
    # Security level scoring
    case @security_level
    when 'high'
      score += 20
    when 'medium'
      score += 10
    when 'low'
      score -= 10
    end
    
    # File security scoring
    if api_key_file_exists?
      file_validation = validate_api_key_file
      score += 10 if file_validation.secure_permissions?
      score -= 15 unless file_validation.valid?
    end
    
    # Rotation scoring
    score -= 20 if rotation_due?
    score -= 10 if expired?
    score += 5 if rotation_warning? && !rotation_due?  # Proactive rotation planning
    
    # Usage pattern scoring
    analytics = usage_analytics
    score -= 5 if analytics[:stale_credentials]
    score += 5 if analytics[:recently_used]
    
    [0, [score, 100].min].max  # Clamp between 0-100
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
  # @return [ApiCredentials] New instance with updated metadata
  def with_metadata(key, value)
    new_metadata = @metadata.dup
    new_metadata[key.to_s] = value
    
    self.class.new(
      credential_id: @credential_id,
      team_id: @team_id,
      credential_type: @credential_type,
      api_key_id: @api_key_id,
      api_issuer_id: @api_issuer_id,
      api_key_path: @api_key_path,
      apple_id: @apple_id,
      security_level: @security_level,
      created_at: @created_at,
      last_used_at: @last_used_at,
      rotation_due_at: @rotation_due_at,
      metadata: new_metadata
    )
  end
  
  # Comparison and Equality
  
  # Check equality with another credential set
  # @param other [ApiCredentials] Other credentials to compare
  # @return [Boolean] True if credentials are equal
  def ==(other)
    return false unless other.is_a?(ApiCredentials)
    @credential_id == other.credential_id
  end
  
  # Generate hash for credentials (useful for Set operations)
  # @return [Integer] Hash value
  def hash
    @credential_id.hash
  end
  
  # Serialization and Display
  
  # Convert credentials to hash representation (excludes sensitive data)
  # @return [Hash] Credentials data as hash
  def to_hash
    {
      credential_id: @credential_id,
      team_id: @team_id,
      credential_type: @credential_type,
      api_key_id: @api_key_id,
      api_issuer_id: @api_issuer_id,
      api_key_path: @api_key_path,
      apple_id: @apple_id,
      security_level: @security_level,
      created_at: @created_at.iso8601,
      last_used_at: @last_used_at&.iso8601,
      rotation_due_at: @rotation_due_at.iso8601,
      metadata: @metadata.reject { |k, v| k.to_s.include?('password') || k.to_s.include?('secret') },
      validation: {
        rotation_due: rotation_due?,
        rotation_warning: rotation_warning?,
        expired: expired?,
        security_score: calculate_security_score,
        days_until_rotation: days_until_rotation
      },
      analytics: usage_analytics
    }
  end
  
  # Convert to secure audit log format (hides sensitive information)
  # @return [String] Formatted audit log entry
  def to_audit_log
    type_info = app_store_connect? ? "API Key #{@api_key_id}" : "Apple ID #{@apple_id}"
    status = rotation_due? ? "⚠️ ROTATION DUE" : "✅ ACTIVE"
    
    "[#{@team_id}] #{type_info} - #{status} (Security: #{@security_level}, Score: #{calculate_security_score})"
  end
  
  # String representation of credentials (secure)
  # @return [String] Human-readable credentials description
  def to_s
    type_display = app_store_connect? ? "App Store Connect (#{@api_key_id})" : "Apple ID (#{@apple_id})"
    "Credentials #{@credential_id}: #{type_display} for Team #{@team_id}"
  end
  
  # Detailed string representation (secure)
  # @return [String] Detailed credentials information
  def inspect
    "#<ApiCredentials:#{object_id} id='#{@credential_id}' type=#{@credential_type} " \
    "team=#{@team_id} security=#{@security_level} score=#{calculate_security_score}>"
  end
  
  # Class Methods
  
  class << self
    # Generate unique credential ID
    # @param team_id [String] Team ID
    # @param credential_type [String] Type of credentials
    # @return [String] Unique credential ID
    def generate_credential_id(team_id, credential_type)
      timestamp = Time.now.strftime('%Y%m%d')
      type_prefix = credential_type == 'app_store_connect' ? 'ASC' : 'AID'
      random_suffix = SecureRandom.hex(3).upcase
      
      "#{team_id}_#{type_prefix}_#{timestamp}_#{random_suffix}"
    end
    
    # Create App Store Connect credentials
    # @param team_id [String] Team ID
    # @param api_key_id [String] API Key ID
    # @param api_issuer_id [String] API Issuer ID
    # @param api_key_path [String] Path to P8 file
    # @param security_level [String] Security level
    # @return [ApiCredentials] App Store Connect credentials
    def app_store_connect(team_id:, api_key_id:, api_issuer_id:, api_key_path:, security_level: 'high')
      credential_id = generate_credential_id(team_id, 'app_store_connect')
      
      new(
        credential_id: credential_id,
        team_id: team_id,
        credential_type: 'app_store_connect',
        api_key_id: api_key_id,
        api_issuer_id: api_issuer_id,
        api_key_path: api_key_path,
        security_level: security_level
      )
    end
    
    # Create Apple ID credentials
    # @param team_id [String] Team ID
    # @param apple_id [String] Apple ID email
    # @param security_level [String] Security level
    # @return [ApiCredentials] Apple ID credentials
    def apple_id(team_id:, apple_id:, security_level: 'medium')
      credential_id = generate_credential_id(team_id, 'apple_id')
      
      new(
        credential_id: credential_id,
        team_id: team_id,
        credential_type: 'apple_id',
        apple_id: apple_id,
        security_level: security_level
      )
    end
  end
  
  private
  
  # Validate initialization parameters
  def validate_initialization_parameters(credential_id, team_id, credential_type, api_key_id,
                                       api_issuer_id, api_key_path, apple_id, security_level)
    raise ArgumentError, "Credential ID cannot be nil or empty" if credential_id.nil? || credential_id.to_s.strip.empty?
    raise ArgumentError, "Team ID cannot be nil or empty" if team_id.nil? || team_id.to_s.strip.empty?
    
    unless team_id.to_s.match?(/^[A-Z0-9]{10}$/)
      raise ArgumentError, "Invalid team ID format: #{team_id}"
    end
    
    unless CREDENTIAL_TYPES.include?(credential_type.to_s.downcase)
      raise ArgumentError, "Invalid credential type: #{credential_type}. Must be one of: #{CREDENTIAL_TYPES.join(', ')}"
    end
    
    unless SECURITY_LEVELS.include?(security_level.to_s.downcase)
      raise ArgumentError, "Invalid security level: #{security_level}. Must be one of: #{SECURITY_LEVELS.join(', ')}"
    end
    
    # Validate required fields based on credential type
    case credential_type.to_s.downcase
    when 'app_store_connect'
      validate_app_store_connect_parameters(api_key_id, api_issuer_id, api_key_path)
    when 'apple_id'
      validate_apple_id_parameters(apple_id)
    end
  end
  
  # Validate App Store Connect specific parameters
  def validate_app_store_connect_parameters(api_key_id, api_issuer_id, api_key_path)
    raise ArgumentError, "API Key ID required for App Store Connect credentials" if api_key_id.nil? || api_key_id.to_s.strip.empty?
    raise ArgumentError, "API Issuer ID required for App Store Connect credentials" if api_issuer_id.nil? || api_issuer_id.to_s.strip.empty?
    raise ArgumentError, "API Key path required for App Store Connect credentials" if api_key_path.nil? || api_key_path.to_s.strip.empty?
    
    unless api_key_id.to_s.match?(API_KEY_ID_REGEX)
      raise ArgumentError, "Invalid API Key ID format: #{api_key_id}"
    end
    
    unless api_issuer_id.to_s.match?(API_ISSUER_ID_REGEX)
      raise ArgumentError, "Invalid API Issuer ID format: #{api_issuer_id}"
    end
  end
  
  # Validate Apple ID specific parameters
  def validate_apple_id_parameters(apple_id)
    raise ArgumentError, "Apple ID required for Apple ID credentials" if apple_id.nil? || apple_id.to_s.strip.empty?
    
    unless apple_id.to_s.match?(/\A[^@\s]+@[^@\s]+\z/)
      raise ArgumentError, "Invalid Apple ID email format: #{apple_id}"
    end
  end
  
  # Parse date from various formats
  def parse_date(date_input)
    case date_input
    when Date
      date_input
    when Time, DateTime
      date_input.to_date
    when String
      Date.parse(date_input)
    else
      raise ArgumentError, "Invalid date format: #{date_input.class}"
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
  
  # Calculate when rotation is due
  def calculate_rotation_due_date
    @created_at + DEFAULT_ROTATION_DAYS
  end
  
  # Calculate validation checksum for integrity verification
  def calculate_validation_checksum
    data = "#{@credential_id}:#{@team_id}:#{@credential_type}:#{@api_key_id}:#{@created_at.iso8601}"
    Digest::SHA256.hexdigest(data)[0, 8]  # First 8 characters for brevity
  end
  
  # Validate App Store Connect credentials
  def validate_app_store_connect_credentials
    errors = []
    
    unless @api_key_id&.match?(API_KEY_ID_REGEX)
      errors << "Invalid API Key ID format"
    end
    
    unless @api_issuer_id&.match?(API_ISSUER_ID_REGEX)
      errors << "Invalid API Issuer ID format"
    end
    
    unless api_key_file_exists?
      errors << "API key file not found or not accessible"
    else
      file_validation = validate_api_key_file
      errors.concat(file_validation.errors) unless file_validation.valid?
    end
    
    errors
  end
  
  # Validate Apple ID credentials
  def validate_apple_id_credentials
    errors = []
    
    unless @apple_id&.match?(/\A[^@\s]+@[^@\s]+\z/)
      errors << "Invalid Apple ID email format"
    end
    
    errors
  end
  
  # Validate security requirements
  def validate_security_requirements
    warnings = []
    
    if @security_level == 'low'
      warnings << "Low security level may not be suitable for production use"
    end
    
    if app_store_connect? && @security_level != 'high'
      warnings << "App Store Connect credentials should use high security level"
    end
    
    warnings
  end
  
  # Validate rotation status
  def validate_rotation_status
    warnings = []
    
    if rotation_due?
      warnings << "Credentials rotation is overdue by #{-days_until_rotation} days"
    elsif rotation_warning?
      warnings << "Credentials rotation due in #{days_until_rotation} days"
    end
    
    if expired?
      warnings << "Credentials have exceeded maximum age (#{MAX_CREDENTIAL_AGE_DAYS} days)"
    end
    
    warnings
  end
  
  # Generate security recommendations
  def generate_security_recommendations(errors, warnings)
    recommendations = []
    
    unless errors.empty?
      recommendations << "Fix validation errors before using credentials in production"
    end
    
    if rotation_due?
      recommendations << "Rotate credentials immediately to maintain security"
    elsif rotation_warning?
      recommendations << "Plan credential rotation within the next #{days_until_rotation} days"
    end
    
    if @security_level == 'low' && app_store_connect?
      recommendations << "Upgrade to high security level for App Store Connect credentials"
    end
    
    analytics = usage_analytics
    if analytics[:stale_credentials]
      recommendations << "Review credential usage - not used for #{analytics[:days_since_last_use]} days"
    end
    
    recommendations
  end
end

# Credential validation result
class CredentialValidationResult
  attr_reader :valid, :errors, :warnings, :security_score, :recommendations
  
  def initialize(valid:, errors:, warnings:, security_score:, recommendations:)
    @valid = valid
    @errors = errors
    @warnings = warnings
    @security_score = security_score
    @recommendations = recommendations
  end
  
  def valid?
    @valid
  end
  
  def has_warnings?
    !@warnings.empty?
  end
  
  def secure?
    @security_score >= 70
  end
end

# API key file validation result
class ApiKeyFileValidation
  attr_reader :valid, :errors, :warnings, :file_permissions, :file_size, :secure_permissions
  
  def initialize(valid:, errors: [], warnings: [], file_permissions: nil, 
                 file_size: nil, secure_permissions: false, error: nil)
    @valid = valid
    @errors = error ? [error] : (errors || [])
    @warnings = warnings || []
    @file_permissions = file_permissions
    @file_size = file_size
    @secure_permissions = secure_permissions
  end
  
  def valid?
    @valid
  end
  
  def secure_permissions?
    @secure_permissions
  end
end