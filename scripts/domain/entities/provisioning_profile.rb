# ProvisioningProfile Domain Entity - Clean Architecture Domain Layer
# Pure business object representing an iOS provisioning profile

require 'date'

class ProvisioningProfile
  # Apple Developer Portal Profile Business Rules
  DEVELOPMENT_TYPE = 'development'.freeze
  DISTRIBUTION_TYPE = 'distribution'.freeze
  APPSTORE_TYPE = 'appstore'.freeze
  ADHOC_TYPE = 'adhoc'.freeze
  VALID_TYPES = [DEVELOPMENT_TYPE, DISTRIBUTION_TYPE, APPSTORE_TYPE, ADHOC_TYPE].freeze
  
  EXPIRATION_WARNING_DAYS = 30
  FILE_EXTENSION = '.mobileprovision'.freeze
  
  attr_reader :uuid, :name, :type, :app_identifier, :team_id, :expiration_date, 
              :creation_date, :certificate_ids, :device_ids, :file_path, :platform
  
  # Initialize ProvisioningProfile entity
  # @param uuid [String] Unique profile UUID
  # @param name [String] Profile name/display name  
  # @param type [String] Profile type ('development', 'distribution', 'appstore', 'adhoc')
  # @param app_identifier [String] Bundle identifier this profile covers
  # @param team_id [String] Apple Developer Team ID (10 alphanumeric characters)
  # @param expiration_date [Date, String] Profile expiration date
  # @param certificate_ids [Array<String>] Certificate IDs associated with this profile
  # @param creation_date [Date, String, nil] Profile creation date (optional)
  # @param device_ids [Array<String>, nil] Device UDIDs for development/adhoc profiles (optional)
  # @param file_path [String, nil] Local file path to .mobileprovision file (optional)
  # @param platform [String] Platform ('ios', 'tvos', 'watchos') default: 'ios'
  def initialize(uuid:, name:, type:, app_identifier:, team_id:, expiration_date:, certificate_ids:,
                 creation_date: nil, device_ids: nil, file_path: nil, platform: 'ios')
    validate_initialization_parameters(uuid, name, type, app_identifier, team_id, expiration_date, certificate_ids)
    
    @uuid = uuid.to_s
    @name = name.to_s
    @type = normalize_type(type)
    @app_identifier = app_identifier.to_s
    @team_id = team_id.to_s
    @expiration_date = parse_date(expiration_date)
    @certificate_ids = Array(certificate_ids).map(&:to_s)
    @creation_date = creation_date ? parse_date(creation_date) : nil
    @device_ids = device_ids ? Array(device_ids).map(&:to_s) : []
    @file_path = file_path&.to_s
    @platform = platform.to_s.downcase
  end
  
  # Business Logic Methods
  
  # Check if profile is expired
  # @return [Boolean] True if profile is expired
  def expired?
    @expiration_date < Date.today
  end
  
  # Check if profile is valid (not expired)
  # @return [Boolean] True if profile is valid
  def valid?
    !expired?
  end
  
  # Check if profile is expiring soon
  # @param days_ahead [Integer] Number of days to check ahead (default: 30)
  # @return [Boolean] True if profile expires within the specified days
  def expiring_soon?(days_ahead = EXPIRATION_WARNING_DAYS)
    return true if expired?
    days_until_expiration <= days_ahead
  end
  
  # Calculate days until expiration
  # @return [Integer] Number of days until expiration (negative if expired)
  def days_until_expiration
    (@expiration_date - Date.today).to_i
  end
  
  # Check if profile is valid for specific team
  # @param target_team_id [String] Team ID to validate against
  # @return [Boolean] True if profile belongs to the team
  def valid_for_team?(target_team_id)
    return false if target_team_id.nil? || target_team_id.empty?
    @team_id == target_team_id.to_s
  end
  
  # Check if profile covers specific app identifier
  # Business rule: Profile app_identifier must match exactly or be a wildcard parent
  # @param bundle_id [String] Bundle identifier to check
  # @return [Boolean] True if profile covers the bundle identifier
  def covers_app_identifier?(bundle_id)
    return false if bundle_id.nil? || bundle_id.empty?
    return false if @app_identifier.nil? || @app_identifier.empty?
    
    # Exact match
    return true if @app_identifier == bundle_id
    
    # Wildcard match (e.g., com.company.* covers com.company.myapp and com.company)
    if @app_identifier.end_with?('*')
      wildcard_prefix = @app_identifier[0..-2]  # Remove the *
      # Handle exact match with base (com.voiceforms.* should cover com.voiceforms)
      if wildcard_prefix.end_with?('.')
        base_prefix = wildcard_prefix[0..-2]  # Remove the dot too
        return bundle_id == base_prefix || bundle_id.start_with?(wildcard_prefix)
      else
        return bundle_id.start_with?(wildcard_prefix)
      end
    end
    
    false
  end
  
  # Check if profile type is development
  # @return [Boolean] True if profile is for development
  def development?
    @type == DEVELOPMENT_TYPE
  end
  
  # Check if profile type is distribution (AppStore or Ad Hoc)
  # @return [Boolean] True if profile is for distribution
  def distribution?
    @type == DISTRIBUTION_TYPE || @type == APPSTORE_TYPE || @type == ADHOC_TYPE
  end
  
  # Check if profile type is specifically AppStore distribution
  # @return [Boolean] True if profile is for App Store distribution
  def appstore?
    @type == APPSTORE_TYPE || @type == DISTRIBUTION_TYPE
  end
  
  # Check if profile type is Ad Hoc distribution
  # @return [Boolean] True if profile is for Ad Hoc distribution
  def adhoc?
    @type == ADHOC_TYPE
  end
  
  # Check if profile contains specific certificate
  # @param certificate_id [String] Certificate ID to check
  # @return [Boolean] True if profile includes the certificate
  def contains_certificate?(certificate_id)
    return false if certificate_id.nil? || certificate_id.empty?
    @certificate_ids.include?(certificate_id.to_s)
  end
  
  # Check if profile contains any of the provided certificates
  # @param certificate_ids [Array<String>] Certificate IDs to check
  # @return [Boolean] True if profile includes any of the certificates
  def contains_any_certificate?(certificate_ids)
    return false if certificate_ids.nil? || certificate_ids.empty?
    Array(certificate_ids).any? { |cert_id| contains_certificate?(cert_id) }
  end
  
  # Check if profile contains all required certificates
  # @param certificate_ids [Array<String>] Certificate IDs to check
  # @return [Boolean] True if profile includes all certificates
  def contains_all_certificates?(certificate_ids)
    return true if certificate_ids.nil? || certificate_ids.empty?
    Array(certificate_ids).all? { |cert_id| contains_certificate?(cert_id) }
  end
  
  # Check if profile type matches build configuration
  # @param configuration [String] Build configuration ('Debug', 'Release', etc.)
  # @return [Boolean] True if profile type matches configuration
  def matches_configuration?(configuration)
    case configuration&.downcase
    when 'debug', 'development'
      development?
    when 'release', 'production', 'appstore'
      appstore?
    when 'adhoc', 'ad-hoc', 'ad_hoc'
      adhoc?
    else
      false
    end
  end
  
  # Check if profile supports device (for development/adhoc profiles)
  # @param device_udid [String] Device UDID to check
  # @return [Boolean] True if profile includes the device (always true for App Store profiles)
  def supports_device?(device_udid)
    # App Store profiles don't restrict devices
    return true if appstore?
    
    # Development and Ad Hoc profiles require device registration
    return false if device_udid.nil? || device_udid.empty?
    @device_ids.include?(device_udid.to_s)
  end
  
  # Get expected file name for this profile
  # @return [String] Suggested file name with .mobileprovision extension
  def expected_filename
    safe_name = @name.gsub(/[^A-Za-z0-9_\-]/, '_')
    "#{safe_name}#{FILE_EXTENSION}"
  end
  
  # Check if profile has associated file
  # @return [Boolean] True if profile has a file path and file exists
  def has_file?
    return false if @file_path.nil? || @file_path.empty?
    File.exist?(@file_path)
  end
  
  # Profile Status and Health
  
  # Get profile health status
  # @return [Symbol] :healthy, :expiring_soon, :expired, :missing_file
  def health_status
    return :expired if expired?
    return :missing_file if !@file_path.nil? && !has_file?
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
    when :missing_file
      "Missing file (#{@file_path})"
    end
  end
  
  # Profile Type Utilities
  
  # Get profile type for display
  # @return [String] Capitalized type name
  def type_display
    case @type
    when DEVELOPMENT_TYPE
      'Development'
    when DISTRIBUTION_TYPE, APPSTORE_TYPE
      'App Store'
    when ADHOC_TYPE
      'Ad Hoc'
    else
      @type.capitalize
    end
  end
  
  # Get profile icon/emoji for display
  # @return [String] Emoji representing profile type
  def type_icon
    case @type
    when DEVELOPMENT_TYPE
      '🔧'
    when DISTRIBUTION_TYPE, APPSTORE_TYPE
      '🏪'
    when ADHOC_TYPE
      '📱'
    else
      '📄'
    end
  end
  
  # Get platform icon/emoji
  # @return [String] Emoji representing platform
  def platform_icon
    case @platform.downcase
    when 'ios'
      '📱'
    when 'tvos'
      '📺'
    when 'watchos'
      '⌚'
    else
      '💻'
    end
  end
  
  # Comparison and Equality
  
  # Check equality with another profile
  # @param other [ProvisioningProfile] Other profile to compare
  # @return [Boolean] True if profiles are equal
  def ==(other)
    return false unless other.is_a?(ProvisioningProfile)
    @uuid == other.uuid && @team_id == other.team_id
  end
  
  # Generate hash for profile (useful for Set operations)
  # @return [Integer] Hash value
  def hash
    [@uuid, @team_id].hash
  end
  
  # Compare profiles for sorting (by expiration date, then type, then name)
  # @param other [ProvisioningProfile] Other profile to compare
  # @return [Integer] -1, 0, or 1 for sorting
  def <=>(other)
    return 0 unless other.is_a?(ProvisioningProfile)
    
    # First by expiration date (earlier dates first for expired profiles)
    result = @expiration_date <=> other.expiration_date
    return result unless result == 0
    
    # Then by type (development before distribution)
    result = @type <=> other.type
    return result unless result == 0
    
    # Finally by name
    @name <=> other.name
  end
  
  # Serialization and Display
  
  # Convert profile to hash representation
  # @return [Hash] Profile data as hash
  def to_hash
    {
      uuid: @uuid,
      name: @name,
      type: @type,
      app_identifier: @app_identifier,
      team_id: @team_id,
      platform: @platform,
      expiration_date: @expiration_date.iso8601,
      creation_date: @creation_date&.iso8601,
      certificate_ids: @certificate_ids,
      device_ids: @device_ids,
      file_path: @file_path,
      valid: valid?,
      expired: expired?,
      expiring_soon: expiring_soon?,
      days_until_expiration: days_until_expiration,
      health_status: health_status,
      status_description: status_description,
      covers_wildcard: @app_identifier.include?('*'),
      device_count: @device_ids.length,
      certificate_count: @certificate_ids.length,
      has_file: has_file?
    }
  end
  
  # Convert profile to JSON representation
  # @return [String] Profile data as JSON
  def to_json(*args)
    require 'json'
    to_hash.to_json(*args)
  end
  
  # String representation of profile
  # @return [String] Human-readable profile description
  def to_s
    "#{type_icon} #{@name} (#{type_display}) - #{@app_identifier} - #{status_description}"
  end
  
  # Detailed string representation
  # @return [String] Detailed profile information
  def inspect
    "#<ProvisioningProfile:#{object_id} uuid=#{@uuid} name='#{@name}' type=#{@type} app_id=#{@app_identifier} team_id=#{@team_id} expires=#{@expiration_date} valid=#{valid?}>"
  end
  
  # Class Methods for Business Logic
  
  class << self
    # Check if app identifier is wildcard
    # @param app_identifier [String] Bundle identifier to check
    # @return [Boolean] True if identifier contains wildcard
    def wildcard_app_identifier?(app_identifier)
      app_identifier.to_s.include?('*')
    end
    
    # Extract base identifier from wildcard
    # @param app_identifier [String] Wildcard bundle identifier
    # @return [String] Base identifier without wildcard
    def base_identifier_from_wildcard(app_identifier)
      return app_identifier unless wildcard_app_identifier?(app_identifier)
      app_identifier.gsub(/\.\*$/, '')
    end
    
    # Check if two app identifiers are compatible
    # @param profile_identifier [String] Profile's app identifier (may have wildcard)
    # @param target_identifier [String] Target app bundle identifier
    # @return [Boolean] True if identifiers are compatible
    def identifiers_compatible?(profile_identifier, target_identifier)
      return false if profile_identifier.nil? || target_identifier.nil?
      
      # Exact match
      return true if profile_identifier == target_identifier
      
      # Wildcard match
      if wildcard_app_identifier?(profile_identifier)
        base = base_identifier_from_wildcard(profile_identifier)
        return target_identifier.start_with?(base)
      end
      
      false
    end
    
    # Validate profile type
    # @param type [String] Profile type to validate
    # @return [Boolean] True if type is valid
    def valid_type?(type)
      VALID_TYPES.include?(normalize_type(type))
    end
    
    # Normalize profile type to standard format
    # @param type [String] Raw profile type
    # @return [String] Normalized type
    def normalize_type(type)
      normalized = type.to_s.downcase
      case normalized
      when 'development', 'dev', 'debug'
        DEVELOPMENT_TYPE
      when 'distribution', 'dist', 'appstore', 'app-store', 'app_store', 'release', 'production'
        APPSTORE_TYPE
      when 'adhoc', 'ad-hoc', 'ad_hoc'
        ADHOC_TYPE
      else
        # Handle Apple's specific naming patterns
        return DEVELOPMENT_TYPE if normalized.include?('development')
        return APPSTORE_TYPE if normalized.include?('distribution') || normalized.include?('appstore')
        return ADHOC_TYPE if normalized.include?('adhoc') || normalized.include?('ad hoc')
        normalized
      end
    end
    
    # Determine required profile type for configuration
    # @param configuration [String] Build configuration
    # @return [String] Required profile type
    def required_type_for_configuration(configuration)
      case configuration&.downcase
      when 'debug', 'development'
        DEVELOPMENT_TYPE
      when 'release', 'production', 'appstore'
        APPSTORE_TYPE
      when 'adhoc', 'ad-hoc', 'ad_hoc'
        ADHOC_TYPE
      else
        DEVELOPMENT_TYPE
      end
    end
    
    # Create profile from Apple Developer Portal data
    # @param portal_data [Hash] Data from Apple Developer Portal API
    # @return [ProvisioningProfile] Profile entity
    def from_portal_data(portal_data)
      new(
        uuid: portal_data[:uuid] || portal_data['uuid'] || portal_data[:id],
        name: portal_data[:name] || portal_data['name'],
        type: portal_data[:type] || portal_data['type'] || portal_data[:profile_type],
        app_identifier: portal_data[:app_identifier] || portal_data['app_identifier'] || portal_data[:bundleId],
        team_id: portal_data[:team_id] || portal_data['team_id'],
        expiration_date: portal_data[:expiration_date] || portal_data['expiration_date'],
        certificate_ids: portal_data[:certificate_ids] || portal_data['certificate_ids'] || [],
        creation_date: portal_data[:creation_date] || portal_data['creation_date'],
        device_ids: portal_data[:device_ids] || portal_data['device_ids'] || [],
        file_path: portal_data[:file_path] || portal_data['file_path'],
        platform: portal_data[:platform] || portal_data['platform'] || 'ios'
      )
    end
    
    # Create profile from .mobileprovision file
    # @param file_path [String] Path to .mobileprovision file
    # @return [ProvisioningProfile] Profile entity
    def from_file(file_path)
      raise ArgumentError, "File does not exist: #{file_path}" unless File.exist?(file_path)
      raise ArgumentError, "File is not a .mobileprovision: #{file_path}" unless file_path.end_with?(FILE_EXTENSION)
      
      # This would normally parse the plist data from the .mobileprovision file
      # For now, create a minimal profile with file path
      filename = File.basename(file_path, FILE_EXTENSION)
      
      new(
        uuid: "FILE_#{rand(100000)}",  # Placeholder - would extract from plist
        name: filename,
        type: filename.downcase.include?('development') ? DEVELOPMENT_TYPE : APPSTORE_TYPE,
        app_identifier: 'unknown',  # Would extract from plist
        team_id: 'UNKNOWN123',  # Would extract from plist
        expiration_date: Date.today + 365,  # Would extract from plist
        certificate_ids: [],  # Would extract from plist
        file_path: file_path
      )
    end
  end
  
  private
  
  # Validate initialization parameters
  def validate_initialization_parameters(uuid, name, type, app_identifier, team_id, expiration_date, certificate_ids)
    raise ArgumentError, "Profile UUID cannot be nil or empty" if uuid.nil? || uuid.to_s.empty?
    raise ArgumentError, "Profile name cannot be nil or empty" if name.nil? || name.to_s.empty?
    raise ArgumentError, "Invalid profile type: #{type}" unless self.class.valid_type?(type)
    raise ArgumentError, "App identifier cannot be nil or empty" if app_identifier.nil? || app_identifier.to_s.empty?
    raise ArgumentError, "Team ID must be 10 alphanumeric characters" unless team_id.to_s.match?(/^[A-Z0-9]{10}$/)
    raise ArgumentError, "Expiration date cannot be nil" if expiration_date.nil?
    raise ArgumentError, "Certificate IDs cannot be nil" if certificate_ids.nil?
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
  
  # Normalize profile type (instance method)
  def normalize_type(type)
    self.class.normalize_type(type)
  end
end