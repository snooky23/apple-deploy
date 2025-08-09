# Create Provisioning Profiles Use Case - Clean Architecture Domain Layer
# Business workflow: Create and manage Apple Developer provisioning profiles

require_relative '../../fastlane/modules/core/logger'
require_relative '../../infrastructure/apple_api/profiles_api'

class CreateProvisioningProfilesRequest
  attr_reader :app_identifier, :team_id, :apple_id, :profiles_dir, :create_development, :create_distribution, :force_recreate
  
  def initialize(app_identifier:, team_id:, apple_id:, profiles_dir:, create_development: true, create_distribution: true, force_recreate: false)
    @app_identifier = app_identifier
    @team_id = team_id
    @apple_id = apple_id
    @profiles_dir = profiles_dir
    @create_development = create_development
    @create_distribution = create_distribution
    @force_recreate = force_recreate
    
    validate_request
  end
  
  private
  
  def validate_request
    raise ArgumentError, "app_identifier cannot be nil or empty" if @app_identifier.nil? || @app_identifier.empty?
    raise ArgumentError, "team_id cannot be nil or empty" if @team_id.nil? || @team_id.empty?
    raise ArgumentError, "apple_id cannot be nil or empty" if @apple_id.nil? || @apple_id.empty?
    raise ArgumentError, "profiles_dir cannot be nil or empty" if @profiles_dir.nil? || @profiles_dir.empty?
    raise ArgumentError, "profiles_dir must be a valid directory" unless Dir.exist?(File.dirname(@profiles_dir))
  end
end

class CreateProvisioningProfilesResult
  attr_reader :success, :created_profiles, :development_profile, :distribution_profile, :error, :error_type, :recovery_suggestion
  
  def initialize(success:, created_profiles: [], development_profile: nil, distribution_profile: nil, error: nil, error_type: nil, recovery_suggestion: nil)
    @success = success
    @created_profiles = created_profiles
    @development_profile = development_profile
    @distribution_profile = distribution_profile
    @error = error
    @error_type = error_type
    @recovery_suggestion = recovery_suggestion
  end
  
  def development_profile_created?
    !@development_profile.nil?
  end
  
  def distribution_profile_created?
    !@distribution_profile.nil?
  end
  
  def development_profiles_count
    @created_profiles.count { |profile| profile[:type] == :development }
  end
  
  def distribution_profiles_count
    @created_profiles.count { |profile| profile[:type] == :distribution }  
  end
end

