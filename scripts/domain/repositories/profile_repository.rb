# Provisioning Profile Repository Interface - Clean Architecture Domain Layer
# Defines all provisioning profile operations without implementation details

module ProfileRepository
  # Query Operations
  
  # Find profiles by app identifier
  # @param app_identifier [String] Bundle identifier (e.g., com.yourapp.id)
  # @param team_id [String] Apple Developer Team ID
  # @return [Array<ProvisioningProfile>] Array of ProvisioningProfile entities
  def find_by_app_identifier(app_identifier, team_id)
    raise NotImplementedError, "Subclass must implement find_by_app_identifier"
  end
  
  # Find profiles by type (development or distribution)
  # @param app_identifier [String] Bundle identifier
  # @param profile_type [String] 'development' or 'distribution'  
  # @param team_id [String] Apple Developer Team ID
  # @return [Array<ProvisioningProfile>] Array of matching profiles
  def find_by_type(app_identifier, profile_type, team_id)
    raise NotImplementedError, "Subclass must implement find_by_type"
  end
  
  # Find profiles compatible with given certificates
  # @param app_identifier [String] Bundle identifier
  # @param certificates [Array<Certificate>] Certificates to match
  # @param team_id [String] Apple Developer Team ID
  # @return [Array<ProvisioningProfile>] Array of compatible profiles
  def find_compatible_profiles(app_identifier, certificates, team_id)
    raise NotImplementedError, "Subclass must implement find_compatible_profiles"
  end
  
  # Find profile by UUID
  # @param profile_uuid [String] Provisioning profile UUID
  # @return [ProvisioningProfile, nil] Profile entity or nil if not found
  def find_by_uuid(profile_uuid)
    raise NotImplementedError, "Subclass must implement find_by_uuid"
  end
  
  # Find all profiles for a team
  # @param team_id [String] Apple Developer Team ID
  # @return [Array<ProvisioningProfile>] Array of all team profiles
  def find_by_team(team_id)
    raise NotImplementedError, "Subclass must implement find_by_team"
  end
  
  # Creation Operations
  
  # Create development provisioning profile
  # @param app_identifier [String] Bundle identifier
  # @param certificates [Array<Certificate>] Development certificates to include
  # @param team_id [String] Apple Developer Team ID
  # @param name [String, nil] Optional profile name
  # @return [ProvisioningProfile] Created profile entity
  def create_development_profile(app_identifier, certificates, team_id, name = nil)
    raise NotImplementedError, "Subclass must implement create_development_profile"
  end
  
  # Create distribution provisioning profile
  # @param app_identifier [String] Bundle identifier
  # @param certificates [Array<Certificate>] Distribution certificates to include
  # @param team_id [String] Apple Developer Team ID
  # @param name [String, nil] Optional profile name
  # @return [ProvisioningProfile] Created profile entity
  def create_distribution_profile(app_identifier, certificates, team_id, name = nil)
    raise NotImplementedError, "Subclass must implement create_distribution_profile"
  end
  
  # Management Operations
  
  # Install profile to system
  # @param profile [ProvisioningProfile] Profile entity to install
  # @param target_directory [String, nil] Optional target directory
  # @return [Boolean] True if installation successful
  def install_profile(profile, target_directory = nil)
    raise NotImplementedError, "Subclass must implement install_profile"
  end
  
  # Download profile from Apple Developer Portal
  # @param profile_id [String] Profile ID to download
  # @param output_path [String] Local path to save profile
  # @return [ProvisioningProfile] Downloaded profile entity
  def download_profile(profile_id, output_path)
    raise NotImplementedError, "Subclass must implement download_profile"
  end
  
  # Delete profile
  # @param profile_id [String] Profile ID to delete
  # @return [Boolean] True if deletion successful
  def delete_profile(profile_id)
    raise NotImplementedError, "Subclass must implement delete_profile"
  end
  
  # Refresh profile (update certificates)
  # @param profile_id [String] Profile ID to refresh
  # @param certificates [Array<Certificate>] New certificates to include
  # @return [ProvisioningProfile] Refreshed profile entity
  def refresh_profile(profile_id, certificates)
    raise NotImplementedError, "Subclass must implement refresh_profile"
  end
  
  # Validation Operations
  
  # Validate profile compatibility
  # @param profile [ProvisioningProfile] Profile entity
  # @param app_identifier [String] Bundle identifier to validate
  # @param certificates [Array<Certificate>] Certificates to validate
  # @return [Boolean] True if profile is compatible
  def validate_profile(profile, app_identifier, certificates)
    raise NotImplementedError, "Subclass must implement validate_profile"
  end
  
  # Check if profile is expired
  # @param profile [ProvisioningProfile] Profile entity
  # @return [Boolean] True if profile is expired
  def is_expired?(profile)
    raise NotImplementedError, "Subclass must implement is_expired?"
  end
  
  # Check if profile matches configuration
  # @param profile [ProvisioningProfile] Profile entity
  # @param configuration [String] Build configuration ('Debug', 'Release')
  # @return [Boolean] True if profile matches configuration
  def matches_configuration?(profile, configuration)
    raise NotImplementedError, "Subclass must implement matches_configuration?"
  end
  
  # Check certificate compatibility
  # @param profile [ProvisioningProfile] Profile entity
  # @param certificates [Array<Certificate>] Certificates to check
  # @return [Boolean] True if all certificates are included in profile
  def certificates_match?(profile, certificates)
    raise NotImplementedError, "Subclass must implement certificates_match?"
  end
  
  # File Operations
  
  # Import profile from file
  # @param file_path [String] Path to .mobileprovision file
  # @return [ProvisioningProfile] Imported profile entity
  def import_from_file(file_path)
    raise NotImplementedError, "Subclass must implement import_from_file"
  end
  
  # Export profile to file
  # @param profile [ProvisioningProfile] Profile entity
  # @param output_path [String] Output file path
  # @return [Boolean] True if export successful
  def export_to_file(profile, output_path)
    raise NotImplementedError, "Subclass must implement export_to_file"
  end
  
  # Repository Information
  
  # Get repository type/source information
  # @return [String] Repository type identifier ('system', 'api', 'file')
  def repository_type
    raise NotImplementedError, "Subclass must implement repository_type"
  end
  
  # Check if repository is available/accessible
  # @return [Boolean] True if repository is accessible
  def available?
    raise NotImplementedError, "Subclass must implement available?"
  end
end