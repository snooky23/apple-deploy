# DeploymentService - Clean Architecture Application Layer
# Orchestrates the complete iOS deployment workflow using domain entities and repository interfaces

require_relative '../../shared/container/di_container'
require_relative '../../domain/entities/certificate'
require_relative '../../domain/entities/provisioning_profile'
require_relative '../../domain/entities/application'
require_relative '../../domain/entities/team'
require_relative '../../domain/entities/deployment_history'
require_relative '../../domain/entities/api_credentials'

class DeploymentService
  attr_reader :container, :logger
  
  # Initialize DeploymentService with dependency injection
  # @param container [DIContainer] Dependency injection container
  # @param logger [Logger, nil] Optional logger
  def initialize(container:, logger: nil)
    @container = container
    @logger = logger
    
    # Register repositories if not already registered
    setup_repositories unless repositories_configured?
  end
  
  # Execute complete deployment workflow
  # @param deployment_config [Hash] Deployment configuration
  # @return [DeploymentResult] Complete deployment result
  def execute_deployment(deployment_config)
    log_info("Starting deployment workflow for #{deployment_config[:app_identifier]}")
    
    deployment_start_time = Time.now
    deployment_id = generate_deployment_id(deployment_config[:team_id], deployment_config[:app_identifier])
    
    # Initialize deployment history
    deployment_history = create_deployment_history(deployment_id, deployment_config, deployment_start_time)
    
    begin
      # Phase 1: Certificate Management
      log_info("Phase 1: Certificate Management")
      certificate_result = ensure_valid_certificates(deployment_config)
      deployment_history = deployment_history.add_log_entry("Certificate validation: #{certificate_result.success? ? 'SUCCESS' : 'FAILED'}")
      
      return create_failed_deployment_result(deployment_history, "Certificate validation failed: #{certificate_result.error}") unless certificate_result.success?
      
      # Phase 2: Provisioning Profile Management  
      log_info("Phase 2: Provisioning Profile Management")
      profile_result = ensure_valid_profiles(deployment_config, certificate_result.certificates)
      deployment_history = deployment_history.add_log_entry("Profile validation: #{profile_result.success? ? 'SUCCESS' : 'FAILED'}")
      
      return create_failed_deployment_result(deployment_history, "Profile validation failed: #{profile_result.error}") unless profile_result.success?
      
      # Phase 3: Version Management
      log_info("Phase 3: Version Management")
      version_result = manage_version_numbers(deployment_config)
      deployment_history = deployment_history.add_log_entry("Version update: #{version_result.new_version}(#{version_result.new_build_number})")
      
      return create_failed_deployment_result(deployment_history, "Version management failed: #{version_result.error}") unless version_result.success?
      
      # Phase 4: Build Process
      log_info("Phase 4: Build and Archive")
      build_result = build_and_archive(deployment_config, version_result)
      deployment_history = deployment_history.add_log_entry("Build: #{build_result.success? ? 'SUCCESS' : 'FAILED'}")
      
      return create_failed_deployment_result(deployment_history, "Build failed: #{build_result.error}") unless build_result.success?
      
      # Phase 5: TestFlight Upload
      log_info("Phase 5: TestFlight Upload")
      upload_result = upload_to_testflight(deployment_config, build_result)
      deployment_history = deployment_history.add_log_entry("Upload: #{upload_result.success? ? 'SUCCESS' : 'FAILED'}")
      
      return create_failed_deployment_result(deployment_history, "Upload failed: #{upload_result.error}") unless upload_result.success?
      
      # Phase 6: Processing Monitoring (Optional)
      if deployment_config[:wait_for_processing]
        log_info("Phase 6: Processing Monitoring")
        processing_result = monitor_processing(deployment_config, version_result.new_build_number)
        deployment_history = deployment_history.add_log_entry("Processing: #{processing_result.success? ? 'COMPLETE' : 'TIMEOUT/FAILED'}")
      end
      
      # Complete deployment
      deployment_duration = Time.now - deployment_start_time
      final_deployment_history = deployment_history
        .complete(upload_result.testflight_url)
        .with_metadata('duration', deployment_duration)
        .with_metadata('final_version', "#{version_result.new_version}(#{version_result.new_build_number})")
      
      log_info("Deployment completed successfully in #{deployment_duration.round(1)}s")
      
      DeploymentResult.new(
        success: true,
        deployment_id: deployment_id,
        deployment_history: final_deployment_history,
        final_version: version_result.new_version,
        final_build_number: version_result.new_build_number,
        ipa_path: build_result.ipa_path,
        testflight_url: upload_result.testflight_url,
        duration: deployment_duration,
        error: nil
      )
      
    rescue => e
      log_error("Deployment failed with exception: #{e.message}")
      deployment_history = deployment_history.fail('deployment_exception', e.message)
      create_failed_deployment_result(deployment_history, e.message)
    end
  end
  
  # Execute certificate validation workflow
  # @param deployment_config [Hash] Deployment configuration  
  # @return [CertificateValidationResult] Certificate validation result
  def ensure_valid_certificates(deployment_config)
    log_info("Validating certificates for team: #{deployment_config[:team_id]}")
    
    certificate_repo = @container.resolve(:certificate_repository)
    team_id = deployment_config[:team_id]
    
    # Get existing certificates
    existing_certificates = certificate_repo.find_by_team(team_id)
    valid_certificates = existing_certificates.select { |cert| !cert.expired? && cert.valid_for_team?(team_id) }
    
    # Check if we have required certificate types
    development_certs = valid_certificates.select { |cert| cert.certificate_type == 'development' }
    distribution_certs = valid_certificates.select { |cert| cert.certificate_type == 'distribution' }
    
    issues = []
    
    # Validate development certificates
    if development_certs.empty?
      issues << "No valid development certificates found"
    elsif !certificate_repo.has_private_key?(development_certs.first)
      issues << "Development certificate missing private key"
    end
    
    # Validate distribution certificates  
    if distribution_certs.empty?
      issues << "No valid distribution certificates found"
    elsif !certificate_repo.has_private_key?(distribution_certs.first)
      issues << "Distribution certificate missing private key"
    end
    
    if issues.empty?
      CertificateValidationResult.new(
        success: true,
        certificates: valid_certificates,
        development_certificates: development_certs,
        distribution_certificates: distribution_certs,
        error: nil
      )
    else
      CertificateValidationResult.new(
        success: false,
        certificates: [],
        development_certificates: [],
        distribution_certificates: [],
        error: issues.join('; ')
      )
    end
  rescue => e
    log_error("Certificate validation error: #{e.message}")
    CertificateValidationResult.new(
      success: false,
      certificates: [],
      development_certificates: [],
      distribution_certificates: [],
      error: e.message
    )
  end
  
  # Execute provisioning profile validation workflow
  # @param deployment_config [Hash] Deployment configuration
  # @param certificates [Array<Certificate>] Available certificates
  # @return [ProfileValidationResult] Profile validation result
  def ensure_valid_profiles(deployment_config, certificates)
    log_info("Validating provisioning profiles")
    
    profile_repo = @container.resolve(:profile_repository)
    app_identifier = deployment_config[:app_identifier]
    team_id = deployment_config[:team_id]
    
    # Find profiles for the app
    app_profiles = profile_repo.find_by_app_identifier(app_identifier, team_id)
    
    # Filter valid profiles
    valid_profiles = app_profiles.select do |profile|
      !profile_repo.is_expired?(profile) && 
      profile_repo.validate_profile(profile, app_identifier, certificates)
    end
    
    # Separate by type
    development_profiles = valid_profiles.select { |p| p.profile_type == 'development' }
    distribution_profiles = valid_profiles.select { |p| p.profile_type == 'distribution' }
    
    issues = []
    issues << "No valid development profiles found" if development_profiles.empty?
    issues << "No valid distribution profiles found" if distribution_profiles.empty?
    
    if issues.empty?
      ProfileValidationResult.new(
        success: true,
        profiles: valid_profiles,
        development_profiles: development_profiles,
        distribution_profiles: distribution_profiles,
        error: nil
      )
    else
      ProfileValidationResult.new(
        success: false,
        profiles: [],
        development_profiles: [],
        distribution_profiles: [],
        error: issues.join('; ')
      )
    end
  rescue => e
    log_error("Profile validation error: #{e.message}")
    ProfileValidationResult.new(
      success: false,
      profiles: [],
      development_profiles: [],
      distribution_profiles: [],
      error: e.message
    )
  end
  
  # Execute version management workflow
  # @param deployment_config [Hash] Deployment configuration
  # @return [VersionManagementResult] Version management result
  def manage_version_numbers(deployment_config)
    log_info("Managing version numbers")
    
    build_repo = @container.resolve(:build_repository)
    project_path = deployment_config[:project_path]
    version_bump = deployment_config[:version_bump] || 'patch'
    
    # Get current version info
    current_version_info = build_repo.get_current_version_info(project_path)
    
    # Calculate new version
    new_version = calculate_new_version(current_version_info.marketing_version, version_bump)
    new_build_number = current_version_info.build_number + 1
    
    # Update project files
    version_success = build_repo.update_version_number(project_path, new_version)
    build_success = build_repo.update_build_number(project_path, new_build_number)
    
    if version_success && build_success
      VersionManagementResult.new(
        success: true,
        old_version: current_version_info.marketing_version,
        new_version: new_version,
        old_build_number: current_version_info.build_number,
        new_build_number: new_build_number,
        error: nil
      )
    else
      VersionManagementResult.new(
        success: false,
        old_version: current_version_info.marketing_version,
        new_version: new_version,
        old_build_number: current_version_info.build_number,
        new_build_number: new_build_number,
        error: 'Failed to update version numbers in project'
      )
    end
  rescue => e
    log_error("Version management error: #{e.message}")
    VersionManagementResult.new(
      success: false,
      old_version: '1.0.0',
      new_version: '1.0.1',
      old_build_number: 1,
      new_build_number: 2,
      error: e.message
    )
  end
  
  # Execute build and archive workflow
  # @param deployment_config [Hash] Deployment configuration
  # @param version_result [VersionManagementResult] Version management result
  # @return [BuildResult] Build result
  def build_and_archive(deployment_config, version_result)
    log_info("Building and archiving application")
    
    build_repo = @container.resolve(:build_repository)
    project_path = deployment_config[:project_path]
    scheme = deployment_config[:scheme]
    configuration = deployment_config[:configuration] || 'Release'
    
    # Create signing configuration
    signing_config = create_signing_configuration(deployment_config)
    
    # Generate archive path
    archive_name = "#{deployment_config[:app_name]}_#{version_result.new_version}_#{version_result.new_build_number}"
    archive_path = File.join(Dir.tmpdir, "#{archive_name}.xcarchive")
    
    # Build archive
    build_result = build_repo.build_archive(project_path, scheme, configuration, archive_path, signing_config)
    
    return build_result unless build_result.success?
    
    # Export IPA
    export_options = {
      method: deployment_config[:export_method] || 'app-store',
      upload_bitcode: false,
      upload_symbols: true,
      compile_bitcode: false
    }
    
    ipa_export_path = File.join(Dir.tmpdir, "#{archive_name}_ipa")
    ipa_result = build_repo.export_ipa(archive_path, export_options, ipa_export_path)
    
    if ipa_result.success?
      # Find the generated IPA
      ipa_files = Dir.glob(File.join(ipa_export_path, '*.ipa'))
      ipa_path = ipa_files.first
      
      BuildResult.new(
        success: true,
        archive_path: archive_path,
        ipa_path: ipa_path,
        duration: build_result.duration + ipa_result.duration,
        build_logs: build_result.build_logs + ipa_result.build_logs,
        metadata: build_result.metadata.merge(ipa_result.metadata),
        error: nil
      )
    else
      ipa_result
    end
  rescue => e
    log_error("Build error: #{e.message}")
    BuildResult.new(
      success: false,
      archive_path: nil,
      ipa_path: nil,
      duration: 0,
      build_logs: [],
      metadata: {},
      error: e.message
    )
  end
  
  # Execute TestFlight upload workflow
  # @param deployment_config [Hash] Deployment configuration
  # @param build_result [BuildResult] Build result
  # @return [UploadResult] Upload result
  def upload_to_testflight(deployment_config, build_result)
    log_info("Uploading to TestFlight")
    
    upload_repo = @container.resolve(:upload_repository)
    
    # Create API credentials
    api_credentials = create_api_credentials(deployment_config)
    
    # Configure upload options
    upload_options = {
      enhanced: deployment_config[:testflight_enhanced] || false,
      changelog: deployment_config[:changelog],
      auto_notify: deployment_config[:auto_notify] || false
    }
    
    # Execute upload
    upload_result = upload_repo.upload_to_testflight(build_result.ipa_path, api_credentials, upload_options)
    
    if upload_result.success?
      log_info("Upload successful")
      # Try to get TestFlight URL from latest build
      begin
        latest_build = upload_repo.get_latest_build(deployment_config[:app_identifier], api_credentials)
        testflight_url = latest_build&.build_id ? "https://appstoreconnect.apple.com/apps/testflight/#{latest_build.build_id}" : nil
        
        UploadResult.new(
          success: true,
          message: upload_result.message,
          upload_logs: upload_result.upload_logs,
          testflight_url: testflight_url,
          error: nil,
          metadata: upload_result.metadata
        )
      rescue
        # Fallback to original result if URL lookup fails
        upload_result
      end
    else
      upload_result
    end
  rescue => e
    log_error("Upload error: #{e.message}")
    UploadResult.new(
      success: false,
      message: 'Upload failed',
      upload_logs: [],
      testflight_url: nil,
      error: e.message,
      metadata: {}
    )
  end
  
  # Monitor TestFlight processing status
  # @param deployment_config [Hash] Deployment configuration
  # @param build_number [String, Integer] Build number to monitor
  # @return [ProcessingResult] Processing result
  def monitor_processing(deployment_config, build_number)
    log_info("Monitoring TestFlight processing")
    
    upload_repo = @container.resolve(:upload_repository)
    api_credentials = create_api_credentials(deployment_config)
    timeout = deployment_config[:processing_timeout] || 600
    
    upload_repo.wait_for_processing(
      deployment_config[:app_identifier],
      build_number,
      api_credentials,
      timeout
    )
  rescue => e
    log_error("Processing monitoring error: #{e.message}")
    ProcessingResult.new(
      success: false,
      final_status: 'ERROR',
      duration: 0,
      ready_for_testing: false,
      error_details: e.message
    )
  end
  
  private
  
  # Setup repository dependencies
  def setup_repositories
    require_relative '../../infrastructure/repositories/certificate_repository_impl'
    require_relative '../../infrastructure/repositories/profile_repository_impl'
    require_relative '../../infrastructure/repositories/build_repository_impl'
    require_relative '../../infrastructure/repositories/upload_repository_impl'
    
    @container.register(:certificate_repository) { CertificateRepositoryImpl.new(logger: @logger) }
    @container.register(:profile_repository) { ProfileRepositoryImpl.new(logger: @logger) }
    @container.register(:build_repository) { BuildRepositoryImpl.new(logger: @logger) }
    @container.register(:upload_repository) { UploadRepositoryImpl.new(logger: @logger) }
  end
  
  def repositories_configured?
    [:certificate_repository, :profile_repository, :build_repository, :upload_repository].all? do |repo|
      @container.registered?(repo)
    end
  end
  
  def create_deployment_history(deployment_id, deployment_config, start_time)
    DeploymentHistory.new(
      deployment_id: deployment_id,
      team_id: deployment_config[:team_id],
      app_identifier: deployment_config[:app_identifier],
      deployment_type: 'testflight',
      status: 'initiated',
      marketing_version: '1.0.0',  # Will be updated during version management
      build_number: '1',           # Will be updated during version management  
      initiated_by: deployment_config[:initiated_by] || 'deployment_service',
      initiated_at: start_time,
      metadata: {
        'scheme' => deployment_config[:scheme],
        'configuration' => deployment_config[:configuration] || 'Release',
        'version_bump' => deployment_config[:version_bump] || 'patch'
      }
    )
  end
  
  def create_signing_configuration(deployment_config)
    SigningConfiguration.new(
      development_team: deployment_config[:team_id],
      code_sign_identity: deployment_config[:code_sign_identity],
      provisioning_profile: deployment_config[:provisioning_profile]
    )
  end
  
  def create_api_credentials(deployment_config)
    ApiCredentials.app_store_connect(
      team_id: deployment_config[:team_id],
      api_key_id: deployment_config[:api_key_id],
      api_issuer_id: deployment_config[:api_issuer_id],
      api_key_path: deployment_config[:api_key_path],
      security_level: 'high'
    )
  end
  
  def calculate_new_version(current_version, version_bump)
    version_parts = current_version.split('.').map(&:to_i)
    
    case version_bump.downcase
    when 'major'
      "#{version_parts[0] + 1}.0.0"
    when 'minor'
      "#{version_parts[0]}.#{version_parts[1] + 1}.0"
    when 'patch'
      "#{version_parts[0]}.#{version_parts[1]}.#{version_parts[2] + 1}"
    else
      current_version
    end
  end
  
  def generate_deployment_id(team_id, app_identifier)
    timestamp = Time.now.strftime('%Y%m%d_%H%M%S')
    random_suffix = SecureRandom.hex(3).upcase
    app_prefix = app_identifier.split('.').last.upcase[0, 4] rescue 'APP'
    
    "DEPLOY_#{team_id}_#{app_prefix}_#{timestamp}_#{random_suffix}"
  end
  
  def create_failed_deployment_result(deployment_history, error_message)
    DeploymentResult.new(
      success: false,
      deployment_id: deployment_history.deployment_id,
      deployment_history: deployment_history.fail('deployment_failed', error_message),
      final_version: nil,
      final_build_number: nil,
      ipa_path: nil,
      testflight_url: nil,
      duration: Time.now - deployment_history.initiated_at,
      error: error_message
    )
  end
  
  # Logging methods
  
  def log_info(message)
    @logger&.info("[DeploymentService] #{message}")
  end
  
  def log_error(message)
    @logger&.error("[DeploymentService] #{message}")
  end
