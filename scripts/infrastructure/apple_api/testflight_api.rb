# TestFlight API Adapter - Infrastructure Layer
# Abstraction for App Store Connect TestFlight operations

require_relative '../../fastlane/modules/core/logger'

class TestFlightAPI
  def initialize(logger: FastlaneLogger)
    @logger = logger
  end
  
  # Connect to App Store Connect API
  # @param api_key [Hash] API key configuration (key_id, issuer_id, key_filepath)
  # @return [Hash] Connection result
  def connect(api_key:)
    @logger.info("Connecting to App Store Connect API...")
    
    begin
      require 'spaceship'
      
      # Set up the API connection using the provided key
      Spaceship::ConnectAPI.token = api_key
      
      {
        success: true,
        connected_at: Time.now,
        api_key_id: api_key[:key_id]
      }
      
    rescue => error
      @logger.error("App Store Connect API connection failed: #{error.message}")
      {
        success: false,
        error: error.message,
        error_type: :api_connection_failed
      }
    end
  end
  
  # Find app by identifier
  # @param app_identifier [String] App bundle identifier
  # @return [Hash] App search result
  def find_app(app_identifier:)
    @logger.info("Finding app with identifier: #{app_identifier}")
    
    begin
      app = Spaceship::ConnectAPI::App.find(app_identifier)
      
      if app.nil?
        {
          success: true,
          found: false,
          app_identifier: app_identifier
        }
      else
        {
          success: true,
          found: true,
          app_identifier: app_identifier,
          app_name: app.name,
          app_id: app.id,
          app: app  # Include the actual app object for further operations
        }
      end
      
    rescue => error
      @logger.error("App search failed: #{error.message}")
      {
        success: false,
        error: error.message,
        error_type: :app_search_failed
      }
    end
  end
  
  # Get recent builds for an app
  # @param app [Object] Spaceship App object
  # @param limit [Integer] Number of builds to retrieve (default: 5)
  # @return [Hash] Builds retrieval result
  def get_recent_builds(app:, limit: 5)
    @logger.info("Retrieving recent builds (limit: #{limit})")
    
    begin
      builds = app.get_builds(
        sort: "version,-uploadedDate",
        limit: limit
      )
      
      builds_info = builds.map do |build|
        {
          id: build.id,
          version: build.version,
          build_version: build.build_version,
          processing_state: build.processing_state,
          uploaded_date: build.uploaded_date,
          build_object: build  # Include actual build object for operations
        }
      end
      
      {
        success: true,
        builds: builds_info,
        count: builds.size,
        retrieved_at: Time.now
      }
      
    rescue => error
      @logger.error("Builds retrieval failed: #{error.message}")
      {
        success: false,
        error: error.message,
        error_type: :builds_retrieval_failed
      }
    end
  end
  
  # Get latest build for an app
  # @param app [Object] Spaceship App object
  # @return [Hash] Latest build result
  def get_latest_build(app:)
    @logger.info("Retrieving latest build")
    
    begin
      builds = app.get_builds(sort: "version,-uploadedDate", limit: 1)
      
      if builds.empty?
        {
          success: true,
          found: false,
          app_name: app.name
        }
      else
        latest_build = builds.first
        {
          success: true,
          found: true,
          build: {
            id: latest_build.id,
            version: latest_build.version,
            build_version: latest_build.build_version,
            processing_state: latest_build.processing_state,
            uploaded_date: latest_build.uploaded_date,
            build_object: latest_build
          },
          retrieved_at: Time.now
        }
      end
      
    rescue => error
      @logger.error("Latest build retrieval failed: #{error.message}")
      {
        success: false,
        error: error.message,
        error_type: :latest_build_retrieval_failed
      }
    end
  end
  
  # Monitor build processing status with polling
  # @param app [Object] Spaceship App object
  # @param initial_build [Object] Initial build object to monitor
  # @param max_wait_time [Integer] Maximum time to wait in seconds (default: 300)
  # @param poll_interval [Integer] Polling interval in seconds (default: 30)
  # @return [Hash] Monitoring result
  def monitor_build_processing(app:, initial_build:, max_wait_time: 300, poll_interval: 30)
    @logger.info("Monitoring build processing: #{initial_build.version} (#{initial_build.build_version})")
    
    begin
      current_build = initial_build
      elapsed_time = 0
      
      # Only monitor if build is currently processing
      if current_build.processing_state != "PROCESSING"
        return {
          success: true,
          monitoring_needed: false,
          final_build: {
            id: current_build.id,
            version: current_build.version,
            build_version: current_build.build_version,
            processing_state: current_build.processing_state,
            uploaded_date: current_build.uploaded_date
          },
          elapsed_time: 0
        }
      end
      
      @logger.info("Build is processing, starting monitoring loop...")
      
      # Polling loop
      while elapsed_time < max_wait_time
        sleep(poll_interval)
        elapsed_time += poll_interval
        
        # Refresh build status
        latest_result = get_latest_build(app: app)
        
        if !latest_result[:success] || !latest_result[:found]
          @logger.warn("Could not refresh build status at #{elapsed_time}s")
          next
        end
        
        current_build_info = latest_result[:build]
        @logger.info("Status check (#{elapsed_time}s): #{current_build_info[:processing_state]}")
        
        # Check if processing completed
        if current_build_info[:processing_state] != "PROCESSING"
          @logger.info("Build processing completed: #{current_build_info[:processing_state]}")
          break
        end
      end
      
      # Get final build state
      final_result = get_latest_build(app: app)
      final_build = final_result[:success] && final_result[:found] ? final_result[:build] : nil
      
      {
        success: true,
        monitoring_needed: true,
        final_build: final_build,
        elapsed_time: elapsed_time,
        processing_completed: final_build ? final_build[:processing_state] != "PROCESSING" : false,
        monitored_at: Time.now
      }
      
    rescue => error
      @logger.error("Build monitoring failed: #{error.message}")
      {
        success: false,
        error: error.message,
        error_type: :build_monitoring_failed
      }
    end
  end
  
  # Upload IPA to TestFlight using pilot
  # @param ipa_path [String] Path to IPA file
  # @param team_id [String] Apple Developer Team ID
  # @param username [String] Apple ID username
  # @param skip_waiting_for_build_processing [Boolean] Skip waiting for processing
  # @return [Hash] Upload result
  def upload_build(ipa_path:, team_id:, username:, skip_waiting_for_build_processing: true)
    @logger.info("Uploading build to TestFlight: #{File.basename(ipa_path)}")
    
    begin
      # Call FastLane's pilot action to upload to TestFlight
      result = pilot(
        ipa: ipa_path,
        team_id: team_id,
        username: username,
        skip_waiting_for_build_processing: skip_waiting_for_build_processing
      )
      
      {
        success: true,
        ipa_path: ipa_path,
        team_id: team_id,
        uploaded_at: Time.now,
        pilot_result: result
      }
      
    rescue => error
      @logger.error("TestFlight upload failed: #{error.message}")
      {
        success: false,
        error: error.message,
        error_type: :testflight_upload_failed
      }
    end
  end
  
  # Upload using xcrun altool (alternative method)
  # @param ipa_path [String] Path to IPA file
  # @param api_key_path [String] Path to API key file
  # @param api_key_id [String] API Key ID
  # @param api_issuer_id [String] API Issuer ID
  # @return [Hash] Upload result
  def upload_with_altool(ipa_path:, api_key_path:, api_key_id:, api_issuer_id:)
    @logger.info("Uploading build using xcrun altool: #{File.basename(ipa_path)}")
    
    begin
      # Copy API key to expected location for xcrun altool
      private_keys_dir = File.expand_path("~/.appstoreconnect/private_keys")
      FileUtils.mkdir_p(private_keys_dir)
      api_key_filename = File.basename(api_key_path)
      destination_key_path = File.join(private_keys_dir, api_key_filename)
      FileUtils.copy(api_key_path, destination_key_path)
      
      begin
        # Upload using xcrun altool
        upload_command = [
          "xcrun altool",
          "--upload-app",
          "--type ios",
          "--file \"#{ipa_path}\"",
          "--apiKey #{api_key_id}",
          "--apiIssuer #{api_issuer_id}"
        ].join(" ")
        
        @logger.info("Executing upload command...")
        result = system(upload_command)
        
        if result
          {
            success: true,
            ipa_path: ipa_path,
            method: :altool,
            uploaded_at: Time.now
          }
        else
          {
            success: false,
            error: "xcrun altool upload command failed",
            error_type: :altool_upload_failed
          }
        end
        
      ensure
        # Clean up the copied API key
        File.delete(destination_key_path) if File.exist?(destination_key_path)
      end
      
    rescue => error
      @logger.error("xcrun altool upload failed: #{error.message}")
      {
        success: false,
        error: error.message,
        error_type: :altool_upload_exception
      }
    end
  end
  
  # Create audit log entry for build upload
  # @param app_identifier [String] App bundle identifier
  # @param build_info [Hash] Build information
  # @param log_directory [String] Directory to write log file (default: current directory)
  # @return [Hash] Logging result
  def create_audit_log(app_identifier:, build_info:, log_directory: Dir.pwd)
    @logger.info("Creating audit log entry")
    
    begin
      timestamp = Time.now.strftime('%Y-%m-%dT%H:%M:%S%z')
      
      # Create log entry
      log_entry = {
        timestamp: timestamp,
        app_identifier: app_identifier,
        version: build_info[:version],
        build_number: build_info[:build_version] || build_info[:build_number],
        processing_state: build_info[:processing_state],
        upload_date: build_info[:uploaded_date],
        testflight_enhanced: true
      }
      
      # Write to log file
      log_file = File.join(log_directory, 'apple_info', 'testflight_enhanced.log')
      FileUtils.mkdir_p(File.dirname(log_file))
      
      File.open(log_file, 'a') do |f|
        f.puts "#{timestamp}: ENHANCED_UPLOAD - #{app_identifier} v#{log_entry[:version]} (#{log_entry[:build_number]}) - #{log_entry[:processing_state]}"
      end
      
      {
        success: true,
        log_file: log_file,
        log_entry: log_entry,
        logged_at: Time.now
      }
      
    rescue => error
      @logger.error("Audit logging failed: #{error.message}")
      {
        success: false,
        error: error.message,
        error_type: :audit_logging_failed
      }
    end
  end
  
  # Get build processing status icon
  # @param processing_state [String] Build processing state
  # @return [String] Status icon
  def get_status_icon(processing_state)
    case processing_state
    when "PROCESSING" then "🔄"
    when "VALID" then "✅"
    when "INVALID" then "❌"
    else "❓"
    end
  end
end