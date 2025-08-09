# Team Domain Entity - Clean Architecture Domain Layer
# Pure business object representing an Apple Developer Team with multi-developer collaboration

require 'date'

class Team
  # Apple Developer Team Business Rules and Constraints
  MAX_TEAM_NAME_LENGTH = 100
  TEAM_ID_LENGTH = 10
  TEAM_ID_REGEX = /\A[A-Z0-9]{10}\z/
  
  # Team Roles and Permissions
  TEAM_ROLES = %w[admin developer].freeze
  DEFAULT_ROLE = 'developer'.freeze
  
  # Team Configuration Limits
  MAX_CERTIFICATES_PER_TEAM = 5  # Combined development + distribution
  MAX_PROFILES_PER_TEAM = 1000   # Apple Developer Portal limit
  MAX_APPLICATIONS_PER_TEAM = 100 # Reasonable enterprise limit
  
  # Directory Structure Requirements
  REQUIRED_DIRECTORIES = %w[certificates profiles].freeze
  
  attr_reader :team_id, :name, :organization_name, :program_type, :status,
              :created_at, :updated_at, :metadata, :members, :applications
  
  # Initialize Team entity
  # @param team_id [String] Apple Developer Team ID (10 alphanumeric characters)
  # @param name [String] Team display name
  # @param organization_name [String] Legal organization name
  # @param program_type [String] Apple Developer Program type ('individual', 'organization', 'enterprise')
  # @param status [String] Team status ('active', 'inactive', 'suspended')
  # @param created_at [Date, String, nil] Team registration date (optional)
  # @param updated_at [Date, String, nil] Last update date (optional)
  # @param metadata [Hash, nil] Additional team metadata (optional)
  # @param members [Array<TeamMember>, nil] Team members (optional)
  # @param applications [Array<String>, nil] Application identifiers managed by team (optional)
  def initialize(team_id:, name:, organization_name: nil, program_type: 'individual',
                 status: 'active', created_at: nil, updated_at: nil, metadata: nil,
                 members: nil, applications: nil)
    validate_initialization_parameters(team_id, name, program_type, status)
    
    @team_id = team_id.to_s.strip
    @name = name.to_s.strip
    @organization_name = organization_name&.to_s&.strip
    @program_type = program_type.to_s.downcase
    @status = status.to_s.downcase
    @created_at = created_at ? parse_date(created_at) : Date.today
    @updated_at = updated_at ? parse_date(updated_at) : Date.today
    @metadata = metadata ? metadata.dup : {}
    @members = members ? members.dup : []
    @applications = applications ? applications.dup : []
  end
  
  # Business Logic Methods
  
  # Check if team is active and operational
  # @return [Boolean] True if team can perform operations
  def active?
    @status == 'active'
  end
  
  # Check if team is suspended or inactive
  # @return [Boolean] True if team operations are restricted
  def restricted?
    %w[inactive suspended].include?(@status)
  end
  
  # Check if team is organization-based (not individual)
  # @return [Boolean] True if team supports multiple developers
  def organization?
    %w[organization enterprise].include?(@program_type)
  end
  
  # Check if team is enterprise program
  # @return [Boolean] True if enterprise program with extended capabilities
  def enterprise?
    @program_type == 'enterprise'
  end
  
  # Check if team is individual developer program
  # @return [Boolean] True if individual developer (single person)
  def individual?
    @program_type == 'individual'
  end
  
  # Team Membership Management
  
  # Add member to team with role validation
  # @param member [TeamMember] Team member to add
  # @return [Team] New team instance with added member
  def add_member(member)
    raise ArgumentError, "Member must be a TeamMember" unless member.is_a?(TeamMember)
    raise BusinessRuleError, "Individual teams cannot have multiple members" if individual? && !@members.empty?
    
    # Check for duplicate members
    if has_member?(member.email)
      raise BusinessRuleError, "Member with email #{member.email} already exists"
    end
    
    new_members = @members + [member]
    with_updated_members(new_members)
  end
  
  # Remove member from team
  # @param email [String] Email of member to remove
  # @return [Team] New team instance with removed member
  def remove_member(email)
    new_members = @members.reject { |member| member.email == email }
    with_updated_members(new_members)
  end
  
  # Check if team has member with given email
  # @param email [String] Email to check
  # @return [Boolean] True if member exists
  def has_member?(email)
    @members.any? { |member| member.email == email }
  end
  
  # Get member by email
  # @param email [String] Email to find
  # @return [TeamMember, nil] Member if found, nil otherwise
  def get_member(email)
    @members.find { |member| member.email == email }
  end
  
  # Get members with specific role
  # @param role [String] Role to filter by ('admin', 'developer')
  # @return [Array<TeamMember>] Members with specified role
  def members_with_role(role)
    @members.select { |member| member.role == role }
  end
  
  # Get admin members
  # @return [Array<TeamMember>] All admin members
  def admin_members
    members_with_role('admin')
  end
  
  # Check if member has admin privileges
  # @param email [String] Email to check
  # @return [Boolean] True if member is admin
  def member_is_admin?(email)
    member = get_member(email)
    member&.admin?
  end
  
  # Application Management
  
  # Add application to team management
  # @param app_identifier [String] Bundle identifier to add
  # @return [Team] New team instance with added application
  def add_application(app_identifier)
    raise ArgumentError, "App identifier cannot be nil or empty" if app_identifier.nil? || app_identifier.empty?
    
    if manages_application?(app_identifier)
      raise BusinessRuleError, "Team already manages application: #{app_identifier}"
    end
    
    if @applications.length >= MAX_APPLICATIONS_PER_TEAM
      raise BusinessRuleError, "Team has reached maximum applications limit: #{MAX_APPLICATIONS_PER_TEAM}"
    end
    
    new_applications = @applications + [app_identifier]
    with_updated_applications(new_applications)
  end
  
  # Remove application from team management
  # @param app_identifier [String] Bundle identifier to remove
  # @return [Team] New team instance with removed application
  def remove_application(app_identifier)
    new_applications = @applications.reject { |app| app == app_identifier }
    with_updated_applications(new_applications)
  end
  
  # Check if team manages specific application
  # @param app_identifier [String] Bundle identifier to check
  # @return [Boolean] True if team manages this application
  def manages_application?(app_identifier)
    @applications.include?(app_identifier)
  end
  
  # Get applications managed by team
  # @return [Array<String>] List of application identifiers
  def managed_applications
    @applications.dup
  end
  
  # Directory and Configuration Management
  
  # Get expected directory structure for team
  # @param base_path [String] Base path for team directories
  # @return [Hash] Directory structure with paths
  def directory_structure(base_path)
    team_path = File.join(base_path, @team_id)
    
    {
      team_root: team_path,
      certificates: File.join(team_path, 'certificates'),
      profiles: File.join(team_path, 'profiles'),
      config: File.join(team_path, 'config.env'),
      api_keys: team_path  # API keys stored in team root
    }
  end
  
  # Validate team directory structure exists and is correct
  # @param base_path [String] Base path to check
  # @return [DirectoryValidationResult] Validation result with details
  def validate_directory_structure(base_path)
    structure = directory_structure(base_path)
    missing_dirs = []
    existing_dirs = []
    
    REQUIRED_DIRECTORIES.each do |dir_name|
      dir_path = structure[dir_name.to_sym]
      if Dir.exist?(dir_path)
        existing_dirs << dir_name
      else
        missing_dirs << dir_name
      end
    end
    
    DirectoryValidationResult.new(
      valid: missing_dirs.empty?,
      team_root_exists: Dir.exist?(structure[:team_root]),
      existing_directories: existing_dirs,
      missing_directories: missing_dirs,
      structure: structure
    )
  end
  
  # Resource Limits and Validation
  
  # Check if team can create more certificates
  # @param current_certificate_count [Integer] Current number of certificates
  # @return [Boolean] True if team can create more certificates
  def can_create_certificates?(current_certificate_count = 0)
    current_certificate_count < MAX_CERTIFICATES_PER_TEAM
  end
  
  # Check if team can create more provisioning profiles
  # @param current_profile_count [Integer] Current number of profiles
  # @return [Boolean] True if team can create more profiles
  def can_create_profiles?(current_profile_count = 0)
    current_profile_count < MAX_PROFILES_PER_TEAM
  end
  
  # Get remaining certificate capacity
  # @param current_certificate_count [Integer] Current number of certificates
  # @return [Integer] Number of certificates that can still be created
  def remaining_certificate_capacity(current_certificate_count = 0)
    [MAX_CERTIFICATES_PER_TEAM - current_certificate_count, 0].max
  end
  
  # Metadata Management
  
  # Get metadata value
  # @param key [String, Symbol] Metadata key
  # @return [Object] Metadata value or nil
  def get_metadata(key)
    @metadata[key.to_s] || @metadata[key.to_sym]
  end
  
  # Set metadata value (returns new Team instance)
  # @param key [String, Symbol] Metadata key
  # @param value [Object] Metadata value
  # @return [Team] New Team instance with updated metadata
  def with_metadata(key, value)
    new_metadata = @metadata.dup
    new_metadata[key.to_s] = value
    
    self.class.new(
      team_id: @team_id,
      name: @name,
      organization_name: @organization_name,
      program_type: @program_type,
      status: @status,
      created_at: @created_at,
      updated_at: Date.today,
      metadata: new_metadata,
      members: @members,
      applications: @applications
    )
  end
  
  # Team Status Management
  
  # Activate team (returns new Team instance)
  # @return [Team] New Team instance with active status
  def activate
    with_status('active')
  end
  
  # Deactivate team (returns new Team instance)  
  # @return [Team] New Team instance with inactive status
  def deactivate
    with_status('inactive')
  end
  
  # Suspend team (returns new Team instance)
  # @return [Team] New Team instance with suspended status
  def suspend
    with_status('suspended')
  end
  
  # Update team status (returns new Team instance)
  # @param new_status [String] New status ('active', 'inactive', 'suspended')
  # @return [Team] New Team instance with updated status
  def with_status(new_status)
    unless %w[active inactive suspended].include?(new_status.to_s.downcase)
      raise ArgumentError, "Invalid status: #{new_status}"
    end
    
    self.class.new(
      team_id: @team_id,
      name: @name,
      organization_name: @organization_name,
      program_type: @program_type,
      status: new_status,
      created_at: @created_at,
      updated_at: Date.today,
      metadata: @metadata,
      members: @members,
      applications: @applications
    )
  end
  
  # Comparison and Equality
  
  # Check equality with another team
  # @param other [Team] Other team to compare
  # @return [Boolean] True if teams are equal
  def ==(other)
    return false unless other.is_a?(Team)
    @team_id == other.team_id
  end
  
  # Generate hash for team (useful for Set operations)
  # @return [Integer] Hash value
  def hash
    @team_id.hash
  end
  
  # Compare teams for sorting (by team_id)
  # @param other [Team] Other team to compare
  # @return [Integer] -1, 0, or 1 for sorting
  def <=>(other)
    return 0 unless other.is_a?(Team)
    @team_id <=> other.team_id
  end
  
  # Serialization and Display
  
  # Convert team to hash representation
  # @return [Hash] Team data as hash
  def to_hash
    {
      team_id: @team_id,
      name: @name,
      organization_name: @organization_name,
      program_type: @program_type,
      status: @status,
      created_at: @created_at.iso8601,
      updated_at: @updated_at.iso8601,
      metadata: @metadata,
      members: @members.map(&:to_hash),
      applications: @applications,
      capabilities: {
        active: active?,
        organization: organization?,
        enterprise: enterprise?,
        member_count: @members.length,
        application_count: @applications.length
      }
    }
  end
  
  # String representation of team
  # @return [String] Human-readable team description
  def to_s
    "Team #{@team_id} (#{@name}) - #{@program_type.capitalize} - #{@status.capitalize}"
  end
  
  # Detailed string representation
  # @return [String] Detailed team information
  def inspect
    "#<Team:#{object_id} id='#{@team_id}' name='#{@name}' type=#{@program_type} status=#{@status} members=#{@members.length} apps=#{@applications.length}>"
  end
  
  # Class Methods
  
  class << self
    # Validate team ID format
    # @param team_id [String] Team ID to validate
    # @return [Boolean] True if team ID is valid
    def valid_team_id?(team_id)
      return false unless team_id.is_a?(String)
      return false if team_id.length != TEAM_ID_LENGTH
      team_id.match?(TEAM_ID_REGEX)
    end
    
    # Create team from configuration data
    # @param config_data [Hash] Configuration data
    # @return [Team] Team entity
    def from_config(config_data)
      new(
        team_id: config_data[:team_id] || config_data['team_id'],
        name: config_data[:team_name] || config_data['team_name'],
        organization_name: config_data[:organization_name] || config_data['organization_name'],
        program_type: config_data[:program_type] || config_data['program_type'] || 'individual',
        status: config_data[:status] || config_data['status'] || 'active',
        created_at: config_data[:created_at] || config_data['created_at'],
        updated_at: config_data[:updated_at] || config_data['updated_at'],
        metadata: config_data[:metadata] || config_data['metadata']
      )
    end
  end
  
  private
  
  # Validate initialization parameters
  def validate_initialization_parameters(team_id, name, program_type, status)
    raise ArgumentError, "Team ID cannot be nil or empty" if team_id.nil? || team_id.to_s.strip.empty?
    raise ArgumentError, "Team name cannot be nil or empty" if name.nil? || name.to_s.strip.empty?
    
    unless self.class.valid_team_id?(team_id.to_s.strip)
      raise ArgumentError, "Invalid team ID format: #{team_id}"
    end
    
    if name.to_s.strip.length > MAX_TEAM_NAME_LENGTH
      raise ArgumentError, "Team name too long (max #{MAX_TEAM_NAME_LENGTH} characters): #{name}"
    end
    
    unless %w[individual organization enterprise].include?(program_type.to_s.downcase)
      raise ArgumentError, "Invalid program type: #{program_type}"
    end
    
    unless %w[active inactive suspended].include?(status.to_s.downcase)
      raise ArgumentError, "Invalid status: #{status}"
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
  
  # Create new team instance with updated members
  def with_updated_members(new_members)
    self.class.new(
      team_id: @team_id,
      name: @name,
      organization_name: @organization_name,
      program_type: @program_type,
      status: @status,
      created_at: @created_at,
      updated_at: Date.today,
      metadata: @metadata,
      members: new_members,
      applications: @applications
    )
  end
  
  # Create new team instance with updated applications
  def with_updated_applications(new_applications)
    self.class.new(
      team_id: @team_id,
      name: @name,
      organization_name: @organization_name,
      program_type: @program_type,
      status: @status,
      created_at: @created_at,
      updated_at: Date.today,
      metadata: @metadata,
      members: @members,
      applications: new_applications
    )
  end