end

# Supporting result classes

class DeploymentResult
  attr_reader :success, :deployment_id, :deployment_history, :final_version, :final_build_number,
              :ipa_path, :testflight_url, :duration, :error
  
  def initialize(success:, deployment_id:, deployment_history:, final_version: nil, final_build_number: nil,
                 ipa_path: nil, testflight_url: nil, duration: 0, error: nil)
    @success = success
    @deployment_id = deployment_id
    @deployment_history = deployment_history
    @final_version = final_version
    @final_build_number = final_build_number
    @ipa_path = ipa_path
    @testflight_url = testflight_url
    @duration = duration
    @error = error
  end
  
  def success?
    @success
  end
  
  def to_hash
    {
      success: @success,
      deployment_id: @deployment_id,
      deployment_history: @deployment_history.to_hash,
      final_version: @final_version,
      final_build_number: @final_build_number,
      ipa_path: @ipa_path,
      testflight_url: @testflight_url,
      duration: @duration,
      error: @error
    }
  end
end

class CertificateValidationResult
  attr_reader :success, :certificates, :development_certificates, :distribution_certificates, :error
  
  def initialize(success:, certificates:, development_certificates:, distribution_certificates:, error: nil)
    @success = success
    @certificates = certificates
    @development_certificates = development_certificates
    @distribution_certificates = distribution_certificates
    @error = error
  end
  
  def success?
    @success
  end
