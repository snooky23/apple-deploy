# Configuration Repository Interface - Clean Architecture Domain Layer
# Defines all configuration and deployment history operations without implementation details

module ConfigurationRepository
  # Team Configuration Operations
  
  # Get team configuration
  # @param team_id [String] Apple Developer Team ID
  # @return [TeamConfiguration] Team configuration settings
  def get_team_configuration(team_id)
    raise NotImplementedError, "Subclass must implement get_team_configuration"
  end
  
  # Save team configuration
  # @param team_id [String] Apple Developer Team ID
  # @param configuration [TeamConfiguration] Configuration to save
  # @return [Boolean] True if save successful
  def save_team_configuration(team_id, configuration)
    raise NotImplementedError, "Subclass must implement save_team_configuration"
  end
  
  # Update team configuration property
  # @param team_id [String] Apple Developer Team ID
  # @param key [String] Configuration key
  # @param value [Object] Configuration value
  # @return [Boolean] True if update successful
  def update_team_configuration(team_id, key, value)
    raise NotImplementedError, "Subclass must implement update_team_configuration"
  end
  
  # Delete team configuration
  # @param team_id [String] Apple Developer Team ID
  # @return [Boolean] True if deletion successful
  def delete_team_configuration(team_id)
    raise NotImplementedError, "Subclass must implement delete_team_configuration"
  end
  
  # Deployment History Operations
  
  # Get deployment history for team
  # @param team_id [String] Apple Developer Team ID
  # @param limit [Integer] Maximum number of records to return
  # @return [Array<DeploymentRecord>] Array of deployment records
  def get_deployment_history(team_id, limit = 10)
    raise NotImplementedError, "Subclass must implement get_deployment_history"
  end
  
  # Record new deployment
  # @param team_id [String] Apple Developer Team ID
  # @param deployment_record [DeploymentRecord] Deployment information to record
  # @return [String] Deployment record ID
  def record_deployment(team_id, deployment_record)
    raise NotImplementedError, "Subclass must implement record_deployment"
  end
  
  # Update deployment status
  # @param team_id [String] Apple Developer Team ID
  # @param deployment_id [String] Deployment record ID
  # @param status [String, DeploymentRecord] New status or complete record
  # @return [Boolean] True if update successful
  def update_deployment_status(team_id, deployment_id, status)
    raise NotImplementedError, "Subclass must implement update_deployment_status"
  end
  
  # Get specific deployment record
  # @param team_id [String] Apple Developer Team ID
  # @param deployment_id [String] Deployment record ID
  # @return [DeploymentRecord, nil] Deployment record or nil if not found
  def get_deployment_record(team_id, deployment_id)
    raise NotImplementedError, "Subclass must implement get_deployment_record"
  end
  
  # Apple Info Structure Operations
  
  # Get apple_info directory structure for team
  # @param team_id [String] Apple Developer Team ID
  # @return [AppleInfoStructure] Directory structure information
  def get_apple_info_structure(team_id)
    raise NotImplementedError, "Subclass must implement get_apple_info_structure"
  end
  
  # Create apple_info directory structure
  # @param team_id [String] Apple Developer Team ID
  # @param base_directory [String] Base directory for apple_info
  # @return [AppleInfoStructure] Created structure information
  def create_apple_info_structure(team_id, base_directory)
    raise NotImplementedError, "Subclass must implement create_apple_info_structure"
  end
  
  # Validate apple_info structure
  # @param team_id [String] Apple Developer Team ID
  # @return [ValidationResult] Structure validation result
  def validate_apple_info_structure(team_id)
    raise NotImplementedError, "Subclass must implement validate_apple_info_structure"
  end
  
  # Application Configuration Operations
  
  # Get application settings
  # @param app_identifier [String] Bundle identifier
  # @param team_id [String] Apple Developer Team ID
  # @return [AppConfiguration] Application configuration settings
  def get_app_configuration(app_identifier, team_id)
    raise NotImplementedError, "Subclass must implement get_app_configuration"
  end
  
  # Save application settings
  # @param app_identifier [String] Bundle identifier
  # @param team_id [String] Apple Developer Team ID
  # @param configuration [AppConfiguration] Configuration to save
  # @return [Boolean] True if save successful
  def save_app_configuration(app_identifier, team_id, configuration)
    raise NotImplementedError, "Subclass must implement save_app_configuration"
  end
  
  # Global Settings Operations
  
  # Get global automation settings
  # @return [GlobalConfiguration] Global settings
  def get_global_configuration
    raise NotImplementedError, "Subclass must implement get_global_configuration"
  end
  
  # Save global automation settings
  # @param configuration [GlobalConfiguration] Global configuration
  # @return [Boolean] True if save successful
  def save_global_configuration(configuration)
    raise NotImplementedError, "Subclass must implement save_global_configuration"
  end
  
  # Cache Operations
  
  # Get cached data
  # @param key [String] Cache key
  # @param team_id [String, nil] Optional team ID for team-specific cache
  # @return [Object, nil] Cached value or nil if not found
  def get_cached_value(key, team_id = nil)
    raise NotImplementedError, "Subclass must implement get_cached_value"
  end
  
  # Set cached data
  # @param key [String] Cache key
  # @param value [Object] Value to cache
  # @param team_id [String, nil] Optional team ID for team-specific cache
  # @param ttl [Integer, nil] Time to live in seconds
  # @return [Boolean] True if cache successful
  def set_cached_value(key, value, team_id = nil, ttl = nil)
    raise NotImplementedError, "Subclass must implement set_cached_value"
  end
  
  # Clear cache
  # @param pattern [String, nil] Optional pattern to match keys
  # @param team_id [String, nil] Optional team ID for team-specific cache
  # @return [Boolean] True if clear successful
  def clear_cache(pattern = nil, team_id = nil)
    raise NotImplementedError, "Subclass must implement clear_cache"
  end
  
  # Backup and Migration Operations
  
  # Create configuration backup
  # @param team_id [String] Apple Developer Team ID
  # @param backup_path [String] Path for backup file
  # @return [Boolean] True if backup successful
  def create_backup(team_id, backup_path)
    raise NotImplementedError, "Subclass must implement create_backup"
  end
  
  # Restore from configuration backup
  # @param team_id [String] Apple Developer Team ID
  # @param backup_path [String] Path to backup file
  # @return [Boolean] True if restore successful
  def restore_backup(team_id, backup_path)
    raise NotImplementedError, "Subclass must implement restore_backup"
  end
  
  # Migrate configuration format
  # @param team_id [String] Apple Developer Team ID
  # @param from_version [String] Source configuration version
  # @param to_version [String] Target configuration version
  # @return [Boolean] True if migration successful
  def migrate_configuration(team_id, from_version, to_version)
    raise NotImplementedError, "Subclass must implement migrate_configuration"
  end
  
  # Query Operations
  
  # List all configured teams
  # @return [Array<String>] Array of team IDs with configurations
  def list_configured_teams
    raise NotImplementedError, "Subclass must implement list_configured_teams"
  end
  
  # Search deployment history
  # @param team_id [String] Apple Developer Team ID
  # @param criteria [Hash] Search criteria
  # @return [Array<DeploymentRecord>] Matching deployment records
  def search_deployments(team_id, criteria)
    raise NotImplementedError, "Subclass must implement search_deployments"
  end
  
  # Repository Information
  
  # Get repository type/source information
  # @return [String] Repository type identifier ('file', 'database', 'cloud')
  def repository_type
    raise NotImplementedError, "Subclass must implement repository_type"
  end
  
  # Check if repository is available/accessible
  # @return [Boolean] True if repository is accessible
  def available?
    raise NotImplementedError, "Subclass must implement available?"
  end
  
  # Get repository health status
  # @return [RepositoryHealth] Health status and diagnostics
  def get_health_status
    raise NotImplementedError, "Subclass must implement get_health_status"
  end
end