end

# Team Member entity for team collaboration
class TeamMember
  attr_reader :email, :role, :name, :added_at
  
  def initialize(email:, role: Team::DEFAULT_ROLE, name: nil, added_at: nil)
    validate_member_parameters(email, role)
    
    @email = email.to_s.strip.downcase
    @role = role.to_s.downcase
    @name = name&.to_s&.strip
    @added_at = added_at ? parse_date(added_at) : Date.today
  end
  
  def admin?
    @role == 'admin'
  end
  
  def developer?
    @role == 'developer'
  end
  
  def to_hash
    {
      email: @email,
      role: @role,
      name: @name,
      added_at: @added_at.iso8601
    }
  end
  
  def ==(other)
    return false unless other.is_a?(TeamMember)
    @email == other.email
  end
  
  def hash
    @email.hash
  end
  
  private
  
  def validate_member_parameters(email, role)
    raise ArgumentError, "Email cannot be nil or empty" if email.nil? || email.to_s.strip.empty?
    
    unless email.to_s.match?(/\A[^@\s]+@[^@\s]+\z/)
      raise ArgumentError, "Invalid email format: #{email}"
    end
    
    unless Team::TEAM_ROLES.include?(role.to_s.downcase)
      raise ArgumentError, "Invalid role: #{role}. Must be one of: #{Team::TEAM_ROLES.join(', ')}"
    end
  end
  
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

# Directory validation result
class DirectoryValidationResult
  attr_reader :valid, :team_root_exists, :existing_directories, :missing_directories, :structure
  
  def initialize(valid:, team_root_exists:, existing_directories:, missing_directories:, structure:)
    @valid = valid
    @team_root_exists = team_root_exists
    @existing_directories = existing_directories
    @missing_directories = missing_directories
    @structure = structure
  end
  
  def valid?
    @valid
  end
end

# Custom exceptions for team management
class BusinessRuleError < StandardError; end