end

class ProfileValidationResult
  attr_reader :success, :profiles, :development_profiles, :distribution_profiles, :error
  
  def initialize(success:, profiles:, development_profiles:, distribution_profiles:, error: nil)
    @success = success
    @profiles = profiles
    @development_profiles = development_profiles
    @distribution_profiles = distribution_profiles
    @error = error
  end
  
  def success?
    @success
  end
end

class VersionManagementResult
  attr_reader :success, :old_version, :new_version, :old_build_number, :new_build_number, :error
  
  def initialize(success:, old_version:, new_version:, old_build_number:, new_build_number:, error: nil)
    @success = success
    @old_version = old_version
    @new_version = new_version
    @old_build_number = old_build_number
    @new_build_number = new_build_number
    @error = error
  end
  
  def success?
    @success
  end
end

# Import required classes from infrastructure layer
begin
  require_relative '../../infrastructure/repositories/build_repository_impl'
rescue LoadError
  # Define placeholder classes if infrastructure not loaded yet
  class BuildResult
    attr_reader :success, :archive_path, :ipa_path, :duration, :build_logs, :metadata, :error
    
    def initialize(success:, archive_path: nil, ipa_path: nil, duration: 0, build_logs: [], metadata: {}, error: nil)
      @success = success
      @archive_path = archive_path
      @ipa_path = ipa_path
      @duration = duration
      @build_logs = build_logs
      @metadata = metadata
      @error = error
    end
    
    def success?
      @success
    end
  end
  
  class SigningConfiguration
    attr_reader :development_team, :code_sign_identity, :provisioning_profile
    
    def initialize(development_team:, code_sign_identity: nil, provisioning_profile: nil)
      @development_team = development_team
      @code_sign_identity = code_sign_identity
      @provisioning_profile = provisioning_profile
    end
  end
  
  class UploadResult
    attr_reader :success, :message, :upload_logs, :testflight_url, :error, :metadata
    
    def initialize(success:, message:, upload_logs: [], testflight_url: nil, error: nil, metadata: {})
      @success = success
      @message = message
      @upload_logs = upload_logs
      @testflight_url = testflight_url
      @error = error
      @metadata = metadata
    end
    
    def success?
      @success
    end
  end
  
  class ProcessingResult
    attr_reader :success, :final_status, :duration, :ready_for_testing, :error_details
    
    def initialize(success:, final_status:, duration:, ready_for_testing:, error_details: nil)
      @success = success
      @final_status = final_status
      @duration = duration
      @ready_for_testing = ready_for_testing
      @error_details = error_details
    end
    
    def success?
      @success
    end
  end
end