class CreateProvisioningProfiles
  def initialize(logger: FastlaneLogger, profiles_api: nil)
    @logger = logger
    @profiles_api = profiles_api || ProfilesAPI.new(logger: logger)
  end
  
  # Execute the use case to create Apple Developer provisioning profiles
  # @param request [CreateProvisioningProfilesRequest] Input parameters
  # @return [CreateProvisioningProfilesResult] Result with created profile information
  def execute(request)
    @logger.step("Creating Apple Developer provisioning profiles")
    
    begin
      created_profiles = []
      development_profile = nil
      distribution_profile = nil
      
      # Business Logic: Create development provisioning profile if requested
      if request.create_development
        development_profile = create_development_profile(request)
        created_profiles << development_profile if development_profile
      end
      
      # Business Logic: Create distribution provisioning profile if requested
      if request.create_distribution
        distribution_profile = create_distribution_profile(request)
        created_profiles << distribution_profile if distribution_profile
      end
      
      if created_profiles.empty?
        @logger.warn("No provisioning profiles were created")
        CreateProvisioningProfilesResult.new(
          success: false,
          error: "No provisioning profiles were created",
          error_type: :profile_creation_failed,
          recovery_suggestion: "Check Apple Developer Portal access and app identifier configuration"
        )
      else
        @logger.success("Provisioning profile creation completed successfully")
        @logger.info("Created #{created_profiles.size} profiles")
        
        CreateProvisioningProfilesResult.new(
          success: true,
          created_profiles: created_profiles,
          development_profile: development_profile,
          distribution_profile: distribution_profile
        )
      end
      
    rescue ProvisioningProfileCreationError => e
      @logger.error("Provisioning profile creation failed: #{e.message}")
      CreateProvisioningProfilesResult.new(
        success: false,
        error: e.message,
        error_type: :profile_creation_failed,
        recovery_suggestion: "Check app identifier configuration and certificate availability"
      )
      
    rescue => e
      @logger.error("Unexpected error during provisioning profile creation: #{e.message}")
      CreateProvisioningProfilesResult.new(
        success: false,
        error: e.message,
        error_type: :unexpected_error,
        recovery_suggestion: "Check Apple Developer Portal connectivity and account permissions"
      )
    end
  end
  
  private
  
  def create_development_profile(request)
    @logger.info("Creating Development Provisioning Profile...")
    
    begin
      profile_info = create_profile_via_fastlane(
        app_identifier: request.app_identifier,
        development: true,
        team_id: request.team_id,
        username: request.apple_id,
        force: request.force_recreate,
        output_path: request.profiles_dir
      )
      
      if profile_info
        @logger.success("✅ Development provisioning profile ready in #{request.profiles_dir}")
        {
          type: :development,
          app_identifier: request.app_identifier,
          team_id: request.team_id,
          name: profile_info[:name],
          path: profile_info[:path],
          output_path: request.profiles_dir,
          created_at: Time.now
        }
      else
        @logger.warn("Development provisioning profile creation returned false")
        nil
      end
      
    rescue => e
      @logger.warn("⚠️  Development profile creation failed: #{e.message}")
      @logger.info("💡 Continuing without development profile...")
      nil
    end
  end
  
  def create_distribution_profile(request)
    @logger.info("Setting up Distribution Provisioning Profile...")
    @logger.info("🔍 Checking for existing valid distribution profiles...")
    
    begin
      # First, try to find and use existing valid profile that matches our local certificates
      profile_info = create_profile_via_fastlane(
        app_identifier: request.app_identifier,
        development: false,
        team_id: request.team_id,
        username: request.apple_id,
        force: false,  # Don't force recreate - use existing valid profile if available
        skip_certificate_verification: false,  # Ensure certificate verification
        output_path: request.profiles_dir
      )
      
      if profile_info
        @logger.success("✅ Distribution provisioning profile ready in #{request.profiles_dir}")
        if profile_info[:name]
          @logger.info("📋 Using existing profile: #{profile_info[:name]}")
        end
        
        return {
          type: :distribution,
          app_identifier: request.app_identifier,
          team_id: request.team_id,
          name: profile_info[:name],
          path: profile_info[:path],
          output_path: request.profiles_dir,
          existing_profile_used: true,
          created_at: Time.now
        }
      end
      
    rescue => profile_error
      @logger.info("⚠️  No existing valid profile found with matching certificates")
      @logger.info("🔄 Creating new distribution profile with current certificates...")
      
      begin
        # If no existing profile works, create a new one
        profile_info = create_profile_via_fastlane(
          app_identifier: request.app_identifier,
          development: false,
          team_id: request.team_id,
          username: request.apple_id,
          force: true,  # Force create new profile with current certificates
          output_path: request.profiles_dir
        )
        
        if profile_info
          @logger.success("✅ New distribution provisioning profile created in #{request.profiles_dir}")
          if profile_info[:name]
            @logger.info("📋 Created new profile: #{profile_info[:name]}")
          end
          
          return {
            type: :distribution,
            app_identifier: request.app_identifier,
            team_id: request.team_id,
            name: profile_info[:name],
            path: profile_info[:path],
            output_path: request.profiles_dir,
            existing_profile_used: false,
            created_at: Time.now
          }
        end
        
      rescue => creation_error
        @logger.error("❌ Distribution profile creation failed: #{creation_error.message}")
        raise ProvisioningProfileCreationError.new("Distribution profile creation failed: #{creation_error.message}")
      end
    end
    
    # If we reach here, something went wrong
    @logger.warn("⚠️  Distribution profile creation failed")
    @logger.info("💡 Attempting to continue without profile - will use automatic code signing fallback")
    nil
  end
  
  def create_profile_via_fastlane(app_identifier:, development:, team_id:, username:, force:, output_path:, skip_certificate_verification: nil)
    # Use ProfilesAPI instead of calling sigh directly
    begin
      @logger.info("Calling ProfilesAPI with:")
      @logger.info("  - App Identifier: #{app_identifier}")
      @logger.info("  - Development: #{development}")
      @logger.info("  - Team ID: #{team_id}")
      @logger.info("  - Username: #{username}")
      @logger.info("  - Force: #{force}")
      @logger.info("  - Output: #{output_path}")
      
      # Use ProfilesAPI adapter
      if development
        result = @profiles_api.create_development_profile(
          app_identifier: app_identifier,
          team_id: team_id,
          username: username,
          force: force,
          output_path: output_path
        )
      else
        result = @profiles_api.create_distribution_profile(
          app_identifier: app_identifier,
          team_id: team_id,
          username: username,
          force: force,
          output_path: output_path,
          skip_certificate_verification: skip_certificate_verification
        )
      end
      
      if result[:success]
        # Return profile information
        {
          name: result[:profile_name],
          path: result[:profile_path],
          success: true
        }
      else
        @logger.error("Profile creation via API failed: #{result[:error]}")
        return nil
      end
      
    rescue => e
      @logger.error("ProfilesAPI call failed: #{e.message}")
      raise e
    end
  end
end

# Custom exception for provisioning profile creation operations
class ProvisioningProfileCreationError < StandardError; end