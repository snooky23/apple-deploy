# Build Application Use Case - Clean Architecture Domain Layer  
# Business workflow: Build and archive iOS application with proper code signing

class BuildApplication
  def initialize(build_repository:, application_repository:, logger:)
    @build_repository = build_repository
    @application_repository = application_repository
    @logger = logger
  end
  
  # Execute the use case to build and archive the iOS application
  # @param request [BuildApplicationRequest] Input parameters
  # @return [BuildApplicationResult] Result with build status and artifacts
  def execute(request)
    @logger.info("🔨 Starting application build for #{request.app_identifier}")
    
    begin
      # Business Logic: Validate input parameters
      validate_request(request)
      
      # Business Logic: Prepare build environment and configuration
      build_preparation = prepare_build_environment(request)
      
      # Business Logic: Configure code signing and provisioning
      signing_configuration = configure_code_signing(request, build_preparation)
      
      # Business Logic: Execute Xcode build and archive
      build_result = execute_build_and_archive(request, signing_configuration)
      
      # Business Logic: Validate build artifacts
      artifact_validation = validate_build_artifacts(build_result)
      
      # Business Logic: Prepare export configuration  
      export_configuration = prepare_export_configuration(request, signing_configuration)
      
      # Business Logic: Export IPA for distribution
      export_result = export_ipa(build_result, export_configuration)
      
      # Business Logic: Final validation of distribution artifacts
      final_validation = validate_distribution_artifacts(export_result)
      
      @logger.success("✅ Application build completed successfully")
      @logger.info("📦 IPA file: #{export_result.ipa_path}")
      @logger.info("📊 Build size: #{format_file_size(export_result.ipa_size)}")
      
      BuildApplicationResult.new(
        success: true,
        archive_path: build_result.archive_path,
        ipa_path: export_result.ipa_path,
        ipa_size: export_result.ipa_size,
        build_duration: build_result.build_duration,
        export_duration: export_result.export_duration,
        build_configuration: signing_configuration,
        validation_result: final_validation
      )
      
    rescue InvalidBuildConfigurationError => e
      @logger.error("❌ Invalid build configuration: #{e.message}")
      BuildApplicationResult.new(
        success: false,
        error: e.message,
        error_type: :invalid_build_configuration,
        recovery_suggestion: "Review Xcode project settings and build configuration"
      )
      
    rescue CodeSigningError => e
      @logger.error("❌ Code signing failed: #{e.message}")
      BuildApplicationResult.new(
        success: false,
        error: e.message,
        error_type: :code_signing_error,
        recovery_suggestion: "Verify certificates and provisioning profiles are valid and properly installed"
      )
      
    rescue BuildFailedError => e
      @logger.error("❌ Build failed: #{e.message}")
      BuildApplicationResult.new(
        success: false,
        error: e.message,
        error_type: :build_failed,
        recovery_suggestion: "Check Xcode build logs for compilation errors and dependencies"
      )
      
    rescue => e
      @logger.error("❌ Unexpected error during build: #{e.message}")
      BuildApplicationResult.new(
        success: false,
        error: e.message,
        error_type: :unexpected_error,
        recovery_suggestion: "Review build environment and system resources"
      )
    end
  end
  
  private
  
  # Validate input request parameters
  def validate_request(request)
    raise ArgumentError, "App identifier is required" if request.app_identifier.nil? || request.app_identifier.empty?
    raise ArgumentError, "Scheme is required" if request.scheme.nil? || request.scheme.empty?
    raise ArgumentError, "Team ID is required" if request.team_id.nil? || request.team_id.empty?
    raise ArgumentError, "Invalid team ID format" unless request.team_id.match?(/^[A-Z0-9]{10}$/)
  end
  
  # Prepare build environment and detect project configuration
  def prepare_build_environment(request)
    @logger.info("🛠️ Preparing build environment...")
    
    # Detect workspace or project file
    project_info = @build_repository.detect_project_structure(request.workspace_path)
    
    raise InvalidBuildConfigurationError, "No Xcode project or workspace found" unless project_info.found?
    
    # Get current application information
    application = @application_repository.find_by_identifier(request.app_identifier)
    
    # Validate scheme exists in project
    available_schemes = @build_repository.get_available_schemes(project_info.path)
    unless available_schemes.include?(request.scheme)
      raise InvalidBuildConfigurationError, "Scheme '#{request.scheme}' not found in project. Available: #{available_schemes.join(', ')}"
    end
    
    preparation_result = {
      project_info: project_info,
      application: application,
      available_schemes: available_schemes,
      build_directory: request.build_directory || "build"
    }
    
    @logger.info("✅ Build environment prepared:")
    @logger.info("   - Project: #{project_info.name} (#{project_info.type})")
    @logger.info("   - Scheme: #{request.scheme}")
    @logger.info("   - Configuration: #{request.configuration}")
    
    preparation_result
  end
  
  # Configure code signing and provisioning profiles
  def configure_code_signing(request, build_preparation)
    @logger.info("🔐 Configuring code signing...")
    
    application = build_preparation[:application]
    
    # Get code signing configuration from repositories
    signing_config = @build_repository.get_code_signing_configuration(
      app_identifier: request.app_identifier,
      team_id: request.team_id,
      configuration: request.configuration
    )
    
    # Validate code signing identity exists
    unless signing_config.identity_available?
      raise CodeSigningError, "No valid code signing identity found for team #{request.team_id}"
    end
    
    # Validate provisioning profile compatibility
    unless signing_config.provisioning_profile_valid?
      raise CodeSigningError, "No valid provisioning profile found for app #{request.app_identifier}"
    end
    
    configuration_result = {
      code_signing_identity: signing_config.identity,
      provisioning_profile: signing_config.provisioning_profile,
      team_id: request.team_id,
      keychain_path: request.keychain_path,
      configuration: request.configuration
    }
    
    @logger.info("✅ Code signing configured:")
    @logger.info("   - Identity: #{signing_config.identity}")
    @logger.info("   - Profile: #{signing_config.provisioning_profile}")
    @logger.info("   - Team: #{request.team_id}")
    
    configuration_result
  end
  
  # Execute Xcode build and archive process
  def execute_build_and_archive(request, signing_configuration)
    @logger.info("🏗️ Executing Xcode build and archive...")
    
    build_start_time = Time.now
    
    # Execute build with repository
    build_result = @build_repository.build_archive(
      scheme: request.scheme,
      configuration: request.configuration,
      app_identifier: request.app_identifier,
      code_signing_identity: signing_configuration[:code_signing_identity],
      provisioning_profile_specifier: signing_configuration[:provisioning_profile],
      team_id: signing_configuration[:team_id],
      keychain_path: signing_configuration[:keychain_path],
      output_directory: request.build_directory
    )
    
    build_duration = Time.now - build_start_time
    
    unless build_result.success?
      raise BuildFailedError, "Xcode build failed: #{build_result.error}"
    end
    
    @logger.info("✅ Build and archive completed in #{format_duration(build_duration)}")
    @logger.info("   - Archive: #{build_result.archive_path}")
    
    {
      archive_path: build_result.archive_path,
      build_duration: build_duration,
      build_logs: build_result.logs
    }
  end
  
  # Validate build artifacts are correctly generated
  def validate_build_artifacts(build_result)
    @logger.info("🔍 Validating build artifacts...")
    
    archive_path = build_result[:archive_path]
    
    # Check archive file exists
    unless File.exist?(archive_path)
      raise BuildFailedError, "Archive file not found at expected path: #{archive_path}"
    end
    
    # Validate archive structure
    archive_validation = @build_repository.validate_archive(archive_path)
    
    unless archive_validation.valid?
      raise BuildFailedError, "Invalid archive structure: #{archive_validation.errors.join(', ')}"
    end
    
    validation_result = {
      archive_exists: true,
      archive_valid: archive_validation.valid?,
      archive_size: File.size(archive_path),
      validation_details: archive_validation.details
    }
    
    @logger.info("✅ Build artifacts validated")
    @logger.info("   - Archive size: #{format_file_size(validation_result[:archive_size])}")
    
    validation_result
  end
  
  # Prepare export configuration for IPA generation
  def prepare_export_configuration(request, signing_configuration)
    @logger.info("📦 Preparing export configuration...")
    
    export_config = {
      export_method: request.export_method || "app-store",
      team_id: signing_configuration[:team_id],
      provisioning_profile_mapping: {
        request.app_identifier => signing_configuration[:provisioning_profile]
      },
      code_signing_identity: signing_configuration[:code_signing_identity],
      upload_symbols: request.upload_symbols.nil? ? true : request.upload_symbols,
      upload_bitcode: false  # Bitcode deprecated
    }
    
    @logger.info("✅ Export configuration prepared:")
    @logger.info("   - Method: #{export_config[:export_method]}")
    @logger.info("   - Upload symbols: #{export_config[:upload_symbols]}")
    
    export_config
  end
  
  # Export IPA file from archive
  def export_ipa(build_result, export_configuration)
    @logger.info("📱 Exporting IPA file...")
    
    export_start_time = Time.now
    
    # Execute export with repository
    export_result = @build_repository.export_ipa(
      archive_path: build_result[:archive_path],
      export_configuration: export_configuration,
      output_directory: File.dirname(build_result[:archive_path])
    )
    
    export_duration = Time.now - export_start_time
    
    unless export_result.success?
      raise BuildFailedError, "IPA export failed: #{export_result.error}"
    end
    
    ipa_size = File.size(export_result.ipa_path)
    
    @logger.info("✅ IPA export completed in #{format_duration(export_duration)}")
    @logger.info("   - IPA: #{export_result.ipa_path}")
    @logger.info("   - Size: #{format_file_size(ipa_size)}")
    
    {
      ipa_path: export_result.ipa_path,
      ipa_size: ipa_size,
      export_duration: export_duration,
      export_logs: export_result.logs
    }
  end
  
  # Validate final distribution artifacts
  def validate_distribution_artifacts(export_result)
    @logger.info("🎯 Validating distribution artifacts...")
    
    ipa_path = export_result[:ipa_path]
    
    # Check IPA file exists
    unless File.exist?(ipa_path)
      raise BuildFailedError, "IPA file not found at expected path: #{ipa_path}"
    end
    
    # Validate IPA structure and signing
    ipa_validation = @build_repository.validate_ipa(ipa_path)
    
    unless ipa_validation.valid?
      raise CodeSigningError, "Invalid IPA signing: #{ipa_validation.errors.join(', ')}"
    end
    
    validation_result = {
      ipa_exists: true,
      ipa_valid: ipa_validation.valid?,
      ipa_size: export_result[:ipa_size],
      code_signing_valid: ipa_validation.code_signing_valid?,
      ready_for_distribution: ipa_validation.ready_for_distribution?
    }
    
    @logger.info("✅ Distribution artifacts validated")
    @logger.info("   - Code signing: #{validation_result[:code_signing_valid] ? 'Valid' : 'Invalid'}")
    @logger.info("   - Ready for distribution: #{validation_result[:ready_for_distribution]}")
    
    validation_result
  end
  
  # Format file size for human-readable display
  def format_file_size(size_bytes)
    units = %w[B KB MB GB]
    size = size_bytes.to_f
    unit_index = 0
    
    while size >= 1024 && unit_index < units.length - 1
      size /= 1024
      unit_index += 1
    end
    
    format("%.1f %s", size, units[unit_index])
  end
  
  # Format duration for human-readable display
  def format_duration(duration_seconds)
    minutes = (duration_seconds / 60).to_i
    seconds = (duration_seconds % 60).to_i
    
    if minutes > 0
      "#{minutes}m #{seconds}s"
    else
      "#{seconds}s"
    end
  end
