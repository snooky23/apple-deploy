# Upload Repository Interface - Clean Architecture Domain Layer
# Defines all TestFlight and App Store upload operations without implementation details

module UploadRepository
  # TestFlight Upload Operations
  
  # Upload IPA to TestFlight
  # @param ipa_path [String] Path to .ipa file
  # @param api_credentials [ApiCredentials] App Store Connect API credentials
  # @param options [Hash] Upload options (enhanced mode, metadata, etc.)
  # @return [UploadResult] Upload result with status and metadata
  def upload_to_testflight(ipa_path, api_credentials, options = {})
    raise NotImplementedError, "Subclass must implement upload_to_testflight"
  end
  
  # Upload to TestFlight with metadata
  # @param ipa_path [String] Path to .ipa file
  # @param api_credentials [ApiCredentials] App Store Connect API credentials
  # @param metadata [TestFlightMetadata] Upload metadata and options
  # @return [UploadResult] Upload result with detailed information
  def upload_with_metadata(ipa_path, api_credentials, metadata)
    raise NotImplementedError, "Subclass must implement upload_with_metadata"
  end
  
  # Status Operations
  
  # Get upload status by upload ID
  # @param upload_id [String] Upload identifier
  # @return [UploadStatus] Current upload status and progress
  def get_upload_status(upload_id)
    raise NotImplementedError, "Subclass must implement get_upload_status"
  end
  
  # Get build processing status
  # @param app_identifier [String] Bundle identifier
  # @param build_number [String, Integer] Build number
  # @param api_credentials [ApiCredentials] App Store Connect API credentials
  # @return [ProcessingStatus] Build processing status
  def get_processing_status(app_identifier, build_number, api_credentials)
    raise NotImplementedError, "Subclass must implement get_processing_status"
  end
  
  # Wait for processing completion
  # @param app_identifier [String] Bundle identifier
  # @param build_number [String, Integer] Build number
  # @param api_credentials [ApiCredentials] App Store Connect API credentials
  # @param timeout [Integer] Timeout in seconds (default: 600)
  # @return [ProcessingResult] Final processing result
  def wait_for_processing(app_identifier, build_number, api_credentials, timeout = 600)
    raise NotImplementedError, "Subclass must implement wait_for_processing"
  end
  
  # TestFlight Query Operations
  
  # Get recent TestFlight builds
  # @param app_identifier [String] Bundle identifier
  # @param api_credentials [ApiCredentials] App Store Connect API credentials
  # @param limit [Integer] Maximum number of builds to return
  # @return [Array<TestFlightBuild>] Array of recent builds
  def get_testflight_builds(app_identifier, api_credentials, limit = 10)
    raise NotImplementedError, "Subclass must implement get_testflight_builds"
  end
  
  # Get latest TestFlight build
  # @param app_identifier [String] Bundle identifier
  # @param api_credentials [ApiCredentials] App Store Connect API credentials
  # @return [TestFlightBuild, nil] Latest build or nil if none found
  def get_latest_build(app_identifier, api_credentials)
    raise NotImplementedError, "Subclass must implement get_latest_build"
  end
  
  # Get build by version and build number
  # @param app_identifier [String] Bundle identifier
  # @param version [String] Marketing version
  # @param build_number [String, Integer] Build number
  # @param api_credentials [ApiCredentials] App Store Connect API credentials
  # @return [TestFlightBuild, nil] Matching build or nil if not found
  def get_build(app_identifier, version, build_number, api_credentials)
    raise NotImplementedError, "Subclass must implement get_build"
  end
  
  # Build Management Operations
  
  # Update build metadata
  # @param build_id [String] TestFlight build ID
  # @param metadata [BuildMetadata] Updated metadata
  # @param api_credentials [ApiCredentials] App Store Connect API credentials
  # @return [Boolean] True if update successful
  def update_build_metadata(build_id, metadata, api_credentials)
    raise NotImplementedError, "Subclass must implement update_build_metadata"
  end
  
  # Enable/disable external testing
  # @param build_id [String] TestFlight build ID
  # @param enabled [Boolean] True to enable external testing
  # @param api_credentials [ApiCredentials] App Store Connect API credentials
  # @return [Boolean] True if update successful
  def set_external_testing(build_id, enabled, api_credentials)
    raise NotImplementedError, "Subclass must implement set_external_testing"
  end
  
  # Add tester groups to build
  # @param build_id [String] TestFlight build ID
  # @param group_names [Array<String>] Tester group names
  # @param api_credentials [ApiCredentials] App Store Connect API credentials
  # @return [Boolean] True if groups added successfully
  def add_tester_groups(build_id, group_names, api_credentials)
    raise NotImplementedError, "Subclass must implement add_tester_groups"
  end
  
  # Validation Operations
  
  # Validate IPA before upload
  # @param ipa_path [String] Path to .ipa file
  # @return [ValidationResult] IPA validation result
  def validate_ipa(ipa_path)
    raise NotImplementedError, "Subclass must implement validate_ipa"
  end
  
  # Validate API credentials
  # @param api_credentials [ApiCredentials] Credentials to validate
  # @return [ValidationResult] Credentials validation result
  def validate_api_credentials(api_credentials)
    raise NotImplementedError, "Subclass must implement validate_api_credentials"
  end
  
  # Check upload eligibility
  # @param app_identifier [String] Bundle identifier
  # @param version [String] Marketing version
  # @param build_number [String, Integer] Build number
  # @param api_credentials [ApiCredentials] App Store Connect API credentials
  # @return [EligibilityResult] Upload eligibility result
  def check_upload_eligibility(app_identifier, version, build_number, api_credentials)
    raise NotImplementedError, "Subclass must implement check_upload_eligibility"
  end
  
  # App Store Operations
  
  # Get app information from App Store Connect
  # @param app_identifier [String] Bundle identifier
  # @param api_credentials [ApiCredentials] App Store Connect API credentials
  # @return [AppInfo] App information and metadata
  def get_app_info(app_identifier, api_credentials)
    raise NotImplementedError, "Subclass must implement get_app_info"
  end
  
  # Get app store versions
  # @param app_identifier [String] Bundle identifier
  # @param api_credentials [ApiCredentials] App Store Connect API credentials
  # @return [Array<AppStoreVersion>] Array of app store versions
  def get_app_store_versions(app_identifier, api_credentials)
    raise NotImplementedError, "Subclass must implement get_app_store_versions"
  end
  
  # Retry Operations
  
  # Retry failed upload
  # @param upload_id [String] Failed upload identifier
  # @param retry_options [Hash] Retry configuration options
  # @return [UploadResult] Retry result
  def retry_upload(upload_id, retry_options = {})
    raise NotImplementedError, "Subclass must implement retry_upload"
  end
  
  # Cancel ongoing upload
  # @param upload_id [String] Upload identifier to cancel
  # @return [Boolean] True if cancellation successful
  def cancel_upload(upload_id)
    raise NotImplementedError, "Subclass must implement cancel_upload"
  end
  
  # Repository Information
  
  # Get repository type/source information
  # @return [String] Repository type identifier ('altool', 'fastlane', 'spaceship')
  def repository_type
    raise NotImplementedError, "Subclass must implement repository_type"
  end
  
  # Check if repository is available/accessible
  # @return [Boolean] True if upload service is accessible
  def available?
    raise NotImplementedError, "Subclass must implement available?"
  end
  
  # Get service status information
  # @return [ServiceStatus] Upload service status and capabilities
  def get_service_status
    raise NotImplementedError, "Subclass must implement get_service_status"
  end
end