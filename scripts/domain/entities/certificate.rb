# Certificate Domain Entity - Clean Architecture Domain Layer
# Pure business object representing an iOS development certificate

require 'date'

class Certificate
  # Apple Developer Portal Certificate Limits (Business Rules)
  DEVELOPMENT_LIMIT = 2
  DISTRIBUTION_LIMIT = 3
  EXPIRATION_WARNING_DAYS = 30
  
  # Certificate Types
  DEVELOPMENT_TYPE = 'development'.freeze
  DISTRIBUTION_TYPE = 'distribution'.freeze
  VALID_TYPES = [DEVELOPMENT_TYPE, DISTRIBUTION_TYPE].freeze
  
  attr_reader :id, :name, :type, :team_id, :expiration_date, :created_date, :serial_number, :thumbprint
  
  # Initialize Certificate entity
  # @param id [String] Unique certificate identifier
  # @param name [String] Certificate name/common name
  # @param type [String] Certificate type ('development' or 'distribution')
  # @param team_id [String] Apple Developer Team ID (10 alphanumeric characters)
  # @param expiration_date [Date, String] Certificate expiration date
  # @param created_date [Date, String, nil] Certificate creation date (optional)
  # @param serial_number [String, nil] Certificate serial number (optional)
  # @param thumbprint [String, nil] Certificate thumbprint/fingerprint (optional)
  def initialize(id:, name:, type:, team_id:, expiration_date:, created_date: nil, serial_number: nil, thumbprint: nil)
    validate_initialization_parameters(id, name, type, team_id, expiration_date)
    
    @id = id.to_s
    @name = name.to_s
    @type = normalize_type(type)
    @team_id = team_id.to_s
    @expiration_date = parse_date(expiration_date)
    @created_date = created_date ? parse_date(created_date) : nil
    @serial_number = serial_number&.to_s
    @thumbprint = thumbprint&.to_s
  end
  
  # Business Logic Methods
  
  # Check if certificate is expired
  # @return [Boolean] True if certificate is expired
  def expired?
    @expiration_date < Date.today
  end
  
  # Check if certificate is valid (not expired)
  # @return [Boolean] True if certificate is valid
  def valid?
    !expired?
  end
  
  # Check if certificate is expiring soon
  # @param days_ahead [Integer] Number of days to check ahead (default: 30)
  # @return [Boolean] True if certificate expires within the specified days
  def expiring_soon?(days_ahead = EXPIRATION_WARNING_DAYS)
    return true if expired?
    days_until_expiration <= days_ahead
  end
  
  # Calculate days until expiration
  # @return [Integer] Number of days until expiration (negative if expired)
  def days_until_expiration
    (@expiration_date - Date.today).to_i
  end
  
  # Check if certificate is valid for specific team
  # @param target_team_id [String] Team ID to validate against
  # @return [Boolean] True if certificate belongs to the team
  def valid_for_team?(target_team_id)
    return false if target_team_id.nil? || target_team_id.empty?
    @team_id == target_team_id.to_s
  end
  
  # Check if certificate is development type
  # @return [Boolean] True if certificate is for development
  def development?
    @type == DEVELOPMENT_TYPE
  end
  
  # Check if certificate is distribution type
  # @return [Boolean] True if certificate is for distribution
  def distribution?
    @type == DISTRIBUTION_TYPE
  end
  
  # Check if certificate can sign for app identifier
  # Business rule: All certificates can sign for any app identifier within their team
  # @param app_identifier [String] Bundle identifier to check
  # @return [Boolean] True if certificate can sign for the app
  def can_sign_for?(app_identifier)
    return false if app_identifier.nil? || app_identifier.empty?
    return false if expired?
    
    # All valid certificates within a team can sign for any app in that team
    true
  end
  
  # Check if certificate type matches configuration
  # @param configuration [String] Build configuration ('Debug', 'Release', etc.)
  # @return [Boolean] True if certificate type matches configuration
  def matches_configuration?(configuration)
    case configuration&.downcase
    when 'debug', 'development'
      development?
    when 'release', 'production', 'appstore'
      distribution?
    else
      false
    end
  end
  
  # Certificate Status and Health
  
  # Get certificate health status
  # @return [Symbol] :healthy, :expiring_soon, :expired
  def health_status
    return :expired if expired?
    return :expiring_soon if expiring_soon?
    :healthy
  end
  
  # Get human-readable status description
  # @return [String] Status description
  def status_description
    case health_status
    when :healthy
      "Valid (expires in #{days_until_expiration} days)"
    when :expiring_soon
      "Expiring soon (#{days_until_expiration} days remaining)"
    when :expired
      "Expired (#{-days_until_expiration} days ago)"
    end
  end
  
  # Certificate Type Utilities
  
  # Get certificate type for display
  # @return [String] Capitalized type name
  def type_display
    @type.capitalize
  end
  
  # Get certificate icon/emoji for display
  # @return [String] Emoji representing certificate type
  def type_icon
    case @type
    when DEVELOPMENT_TYPE
      '🔧'
    when DISTRIBUTION_TYPE
      '📱'
    else
      '📄'
    end
  end
  
  # Comparison and Equality
  
  # Check equality with another certificate
  # @param other [Certificate] Other certificate to compare
  # @return [Boolean] True if certificates are equal
  def ==(other)
    return false unless other.is_a?(Certificate)
    @id == other.id && @team_id == other.team_id
  end
  
  # Generate hash for certificate (useful for Set operations)
  # @return [Integer] Hash value
  def hash
    [@id, @team_id].hash
  end
  
  # Compare certificates for sorting (by expiration date, then type, then name)
  # @param other [Certificate] Other certificate to compare
  # @return [Integer] -1, 0, or 1 for sorting
  def <=>(other)
    return 0 unless other.is_a?(Certificate)
    
    # First by expiration date (earlier dates first for expired certs)
    result = @expiration_date <=> other.expiration_date
    return result unless result == 0
    
    # Then by type (development before distribution)
    result = @type <=> other.type
    return result unless result == 0
    
    # Finally by name
    @name <=> other.name
  end
  
  # Serialization and Display
  
  # Convert certificate to hash representation
  # @return [Hash] Certificate data as hash
  def to_hash
    {
      id: @id,
      name: @name,
      type: @type,
      team_id: @team_id,
      expiration_date: @expiration_date.iso8601,
      created_date: @created_date&.iso8601,
      serial_number: @serial_number,
      thumbprint: @thumbprint,
      valid: valid?,
      expired: expired?,
      expiring_soon: expiring_soon?,
      days_until_expiration: days_until_expiration,
      health_status: health_status,
      status_description: status_description
    }
  end
  
  # Convert certificate to JSON representation
  # @return [String] Certificate data as JSON
  def to_json(*args)
    require 'json'
    to_hash.to_json(*args)
  end
  
  # String representation of certificate
  # @return [String] Human-readable certificate description
  def to_s
    "#{type_icon} #{@name} (#{@type}) - #{status_description}"
  end
  
  # Detailed string representation
  # @return [String] Detailed certificate information
  def inspect
    "#<Certificate:#{object_id} id=#{@id} name='#{@name}' type=#{@type} team_id=#{@team_id} expires=#{@expiration_date} valid=#{valid?}>"
  end
  
  # Class Methods for Business Logic
  
  class << self
    # Check if team is at development certificate limit
    # @param certificate_count [Integer] Current number of development certificates
    # @return [Boolean] True if at or over limit
    def at_development_limit?(certificate_count)
      certificate_count >= DEVELOPMENT_LIMIT
    end
    
    # Check if team is at distribution certificate limit
    # @param certificate_count [Integer] Current number of distribution certificates
    # @return [Boolean] True if at or over limit
    def at_distribution_limit?(certificate_count)
      certificate_count >= DISTRIBUTION_LIMIT
    end
    
    # Get certificate limit for type
    # @param type [String] Certificate type
    # @return [Integer] Maximum allowed certificates of this type
    def limit_for_type(type)
      case normalize_type(type)
      when DEVELOPMENT_TYPE
        DEVELOPMENT_LIMIT
      when DISTRIBUTION_TYPE
        DISTRIBUTION_LIMIT
      else
        0
      end
    end
    
    # Determine cleanup strategy when at limits
    # @param certificate_type [String] Type of certificate to create
    # @param existing_certificates [Array<Certificate>] Current certificates of this type
    # @return [Symbol] Cleanup strategy (:remove_oldest, :remove_expired, :cannot_create)
    def cleanup_strategy(certificate_type, existing_certificates)
      return :cannot_create if existing_certificates.empty?
      
      # First, try to remove expired certificates
      expired_certs = existing_certificates.select(&:expired?)
      return :remove_expired unless expired_certs.empty?
      
      # If no expired certificates, remove oldest valid certificate
      valid_certs = existing_certificates.select(&:valid?)
      return :remove_oldest unless valid_certs.empty?
      
      # This shouldn't happen, but safety fallback
      :cannot_create
    end
    
    # Validate certificate type
    # @param type [String] Certificate type to validate
    # @return [Boolean] True if type is valid
    def valid_type?(type)
      VALID_TYPES.include?(normalize_type(type))
    end
    
    # Normalize certificate type to standard format
    # @param type [String] Raw certificate type
    # @return [String] Normalized type
    def normalize_type(type)
      return DEVELOPMENT_TYPE if type.to_s.downcase.include?('development')
      return DISTRIBUTION_TYPE if type.to_s.downcase.include?('distribution')
      type.to_s.downcase
    end
    
    # Create certificate from Apple Developer Portal data
    # @param portal_data [Hash] Data from Apple Developer Portal API
    # @return [Certificate] Certificate entity
    def from_portal_data(portal_data)
      new(
        id: portal_data[:id] || portal_data['id'],
        name: portal_data[:name] || portal_data['name'],
        type: portal_data[:certificate_type] || portal_data['certificate_type'] || portal_data[:type],
        team_id: portal_data[:team_id] || portal_data['team_id'],
        expiration_date: portal_data[:expiration_date] || portal_data['expiration_date'],
        created_date: portal_data[:created_date] || portal_data['created_date'],
        serial_number: portal_data[:serial_number] || portal_data['serial_number'],
        thumbprint: portal_data[:thumbprint] || portal_data['thumbprint']
      )
    end
  end
  
  private
  
  # Validate initialization parameters
  def validate_initialization_parameters(id, name, type, team_id, expiration_date)
    raise ArgumentError, "Certificate ID cannot be nil or empty" if id.nil? || id.to_s.empty?
    raise ArgumentError, "Certificate name cannot be nil or empty" if name.nil? || name.to_s.empty?
    raise ArgumentError, "Invalid certificate type: #{type}" unless self.class.valid_type?(type)
    raise ArgumentError, "Team ID must be 10 alphanumeric characters" unless team_id.to_s.match?(/^[A-Z0-9]{10}$/)
    raise ArgumentError, "Expiration date cannot be nil" if expiration_date.nil?
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
  
  # Normalize certificate type (instance method)
  def normalize_type(type)
    self.class.normalize_type(type)
  end
end