end

# Request object for BuildApplication use case
class BuildApplicationRequest
  attr_reader :app_identifier, :scheme, :team_id, :configuration, :workspace_path,
              :build_directory, :keychain_path, :export_method, :upload_symbols
  
  def initialize(app_identifier:, scheme:, team_id:, configuration: "Release",
                 workspace_path: nil, build_directory: nil, keychain_path: nil,
                 export_method: "app-store", upload_symbols: true)
    @app_identifier = app_identifier
    @scheme = scheme
    @team_id = team_id
    @configuration = configuration
    @workspace_path = workspace_path
    @build_directory = build_directory
    @keychain_path = keychain_path
    @export_method = export_method
    @upload_symbols = upload_symbols
  end
end

# Result object for BuildApplication use case
class BuildApplicationResult
  attr_reader :success, :archive_path, :ipa_path, :ipa_size, :build_duration,
              :export_duration, :build_configuration, :validation_result,
              :error, :error_type, :recovery_suggestion
  
  def initialize(success:, archive_path: nil, ipa_path: nil, ipa_size: nil,
                 build_duration: nil, export_duration: nil, build_configuration: nil,
                 validation_result: nil, error: nil, error_type: nil, recovery_suggestion: nil)
    @success = success
    @archive_path = archive_path
    @ipa_path = ipa_path
    @ipa_size = ipa_size
    @build_duration = build_duration
    @export_duration = export_duration
    @build_configuration = build_configuration
    @validation_result = validation_result
    @error = error
    @error_type = error_type
    @recovery_suggestion = recovery_suggestion
  end
  
  def success?
    @success
  end
  
  def ready_for_distribution?
    success? && @validation_result&.dig(:ready_for_distribution)
  end
  
  def total_duration
    return nil unless @build_duration && @export_duration
    @build_duration + @export_duration
  end
end

# Custom exceptions for build management
class InvalidBuildConfigurationError < StandardError; end
class CodeSigningError < StandardError; end
class BuildFailedError < StandardError; end