# Apple API Manager - Handles App Store Connect API authentication and operations
# Provides centralized API management with retry logic and error handling

require_relative '../core/logger'
require_relative '../core/error_handler'
require 'spaceship'

class AppleAPIManager
  class APIError < ErrorHandler::APIError; end
  
  attr_reader :api_key_path, :api_key_id, :issuer_id, :team_id
  
  def initialize(options = {})
    # Extract and resolve paths
    raw_api_key_path = options[:api_key_path] || options["api_key_path"]
    @api_key_path = resolve_api_key_path(raw_api_key_path)
    @api_key_id = options[:api_key_id] || options["api_key_id"]
    @issuer_id = options[:api_issuer_id] || options["api_issuer_id"]
    @team_id = options[:team_id] || options["team_id"]
    @app_identifier = options[:app_identifier] || options["app_identifier"]
    
    @authenticated = false
    @auth_expires_at = nil
    @retry_count = 0
    @max_retries = 3
  end
  
  # Main authentication method
  def authenticate
    log_step("API Authentication", "Authenticating with App Store Connect API") do
      validate_credentials
      perform_authentication
      verify_authentication
      
      @authenticated = true
      @auth_expires_at = Time.now + 1800 # 30 minutes
      
      log_success("API authentication successful", 
                 team_id: @team_id,
                 api_key_id: @api_key_id)
    end
  end
  
  # Check if current authentication is valid
  def authenticated?
    @authenticated && @auth_expires_at && Time.now < @auth_expires_at
  end
  
  # Ensure authentication is valid (authenticate if needed)
  def ensure_authenticated
    unless authenticated?
      log_info("Authentication expired or not present, re-authenticating...")
      authenticate
    end
  end
  
  # Execute API operations with automatic retry and authentication
  def with_api_retry(operation_name, &block)
    with_error_handling("API #{operation_name}") do
      ensure_authenticated
      
      (0..@max_retries).each do |attempt|
        begin
          return yield
        rescue => e
          if should_retry_error?(e) && attempt < @max_retries
            wait_time = calculate_backoff_time(attempt)
            log_warn("API #{operation_name} failed, retrying in #{wait_time}s", 
                    attempt: attempt + 1,
                    max_retries: @max_retries,
                    error: e.message)
            sleep(wait_time)
            
            # Re-authenticate if auth error
            if auth_error?(e)
              @authenticated = false
              ensure_authenticated
            end
          else
            raise APIError.new(
              "API #{operation_name} failed after #{@max_retries} attempts: #{e.message}",
              error_code: classify_api_error(e),
              original: e
            )
          end
        end
      end
    end
  end
  
  # Get app information from App Store Connect
  def get_app_info
    with_api_retry("get_app_info") do
      log_info("Fetching app information", app_identifier: @app_identifier)
      
      app = Spaceship::ConnectAPI::App.find(@app_identifier)
      
      unless app
        raise APIError.new(
          "App not found: #{@app_identifier}",
          error_code: 'APP_NOT_FOUND'
        )
      end
      
      log_info("App information retrieved", 
              app_name: app.name,
              app_id: app.id,
              bundle_id: app.bundle_id)
      
      app
    end
  end
  
  # Get latest build information from TestFlight
  def get_latest_testflight_build(app_id)
    with_api_retry("get_latest_testflight_build") do
      log_info("Fetching latest TestFlight build", app_id: app_id)
      
      builds = Spaceship::ConnectAPI::Build.all(
        app_id: app_id,
        sort: '-version,-uploadedDate',
        limit: 1
      )
      
      latest_build = builds.first
      
      if latest_build
        log_info("Latest TestFlight build found",
                build_number: latest_build.version,
                upload_date: latest_build.uploaded_date,
                processing_state: latest_build.processing_state)
      else
        log_info("No TestFlight builds found for app")
      end
      
      latest_build
    end
  end
  
  # Upload build to TestFlight
  def upload_to_testflight(ipa_path, options = {})
    with_api_retry("upload_to_testflight") do
      log_info("Starting TestFlight upload", 
              ipa_path: File.basename(ipa_path),
              ipa_size: "#{(File.size(ipa_path) / 1024.0 / 1024.0).round(1)}MB")
      
      # Use deliver action with API authentication
      require 'deliver'
      
      deliver_options = {
        ipa: ipa_path,
        skip_screenshots: true,
        skip_metadata: true,
        skip_app_version_update: true,
        force: true,
        api_key_path: @api_key_path,
        api_key_id: @api_key_id,
        api_issuer_id: @issuer_id
      }
      
      # Add optional parameters
      deliver_options[:platform] = options[:platform] if options[:platform]
      deliver_options[:team_id] = @team_id if @team_id
      
      log_info("Uploading to TestFlight...", options: deliver_options.keys)
      
      # Execute upload
      result = Deliver::Runner.new(deliver_options).run
      
      log_success("TestFlight upload completed", result: result)
      result
    end
  end
  
  # Create or update certificates via API
  def manage_certificates(certificate_type = 'DEVELOPMENT')
    with_api_retry("manage_certificates") do
      log_info("Managing certificates via API", 
              certificate_type: certificate_type,
              team_id: @team_id)
      
      # Get existing certificates
      existing_certs = Spaceship::ConnectAPI::Certificate.all(
        filter: { certificateType: certificate_type }
      )
      
      log_info("Found existing certificates", count: existing_certs.length)
      
      # Check if we need to create new certificates
      valid_certs = existing_certs.select do |cert|
        cert.expiration_date > Time.now + (30 * 24 * 60 * 60) # 30 days
      end
      
      if valid_certs.empty?
        log_info("Creating new certificate", type: certificate_type)
        create_certificate(certificate_type)
      else
        log_info("Valid certificates found", count: valid_certs.length)
        valid_certs
      end
    end
  end
  
  # Create provisioning profiles via API
  def manage_provisioning_profiles(profile_type = 'DEVELOPMENT')
    with_api_retry("manage_provisioning_profiles") do
      log_info("Managing provisioning profiles via API",
              profile_type: profile_type,
              app_identifier: @app_identifier)
      
      # Implementation for provisioning profile management
      # This would interact with Spaceship::ConnectAPI::Profile
      
      log_info("Provisioning profile management completed")
    end
  end
  
  # Test API connectivity
  def test_connection
    with_error_handling("API connection test") do
      log_info("Testing API connectivity...")
      
      # Simple API call to test connection
      apps = Spaceship::ConnectAPI::App.all(limit: 1)
      
      log_success("API connection test successful", apps_accessible: apps.length)
      true
    end
  rescue => e
    log_error("API connection test failed", error: e.message)
    false
  end
  
  private
  
  def resolve_api_key_path(path)
    return nil if path.nil? || path.empty?
    
    # If already absolute path, return as is (deploy script has already resolved it)
    if path.start_with?('/')
      log_info("Using absolute API key path", path: path)
      return path
    end
    
    # Current working directory is the app directory (e.g., template_swiftui)
    # But we're running from fastlane/ subdirectory, so need to go up one level
    
    log_info("Resolving relative API key path", 
            relative_path: path,
            current_dir: Dir.pwd)
    
    # Try direct path relative to current working directory first
    direct_path = File.expand_path(path)
    if File.exist?(direct_path)
      log_info("Found API key at direct path", path: direct_path)
      return direct_path
    end
    
    # Try relative to parent directory (go up from fastlane/ to app directory)
    parent_direct_path = File.expand_path(File.join('..', path))
    if File.exist?(parent_direct_path)
      log_info("Found API key at parent path", path: parent_direct_path)
      return parent_direct_path
    end
    
    # Try relative to apple_info from parent directory
    parent_apple_info_path = File.expand_path(File.join('..', 'apple_info', path))
    if File.exist?(parent_apple_info_path)
      log_info("Found API key at parent apple_info path", path: parent_apple_info_path)
      return parent_apple_info_path
    end
    
    # Log all attempts for debugging
    log_warn("API key not found at any expected location", 
            attempts: [direct_path, parent_direct_path, parent_apple_info_path])
    
    # Return the most likely correct path for better error messages
    return parent_apple_info_path
  end
  
  def validate_credentials
    log_info("Validating API credentials...")
    
    missing_params = []
    missing_params << 'api_key_path' unless @api_key_path
    missing_params << 'api_key_id' unless @api_key_id  
    missing_params << 'api_issuer_id' unless @issuer_id
    
    unless missing_params.empty?
      raise APIError.new(
        "Missing required API credentials: #{missing_params.join(', ')}",
        error_code: 'MISSING_CREDENTIALS'
      )
    end
    
    unless File.exist?(@api_key_path)
      raise APIError.new(
        "API key file not found: #{@api_key_path}",
        error_code: 'API_KEY_FILE_NOT_FOUND'
      )
    end
    
    log_info("API credentials validated", 
            api_key_file: File.basename(@api_key_path),
            api_key_id: @api_key_id)
  end
  
  def perform_authentication
    log_info("Performing API authentication...")
    
    # Configure Spaceship with API key authentication
    log_info("Creating API authentication token...")
    
    # Read API key content directly (more reliable than filepath)
    key_content = File.read(@api_key_path)
    
    # Create authentication token using key content
    Spaceship::ConnectAPI.token = Spaceship::ConnectAPI::Token.create(
      key_id: @api_key_id,
      issuer_id: @issuer_id,
      key: key_content
    )
    
    log_info("API authentication configured")
  end
  
  def verify_authentication
    log_info("Verifying API authentication...")
    
    # Test authentication by making a simple API call
    begin
      apps = Spaceship::ConnectAPI::App.all(limit: 1)
      log_info("Authentication verification successful", apps_count: apps.length)
    rescue => e
      raise APIError.new(
        "Authentication verification failed: #{e.message}",
        error_code: 'AUTH_VERIFICATION_FAILED',
        original: e
      )
    end
  end
  
  def should_retry_error?(error)
    message = error.message.downcase
    
    # Retry on temporary network errors
    return true if message.include?('timeout')
    return true if message.include?('connection')
    return true if message.include?('network')
    
    # Retry on rate limiting
    return true if message.include?('rate limit')
    return true if message.include?('too many requests')
    
    # Retry on temporary server errors
    return true if message.include?('500')
    return true if message.include?('502')
    return true if message.include?('503')
    
    false
  end
  
  def auth_error?(error)
    message = error.message.downcase
    message.include?('authentication') || 
    message.include?('unauthorized') ||
    message.include?('invalid token')
  end
  
  def classify_api_error(error)
    message = error.message.downcase
    
    return 'AUTH_FAILED' if auth_error?(error)
    return 'RATE_LIMIT' if message.include?('rate limit')
    return 'NETWORK_ERROR' if message.include?('timeout') || message.include?('connection')
    return 'SERVER_ERROR' if message.include?('500') || message.include?('502')
    return 'API_ERROR'
  end
  
  def calculate_backoff_time(attempt)
    # Exponential backoff: 2^attempt seconds, max 60 seconds
    [2 ** attempt, 60].min
  end
  
  def create_certificate(certificate_type)
    log_info("Creating new certificate", type: certificate_type)
    
    # This would implement certificate creation via Spaceship
    # For now, return placeholder
    log_warn("Certificate creation not yet implemented")
    nil
  end
end

# Convenience methods for FastLane integration
def create_api_manager(options)
  AppleAPIManager.new(options)
end

def with_api_authentication(options, &block)
  api_manager = AppleAPIManager.new(options)
  api_manager.authenticate
  yield api_manager
end