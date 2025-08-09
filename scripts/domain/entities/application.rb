# Application Domain Entity - Clean Architecture Domain Layer
# Pure business object representing an iOS application with metadata and versioning rules

require 'date'

class Application
  # App Store Business Rules and Constraints
  MAX_APP_NAME_LENGTH = 50
  MAX_SUBTITLE_LENGTH = 30
  MAX_VERSION_LENGTH = 18
  MAX_BUILD_NUMBER = 2147483647  # 32-bit signed integer limit
  
  # Bundle Identifier Validation
  BUNDLE_ID_MIN_LENGTH = 3
  BUNDLE_ID_MAX_LENGTH = 255
  BUNDLE_ID_REGEX = /\A[a-zA-Z0-9.-]+\z/
  REVERSE_DNS_REGEX = /\A[a-zA-Z][a-zA-Z0-9-]*(\.[a-zA-Z][a-zA-Z0-9-]*)+\z/
  
  # Version Management
  VERSION_COMPONENTS = %w[major minor patch].freeze
  SEMANTIC_VERSION_REGEX = /\A(\d+)\.(\d+)\.(\d+)(?:-([0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*))?(?:\+([0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*))?\z/
  
  # Platform Support
  SUPPORTED_PLATFORMS = %w[ios tvos watchos macos].freeze
  DEFAULT_PLATFORM = 'ios'.freeze
  
  attr_reader :bundle_identifier, :name, :display_name, :scheme, :team_id, :platform,
              :marketing_version, :build_number, :created_at, :updated_at, :metadata
  
  # Initialize Application entity
  # @param bundle_identifier [String] Unique app bundle identifier (e.g., com.company.app)
  # @param name [String] Internal app name (for development/CI)
  # @param display_name [String] User-facing app display name (App Store)
  # @param scheme [String] Xcode scheme name for building
  # @param team_id [String] Apple Developer Team ID (10 alphanumeric characters)
  # @param marketing_version [String] User-facing version (e.g., "1.2.3")
  # @param build_number [String, Integer] Internal build number
  # @param platform [String] Target platform ('ios', 'tvos', 'watchos', 'macos')
  # @param created_at [Date, String, nil] Application registration date (optional)
  # @param updated_at [Date, String, nil] Last update date (optional)
  # @param metadata [Hash, nil] Additional application metadata (optional)
  def initialize(bundle_identifier:, name:, display_name:, scheme:, team_id:, 
                 marketing_version:, build_number:, platform: DEFAULT_PLATFORM,
                 created_at: nil, updated_at: nil, metadata: nil)
    validate_initialization_parameters(bundle_identifier, name, display_name, scheme, team_id, 
                                     marketing_version, build_number, platform)
    
    @bundle_identifier = bundle_identifier.to_s.strip
    @name = name.to_s.strip
    @display_name = display_name.to_s.strip
    @scheme = scheme.to_s.strip
    @team_id = team_id.to_s.strip
    @marketing_version = marketing_version.to_s.strip
    @build_number = build_number.to_s
    @platform = platform.to_s.downcase
    @created_at = created_at ? parse_date(created_at) : Date.today
    @updated_at = updated_at ? parse_date(updated_at) : Date.today
    @metadata = metadata ? metadata.dup : {}
  end
  
  # Business Logic Methods
  
  # Validate application is ready for App Store submission
  # @return [Boolean] True if application meets all App Store requirements
  def ready_for_app_store?
    valid_bundle_identifier? &&
    valid_display_name? &&
    valid_marketing_version? &&
    valid_build_number? &&
    supported_platform? &&
    !marketing_version_preview?
  end
  
  # Get list of validation issues preventing App Store submission
  # @return [Array<String>] Array of validation error messages
  def app_store_validation_errors
    errors = []
    
    errors << "Invalid bundle identifier format" unless valid_bundle_identifier?
    errors << "Display name too long (max #{MAX_APP_NAME_LENGTH} chars)" unless valid_display_name?
    errors << "Invalid marketing version format" unless valid_marketing_version?
    errors << "Invalid build number" unless valid_build_number?
    errors << "Unsupported platform: #{@platform}" unless supported_platform?
    errors << "Marketing version contains preview/beta keywords" if marketing_version_preview?
    
    errors
  end
  
  # Bundle Identifier Validation and Business Logic
  
  # Check if bundle identifier is valid according to Apple guidelines
  # @return [Boolean] True if bundle identifier is valid
  def valid_bundle_identifier?
    return false if @bundle_identifier.length < BUNDLE_ID_MIN_LENGTH
    return false if @bundle_identifier.length > BUNDLE_ID_MAX_LENGTH
    return false unless @bundle_identifier.match?(BUNDLE_ID_REGEX)
    return false unless @bundle_identifier.match?(REVERSE_DNS_REGEX)
    return false if @bundle_identifier.start_with?('.')
    return false if @bundle_identifier.end_with?('.')
    return false if @bundle_identifier.include?('..')
    
    true
  end
  
  # Get bundle identifier domain (e.g., "com.company" from "com.company.app")
  # @return [String] Domain portion of bundle identifier
  def bundle_domain
    parts = @bundle_identifier.split('.')
    return @bundle_identifier if parts.length <= 2
    parts[0..-2].join('.')
  end
  
  # Get app name from bundle identifier (e.g., "app" from "com.company.app")
  # @return [String] App name portion of bundle identifier
  def bundle_app_name
    parts = @bundle_identifier.split('.')
    parts.last || @bundle_identifier
  end
  
  # Check if bundle identifier belongs to specific domain
  # @param domain [String] Domain to check (e.g., "com.company")
  # @return [Boolean] True if app belongs to domain
  def belongs_to_domain?(domain)
    return false if domain.nil? || domain.empty?
    @bundle_identifier.start_with?("#{domain}.")
  end
  
  # Version Management Business Logic
  
  # Parse current marketing version into semantic version components
  # @return [Hash] Hash with :major, :minor, :patch, :prerelease, :build_metadata
  def parse_marketing_version
    match = @marketing_version.match(SEMANTIC_VERSION_REGEX)
    return nil unless match
    
    {
      major: match[1].to_i,
      minor: match[2].to_i,
      patch: match[3].to_i,
      prerelease: match[4],
      build_metadata: match[5],
      raw: @marketing_version
    }
  end
  
  # Check if marketing version follows semantic versioning
  # @return [Boolean] True if version is semantic version compatible
  def valid_marketing_version?
    return false if @marketing_version.empty?
    return false if @marketing_version.length > MAX_VERSION_LENGTH
    !parse_marketing_version.nil?
  end
  
  # Check if marketing version contains preview/beta keywords
  # @return [Boolean] True if version contains preview indicators
  def marketing_version_preview?
    preview_keywords = %w[alpha beta rc preview snapshot dev test]
    version_lower = @marketing_version.downcase
    preview_keywords.any? { |keyword| version_lower.include?(keyword) }
  end
  
  # Increment marketing version using semantic versioning rules
  # @param component [String, Symbol] Component to increment ('major', 'minor', 'patch')
  # @return [String] New incremented version
  def increment_marketing_version(component)
    component = component.to_s.downcase
    raise ArgumentError, "Invalid component: #{component}" unless VERSION_COMPONENTS.include?(component)
    
    version_info = parse_marketing_version
    raise ArgumentError, "Invalid current version format" unless version_info
    
    case component
    when 'major'
      "#{version_info[:major] + 1}.0.0"
    when 'minor'
      "#{version_info[:major]}.#{version_info[:minor] + 1}.0"
    when 'patch'
      "#{version_info[:major]}.#{version_info[:minor]}.#{version_info[:patch] + 1}"
    end
  end
  
  # Get next version for given increment type
  # @param increment_type [String, Symbol] Type of increment ('major', 'minor', 'patch')
  # @return [String] Next version string
  def next_version(increment_type)
    increment_marketing_version(increment_type)
  end
  
  # Compare marketing version with another version
  # @param other_version [String] Version to compare against
  # @return [Integer] -1 if less than, 0 if equal, 1 if greater than
  def compare_version(other_version)
    current = parse_marketing_version
    other_app = self.class.new(
      bundle_identifier: @bundle_identifier,
      name: @name,
      display_name: @display_name,
      scheme: @scheme,
      team_id: @team_id,
      marketing_version: other_version,
      build_number: @build_number
    )
    other = other_app.parse_marketing_version
    
    return 0 unless current && other
    
    # Compare major.minor.patch
    [:major, :minor, :patch].each do |component|
      result = current[component] <=> other[component]
      return result unless result == 0
    end
    
    0
  end
  
  # Check if current version is greater than other version
  # @param other_version [String] Version to compare
  # @return [Boolean] True if current version is greater
  def version_greater_than?(other_version)
    compare_version(other_version) > 0
  end
  
  # Build Number Management
  
  # Check if build number is valid
  # @return [Boolean] True if build number is valid
  def valid_build_number?
    return false if @build_number.nil? || @build_number.empty?
    return false unless @build_number.match?(/\A\d+\z/)
    
    build_int = @build_number.to_i
    build_int > 0 && build_int <= MAX_BUILD_NUMBER
  end
  
  # Increment build number
  # @param increment [Integer] Amount to increment (default: 1)
  # @return [String] New build number
  def increment_build_number(increment = 1)
    current_build = @build_number.to_i
    new_build = current_build + increment
    
    raise ArgumentError, "Build number would exceed maximum" if new_build > MAX_BUILD_NUMBER
    
    new_build.to_s
  end
  
  # Get next build number
  # @return [String] Next build number
  def next_build_number
    increment_build_number
  end
  
  # Platform and Configuration
  
  # Check if platform is supported
  # @return [Boolean] True if platform is supported
  def supported_platform?
    SUPPORTED_PLATFORMS.include?(@platform)
  end
  
  # Check if app is for iOS platform
  # @return [Boolean] True if iOS app
  def ios_app?
    @platform == 'ios'
  end
  
  # Check if app is for tvOS platform
  # @return [Boolean] True if tvOS app
  def tvos_app?
    @platform == 'tvos'
  end
  
  # Check if app is for watchOS platform
  # @return [Boolean] True if watchOS app
  def watchos_app?
    @platform == 'watchos'
  end
  
  # Check if app is for macOS platform
  # @return [Boolean] True if macOS app
  def macos_app?
    @platform == 'macos'
  end
  
  # Get platform-specific icon name
  # @return [String] Emoji icon for platform
  def platform_icon
    case @platform
    when 'ios'
      '📱'
    when 'tvos'
      '📺'
    when 'watchos'
      '⌚'
    when 'macos'
      '💻'
    else
      '📦'
    end
  end
  
  # Team and Ownership
  
  # Check if app belongs to specific team
  # @param team_id [String] Team ID to check
  # @return [Boolean] True if app belongs to team
  def belongs_to_team?(team_id)
    return false if team_id.nil? || team_id.empty?
    @team_id == team_id.to_s
  end
  
  # Display and Naming
  
  # Check if display name is valid for App Store
  # @return [Boolean] True if display name is valid
  def valid_display_name?
    return false if @display_name.empty?
    return false if @display_name.length > MAX_APP_NAME_LENGTH
    
    # App Store doesn't allow certain characters
    forbidden_chars = ['<', '>', '"', '&']
    !forbidden_chars.any? { |char| @display_name.include?(char) }
  end
  
  # Get safe filename version of app name
  # @return [String] Filesystem-safe version of display name
  def safe_filename
    @display_name.gsub(/[^A-Za-z0-9_\-]/, '_').gsub(/_+/, '_')
  end
  
  # Metadata Management
  
  # Get metadata value
  # @param key [String, Symbol] Metadata key
  # @return [Object] Metadata value or nil
  def get_metadata(key)
    @metadata[key.to_s] || @metadata[key.to_sym]
  end
  
  # Set metadata value (returns new Application instance)
  # @param key [String, Symbol] Metadata key
  # @param value [Object] Metadata value
  # @return [Application] New Application instance with updated metadata
  def with_metadata(key, value)
    new_metadata = @metadata.dup
    new_metadata[key.to_s] = value
    
    self.class.new(
      bundle_identifier: @bundle_identifier,
      name: @name,
      display_name: @display_name,
      scheme: @scheme,
      team_id: @team_id,
      marketing_version: @marketing_version,
      build_number: @build_number,
      platform: @platform,
      created_at: @created_at,
      updated_at: Date.today,
      metadata: new_metadata
    )
  end
  
  # Version Update Methods (return new instances)
  
  # Create new Application instance with updated marketing version
  # @param new_version [String] New marketing version
  # @return [Application] New Application instance
  def with_marketing_version(new_version)
    self.class.new(
      bundle_identifier: @bundle_identifier,
      name: @name,
      display_name: @display_name,
      scheme: @scheme,
      team_id: @team_id,
      marketing_version: new_version,
      build_number: @build_number,
      platform: @platform,
      created_at: @created_at,
      updated_at: Date.today,
      metadata: @metadata
    )
  end
  
  # Create new Application instance with updated build number
  # @param new_build_number [String, Integer] New build number
  # @return [Application] New Application instance
  def with_build_number(new_build_number)
    self.class.new(
      bundle_identifier: @bundle_identifier,
      name: @name,
      display_name: @display_name,
      scheme: @scheme,
      team_id: @team_id,
      marketing_version: @marketing_version,
      build_number: new_build_number.to_s,
      platform: @platform,
      created_at: @created_at,
      updated_at: Date.today,
      metadata: @metadata
    )
  end
  
  # Create new Application instance with incremented version
  # @param component [String, Symbol] Component to increment ('major', 'minor', 'patch')
  # @return [Application] New Application instance with incremented version
  def with_incremented_version(component)
    new_version = increment_marketing_version(component)
    with_marketing_version(new_version)
  end
  
  # Comparison and Equality
  
  # Check equality with another application
  # @param other [Application] Other application to compare
  # @return [Boolean] True if applications are equal
  def ==(other)
    return false unless other.is_a?(Application)
    @bundle_identifier == other.bundle_identifier && @team_id == other.team_id
  end
  
  # Generate hash for application (useful for Set operations)
  # @return [Integer] Hash value
  def hash
    [@bundle_identifier, @team_id].hash
  end
  
  # Compare applications for sorting (by bundle identifier, then version)
  # @param other [Application] Other application to compare
  # @return [Integer] -1, 0, or 1 for sorting
  def <=>(other)
    return 0 unless other.is_a?(Application)
    
    # First by bundle identifier
    result = @bundle_identifier <=> other.bundle_identifier
    return result unless result == 0
    
    # Then by marketing version
    compare_version(other.marketing_version)
  end
  
  # Serialization and Display
  
  # Convert application to hash representation
  # @return [Hash] Application data as hash
  def to_hash
    {
      bundle_identifier: @bundle_identifier,
      name: @name,
      display_name: @display_name,
      scheme: @scheme,
      team_id: @team_id,
      platform: @platform,
      marketing_version: @marketing_version,
      build_number: @build_number,
      created_at: @created_at.iso8601,
      updated_at: @updated_at.iso8601,
      metadata: @metadata,
      version_info: parse_marketing_version,
      validation: {
        ready_for_app_store: ready_for_app_store?,
        validation_errors: app_store_validation_errors,
        valid_bundle_id: valid_bundle_identifier?,
        valid_display_name: valid_display_name?,
        valid_version: valid_marketing_version?,
        valid_build_number: valid_build_number?,
        supported_platform: supported_platform?
      }
    }
  end
  
  # Convert application to JSON representation
  # @return [String] Application data as JSON
  def to_json(*args)
    require 'json'
    to_hash.to_json(*args)
  end
  
  # String representation of application
  # @return [String] Human-readable application description
  def to_s
    "#{platform_icon} #{@display_name} (#{@bundle_identifier}) - v#{@marketing_version} (#{@build_number})"
  end
  
  # Detailed string representation
  # @return [String] Detailed application information
  def inspect
    "#<Application:#{object_id} bundle_id='#{@bundle_identifier}' name='#{@display_name}' version=#{@marketing_version} build=#{@build_number} team=#{@team_id} platform=#{@platform}>"
  end
  
  # Class Methods for Business Logic
  
  class << self
    # Validate bundle identifier format
    # @param bundle_id [String] Bundle identifier to validate
    # @return [Boolean] True if bundle identifier is valid
    def valid_bundle_identifier?(bundle_id)
      return false unless bundle_id.is_a?(String)
      return false if bundle_id.length < BUNDLE_ID_MIN_LENGTH
      return false if bundle_id.length > BUNDLE_ID_MAX_LENGTH
      return false unless bundle_id.match?(BUNDLE_ID_REGEX)
      return false unless bundle_id.match?(REVERSE_DNS_REGEX)
      return false if bundle_id.start_with?('.')
      return false if bundle_id.end_with?('.')
      return false if bundle_id.include?('..')
      
      true
    end
    
    # Parse semantic version string
    # @param version [String] Version string to parse
    # @return [Hash, nil] Parsed version components or nil if invalid
    def parse_version(version)
      match = version.to_s.match(SEMANTIC_VERSION_REGEX)
      return nil unless match
      
      {
        major: match[1].to_i,
        minor: match[2].to_i,
        patch: match[3].to_i,
        prerelease: match[4],
        build_metadata: match[5],
        raw: version.to_s
      }
    end
    
    # Check if version is valid semantic version
    # @param version [String] Version to validate
    # @return [Boolean] True if version is valid
    def valid_version?(version)
      !parse_version(version).nil?
    end
    
    # Compare two version strings
    # @param version1 [String] First version
    # @param version2 [String] Second version
    # @return [Integer] -1, 0, or 1 for comparison result
    def compare_versions(version1, version2)
      v1 = parse_version(version1)
      v2 = parse_version(version2)
      
      return 0 unless v1 && v2
      
      [:major, :minor, :patch].each do |component|
        result = v1[component] <=> v2[component]
        return result unless result == 0
      end
      
      0
    end
    
    # Get platform from bundle identifier hints
    # @param bundle_id [String] Bundle identifier
    # @return [String] Suggested platform
    def suggest_platform_from_bundle_id(bundle_id)
      case bundle_id.to_s.downcase
      when /\.tv\.|tvos|appletv/
        'tvos'
      when /\.watch\.|watchos|watchkit/
        'watchos'
      when /\.mac\.|macos|osx/
        'macos'
      else
        DEFAULT_PLATFORM
      end
    end
    
    # Create application from configuration data
    # @param config_data [Hash] Configuration data
    # @return [Application] Application entity
    def from_config(config_data)
      new(
        bundle_identifier: config_data[:app_identifier] || config_data['app_identifier'],
        name: config_data[:app_name] || config_data['app_name'],
        display_name: config_data[:display_name] || config_data['display_name'] || 
                     config_data[:app_name] || config_data['app_name'],
        scheme: config_data[:scheme] || config_data['scheme'],
        team_id: config_data[:team_id] || config_data['team_id'],
        marketing_version: config_data[:marketing_version] || config_data['marketing_version'] || '1.0.0',
        build_number: config_data[:build_number] || config_data['build_number'] || '1',
        platform: config_data[:platform] || config_data['platform'] || DEFAULT_PLATFORM,
        created_at: config_data[:created_at] || config_data['created_at'],
        updated_at: config_data[:updated_at] || config_data['updated_at'],
        metadata: config_data[:metadata] || config_data['metadata']
      )
    end
  end
  
  private
  
  # Validate initialization parameters
  def validate_initialization_parameters(bundle_id, name, display_name, scheme, team_id, version, build, platform)
    raise ArgumentError, "Bundle identifier cannot be nil or empty" if bundle_id.nil? || bundle_id.to_s.strip.empty?
    raise ArgumentError, "App name cannot be nil or empty" if name.nil? || name.to_s.strip.empty?
    raise ArgumentError, "Display name cannot be nil or empty" if display_name.nil? || display_name.to_s.strip.empty?
    raise ArgumentError, "Scheme cannot be nil or empty" if scheme.nil? || scheme.to_s.strip.empty?
    raise ArgumentError, "Team ID must be 10 alphanumeric characters" unless team_id.to_s.match?(/^[A-Z0-9]{10}$/)
    raise ArgumentError, "Marketing version cannot be nil or empty" if version.nil? || version.to_s.strip.empty?
    raise ArgumentError, "Build number cannot be nil or empty" if build.nil? || build.to_s.strip.empty?
    raise ArgumentError, "Unsupported platform: #{platform}" unless SUPPORTED_PLATFORMS.include?(platform.to_s.downcase)
    
    # Validate bundle identifier format
    unless self.class.valid_bundle_identifier?(bundle_id.to_s.strip)
      raise ArgumentError, "Invalid bundle identifier format: #{bundle_id}"
    end
    
    # Validate display name length
    if display_name.to_s.strip.length > MAX_APP_NAME_LENGTH
      raise ArgumentError, "Display name too long (max #{MAX_APP_NAME_LENGTH} characters): #{display_name}"
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
end