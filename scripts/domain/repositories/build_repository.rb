# Build Repository Interface - Clean Architecture Domain Layer  
# Defines all build and project operations without implementation details

module BuildRepository
  # Build Operations
  
  # Build archive for iOS app
  # @param project_path [String] Path to Xcode project or workspace
  # @param scheme [String] Xcode scheme to build
  # @param configuration [String] Build configuration ('Debug', 'Release')
  # @param output_path [String] Path for archive output
  # @param signing_config [SigningConfiguration] Code signing configuration
  # @return [BuildResult] Build result with archive path and metadata
  def build_archive(project_path, scheme, configuration, output_path, signing_config)
    raise NotImplementedError, "Subclass must implement build_archive"
  end
  
  # Export IPA from archive
  # @param archive_path [String] Path to .xcarchive
  # @param export_options [Hash] Export options for IPA creation
  # @param output_path [String] Directory for IPA output
  # @return [BuildResult] Export result with IPA path and metadata
  def export_ipa(archive_path, export_options, output_path)
    raise NotImplementedError, "Subclass must implement export_ipa"
  end
  
  # Clean build directory
  # @param project_path [String] Path to Xcode project
  # @param scheme [String] Xcode scheme
  # @return [Boolean] True if clean successful
  def clean_build(project_path, scheme)
    raise NotImplementedError, "Subclass must implement clean_build"
  end
  
  # Project Operations
  
  # Update build number in project
  # @param project_path [String] Path to Xcode project
  # @param build_number [String, Integer] New build number
  # @return [Boolean] True if update successful
  def update_build_number(project_path, build_number)
    raise NotImplementedError, "Subclass must implement update_build_number"
  end
  
  # Update marketing version in project
  # @param project_path [String] Path to Xcode project
  # @param version_number [String] New version number (e.g., "1.2.3")
  # @return [Boolean] True if update successful
  def update_version_number(project_path, version_number)
    raise NotImplementedError, "Subclass must implement update_version_number"
  end
  
  # Get current version info from project
  # @param project_path [String] Path to Xcode project
  # @return [VersionInfo] Current version and build number information
  def get_current_version_info(project_path)
    raise NotImplementedError, "Subclass must implement get_current_version_info"
  end
  
  # Update code signing settings
  # @param project_path [String] Path to Xcode project
  # @param signing_config [SigningConfiguration] New signing configuration
  # @return [Boolean] True if update successful
  def update_signing_configuration(project_path, signing_config)
    raise NotImplementedError, "Subclass must implement update_signing_configuration"
  end
  
  # Validation Operations
  
  # Validate project configuration for building
  # @param project_path [String] Path to Xcode project
  # @param scheme [String] Xcode scheme
  # @param configuration [String] Build configuration
  # @return [ValidationResult] Validation result with any issues found
  def validate_project_configuration(project_path, scheme, configuration)
    raise NotImplementedError, "Subclass must implement validate_project_configuration"
  end
  
  # Validate code signing configuration
  # @param project_path [String] Path to Xcode project
  # @param signing_config [SigningConfiguration] Signing configuration to validate
  # @return [ValidationResult] Validation result for signing setup
  def validate_signing_configuration(project_path, signing_config)
    raise NotImplementedError, "Subclass must implement validate_signing_configuration"
  end
  
  # Check if scheme exists in project
  # @param project_path [String] Path to Xcode project
  # @param scheme [String] Scheme name to check
  # @return [Boolean] True if scheme exists
  def scheme_exists?(project_path, scheme)
    raise NotImplementedError, "Subclass must implement scheme_exists?"
  end
  
  # Query Operations
  
  # Get available schemes for project
  # @param project_path [String] Path to Xcode project
  # @return [Array<String>] Array of available scheme names
  def get_available_schemes(project_path)
    raise NotImplementedError, "Subclass must implement get_available_schemes"
  end
  
  # Get available configurations for project
  # @param project_path [String] Path to Xcode project
  # @return [Array<String>] Array of available configuration names
  def get_available_configurations(project_path)
    raise NotImplementedError, "Subclass must implement get_available_configurations"
  end
  
  # Get build settings for scheme and configuration
  # @param project_path [String] Path to Xcode project
  # @param scheme [String] Xcode scheme
  # @param configuration [String] Build configuration
  # @return [Hash] Build settings as key-value pairs
  def get_build_settings(project_path, scheme, configuration)
    raise NotImplementedError, "Subclass must implement get_build_settings"
  end
  
  # Archive Operations
  
  # Validate archive integrity
  # @param archive_path [String] Path to .xcarchive
  # @return [ValidationResult] Archive validation result
  def validate_archive(archive_path)
    raise NotImplementedError, "Subclass must implement validate_archive"
  end
  
  # Get archive metadata
  # @param archive_path [String] Path to .xcarchive
  # @return [ArchiveMetadata] Archive information and metadata
  def get_archive_metadata(archive_path)
    raise NotImplementedError, "Subclass must implement get_archive_metadata"
  end
  
  # IPA Operations
  
  # Validate IPA file
  # @param ipa_path [String] Path to .ipa file
  # @return [ValidationResult] IPA validation result
  def validate_ipa(ipa_path)
    raise NotImplementedError, "Subclass must implement validate_ipa"
  end
  
  # Get IPA metadata
  # @param ipa_path [String] Path to .ipa file
  # @return [IpaMetadata] IPA information and metadata
  def get_ipa_metadata(ipa_path)
    raise NotImplementedError, "Subclass must implement get_ipa_metadata"
  end
  
  # Repository Information
  
  # Get repository type/source information
  # @return [String] Repository type identifier ('xcode', 'xcodebuild', 'fastlane')
  def repository_type
    raise NotImplementedError, "Subclass must implement repository_type"
  end
  
  # Check if repository is available/accessible
  # @return [Boolean] True if build tools are available
  def available?
    raise NotImplementedError, "Subclass must implement available?"
  end
  
  # Get Xcode version information
  # @return [XcodeVersion] Xcode version and build tools information
  def get_xcode_version
    raise NotImplementedError, "Subclass must implement get_xcode_version"
  end
end