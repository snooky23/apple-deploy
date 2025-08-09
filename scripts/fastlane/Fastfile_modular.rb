# World-Class Modular FastLane Implementation
# This replaces the monolithic 5,131-line Fastfile with a clean, maintainable system

# Import modular architecture
require_relative 'modules/core/logger'
require_relative 'modules/core/validator'
require_relative 'modules/core/progress'
require_relative 'modules/core/error_handler'
require_relative 'modules/auth/api_manager'
require_relative 'modules/auth/keychain_manager'
require_relative 'modules/certificates/manager'
require_relative 'modules/utils/file_utils'
require_relative 'modules/utils/shell_utils'

# Initialize modular system
FastlaneLogger.initialize_logger
FastlaneLogger.set_log_level(:INFO)

default_platform(:ios)

platform :ios do
  
  # Main deployment lane using modular architecture
  lane :build_and_upload do |options|
    # Initialize progress tracker
    progress = create_progress_tracker([
      { name: "Parameter Validation", description: "Validating deployment parameters" },
      { name: "Environment Setup", description: "Preparing deployment environment" },
      { name: "Authentication", description: "Setting up Apple API authentication" },
      { name: "Certificate Management", description: "Ensuring certificates are available" },
      { name: "Profile Management", description: "Managing provisioning profiles" },
      { name: "Version Management", description: "Handling version increments" },
      { name: "Build & Archive", description: "Building and archiving application" },
      { name: "TestFlight Upload", description: "Uploading to TestFlight" }
    ])
    
    with_error_handling("iOS Deployment Pipeline") do
      
      # Step 1: Parameter Validation
      step = progress.start_step("Parameter Validation")
      validate_parameters(options, :build_and_upload)
      progress.complete_step(true, "All parameters validated successfully")
      
      # Step 2: Environment Setup
      step = progress.start_step("Environment Setup")
      setup_deployment_environment(options)
      progress.complete_step(true, "Environment ready for deployment")
      
      # Step 3: Authentication
      step = progress.start_step("Authentication")
      api_manager = setup_api_authentication(options)
      progress.complete_step(true, "Apple API authentication successful")
      
      # Step 4: Certificate Management
      step = progress.start_step("Certificate Management")
      certificate_status = ensure_certificates_available(options)
      progress.complete_step(true, "All required certificates are available")
      
      # Step 5: Profile Management (placeholder for now)
      step = progress.start_step("Profile Management")
      setup_provisioning_profiles(options)
      progress.complete_step(true, "Provisioning profiles configured")
      
      # Step 6: Version Management
      step = progress.start_step("Version Management")
      version_info = handle_version_management(options)
      progress.complete_step(true, "Version updated to #{version_info[:final_version]}")
      
      # Step 7: Build & Archive
      step = progress.start_step("Build & Archive")
      ipa_path = build_and_archive_app(options)
      progress.complete_step(true, "IPA created: #{File.basename(ipa_path)}")
      
      # Step 8: TestFlight Upload
      step = progress.start_step("TestFlight Upload")
      upload_result = upload_to_testflight_secure(ipa_path, api_manager, options)
      progress.complete_step(true, "Upload completed successfully")
      
      # Log final success
      FastlaneLogger.header("DEPLOYMENT COMPLETED", "Successfully deployed to TestFlight")
      FastlaneLogger.success("🎉 Deployment pipeline completed successfully!", {
        app_identifier: options[:app_identifier],
        version: version_info[:final_version],
        ipa_path: File.basename(ipa_path),
        upload_result: upload_result
      })
    end
  end
  
  # Setup deployment environment
  private_lane :setup_deployment_environment do |options|
    log_step("Environment Setup", "Preparing deployment environment") do
      
      # Ensure app directory exists and is accessible
      app_dir = options[:app_dir]
      ensure_directory_exists(app_dir)
      
      # Validate Xcode project
      project_info = find_xcode_project(app_dir)
      log_success("Xcode project found", 
                 type: project_info[:type],
                 project: File.basename(project_info[:path]))
      
      # Setup certificates and profiles directories
      setup_apple_info_structure(options)
    end
  end
  
  # Setup Apple API authentication using modular system
  private_lane :setup_api_authentication do |options|
    log_step("API Authentication", "Setting up Apple API authentication") do
      
      api_manager = create_api_manager(options)
      api_manager.authenticate
      
      # Test connection
      unless api_manager.test_connection
        raise ErrorHandler::APIError.new(
          "API connection test failed",
          error_code: 'API_CONNECTION_FAILED'
        )
      end
      
      log_success("API authentication completed successfully")
      api_manager
    end
  end
  
  # Setup provisioning profiles (placeholder using legacy system for now)
  private_lane :setup_provisioning_profiles do |options|
    log_step("Profile Management", "Setting up provisioning profiles") do
      
      # For now, use simplified profile setup
      # This will be replaced with modular profile management
      profiles_dir = File.join(options[:app_dir], 'apple_info', 'profiles')
      
      if File.directory?(profiles_dir)
        profile_files = Dir.glob("#{profiles_dir}/*.mobileprovision")
        
        profile_files.each do |profile_file|
          destination = File.expand_path("~/Library/MobileDevice/Provisioning Profiles/#{File.basename(profile_file)}")
          FileUtils.copy_file(profile_file, destination)
          log_info("Installed profile", file: File.basename(profile_file))
        end
        
        log_success("Provisioning profiles installed", count: profile_files.length)
      else
        log_warn("No profiles directory found, profiles may be created automatically")
      end
    end
  end
  
  # Handle version management
  private_lane :handle_version_management do |options|
    log_step("Version Management", "Managing application version") do
      
      version_bump = options[:version_bump]
      
      if version_bump && version_bump != "none"
        log_info("Version increment requested", type: version_bump)
        
        case version_bump
        when "patch"
          increment_version_number(bump_type: "patch")
        when "minor" 
          increment_version_number(bump_type: "minor")
        when "major"
          increment_version_number(bump_type: "major")
        end
        
        final_version = get_version_number
        log_success("Version updated", version: final_version)
        
        { final_version: final_version, increment_type: version_bump }
      else
        current_version = get_version_number
        log_info("No version increment requested", current_version: current_version)
        
        { final_version: current_version, increment_type: "none" }
      end
    end
  end
  
  # Build and archive application
  private_lane :build_and_archive_app do |options|
    log_step("Build & Archive", "Building and archiving application") do
      
      # Build the app
      build_app(
        scheme: options[:scheme],
        configuration: options[:configuration] || "Release",
        export_method: "app-store",
        export_options: {
          provisioningProfiles: {
            options[:app_identifier] => "#{options[:app_identifier]} AppStore"
          }
        }
      )
      
      # Get the IPA path
      ipa_path = lane_context[SharedValues::IPA_OUTPUT_PATH]
      
      unless ipa_path && File.exist?(ipa_path)
        raise ErrorHandler::BuildError.new(
          "IPA file not found after build",
          error_code: 'IPA_NOT_FOUND'
        )
      end
      
      log_success("Build completed successfully",
                 ipa_path: ipa_path,
                 ipa_size: "#{(File.size(ipa_path) / 1024.0 / 1024.0).round(1)}MB")
      
      ipa_path
    end
  end
  
  # Secure TestFlight upload with comprehensive error handling
  private_lane :upload_to_testflight_secure do |ipa_path, api_manager, options|
    log_step("TestFlight Upload", "Uploading to TestFlight with retry logic") do
      
      api_manager.with_api_retry("TestFlight Upload") do
        
        # Upload using deliver
        deliver(
          ipa: ipa_path,
          skip_screenshots: true,
          skip_metadata: true,
          skip_app_version_update: true,
          force: true,
          api_key_path: options[:api_key_path],
          api_key_id: options[:api_key_id],
          api_issuer_id: options[:api_issuer_id]
        )
        
        log_success("TestFlight upload completed successfully")
        
        # Log to audit trail
        log_upload_success(options[:app_identifier], File.basename(ipa_path))
        
        { success: true, ipa_file: File.basename(ipa_path) }
      end
    end
  end
  
  # Setup apple_info directory structure
  private_lane :setup_apple_info_structure do |options|
    app_dir = options[:app_dir]
    apple_info_dir = File.join(app_dir, 'apple_info')
    
    if File.directory?(apple_info_dir)
      log_info("Using existing apple_info directory structure")
      
      # Ensure subdirectories exist
      ['certificates', 'profiles'].each do |subdir|
        subdir_path = File.join(apple_info_dir, subdir)
        ensure_directory_exists(subdir_path)
      end
    else
      log_info("No apple_info directory found, using standard FastLane structure")
    end
  end
  
  # Log successful upload to audit trail
  private_lane :log_upload_success do |app_identifier, ipa_filename|
    begin
      log_file = File.join(Dir.pwd, 'apple_info', 'certificates', 'testflight_uploads.log')
      ensure_directory_exists(File.dirname(log_file))
      
      File.open(log_file, 'a') do |f|
        f.puts "#{Time.now.strftime('%Y-%m-%dT%H:%M:%S%z')}: SUCCESS - #{ipa_filename} uploaded to TestFlight for #{app_identifier}"
      end
      
      log_info("Upload logged to audit trail", log_file: log_file)
    rescue => e
      log_warn("Failed to write to audit log", error: e.message)
    end
  end
  
  # Error handling lane
  error do |lane, exception|
    FastlaneLogger.error("Lane failed: #{lane}", 
                        error: exception.message,
                        error_class: exception.class.name)
    
    # Handle specific error types
    case exception
    when ErrorHandler::DeploymentError
      FastlaneLogger.error("Deployment error details",
                          error_code: exception.error_code,
                          recovery_suggestions: exception.recovery_suggestions)
    else
      FastlaneLogger.error("Unexpected error occurred", 
                          backtrace: exception.backtrace&.first(5))
    end
  end
end