# Monitor TestFlight Processing Use Case - Clean Architecture Domain Layer
# Business workflow: Monitor and report TestFlight build processing status

require_relative '../../fastlane/modules/core/logger'
require_relative '../../infrastructure/apple_api/testflight_api'

class MonitorTestFlightProcessingRequest
  attr_reader :app_identifier, :api_key, :enhanced_mode, :max_wait_time, :poll_interval
  
  def initialize(app_identifier:, api_key:, enhanced_mode: true, max_wait_time: 300, poll_interval: 30)
    @app_identifier = app_identifier
    @api_key = api_key
    @enhanced_mode = enhanced_mode
    @max_wait_time = max_wait_time
    @poll_interval = poll_interval
    
    validate_request
  end
  
  private
  
  def validate_request
    raise ArgumentError, "app_identifier cannot be nil or empty" if @app_identifier.nil? || @app_identifier.empty?
    raise ArgumentError, "api_key cannot be nil" if @api_key.nil?
    raise ArgumentError, "max_wait_time must be positive" if @max_wait_time <= 0
    raise ArgumentError, "poll_interval must be positive" if @poll_interval <= 0
  end
end

class MonitorTestFlightProcessingResult
  attr_reader :success, :app_name, :builds, :latest_build, :processing_completed, :final_status, 
              :wait_time_elapsed, :error, :error_type, :recovery_suggestion, :audit_log_created
  
  def initialize(success:, app_name: nil, builds: [], latest_build: nil, processing_completed: false, 
                 final_status: nil, wait_time_elapsed: 0, error: nil, error_type: nil, 
                 recovery_suggestion: nil, audit_log_created: false)
    @success = success
    @app_name = app_name
    @builds = builds
    @latest_build = latest_build
    @processing_completed = processing_completed
    @final_status = final_status
    @wait_time_elapsed = wait_time_elapsed
    @error = error
    @error_type = error_type
    @recovery_suggestion = recovery_suggestion
    @audit_log_created = audit_log_created
  end
  
  def build_ready_for_testing?
    @final_status == "VALID"
  end
  
  def build_processing_failed?
    @final_status == "INVALID"
  end
  
  def still_processing?
    @final_status == "PROCESSING"
  end
end

class MonitorTestFlightProcessing
  def initialize(logger: FastlaneLogger, testflight_api: nil)
    @logger = logger
    @testflight_api = testflight_api || TestFlightAPI.new(logger: logger)
  end
  
  # Execute the use case to monitor TestFlight build processing
  # @param request [MonitorTestFlightProcessingRequest] Input parameters
  # @return [MonitorTestFlightProcessingResult] Result with processing status and build information
  def execute(request)
    @logger.header("🔍 TestFlight Status Check")
    
    return create_disabled_result unless request.enhanced_mode
    
    begin
      # Business Logic: Connect to App Store Connect API
      app = connect_to_app_store_api(request)
      return create_app_not_found_result unless app
      
      @logger.info("📱 Found app: #{app.name}")
      
      # Business Logic: Retrieve recent builds
      builds = retrieve_recent_builds(app)
      return create_no_builds_result if builds.empty?
      
      # Business Logic: Display build status overview
      display_builds_overview(builds)
      
      # Business Logic: Monitor latest build processing
      latest_build = builds.first
      processing_result = monitor_build_processing(app, latest_build, request)
      
      # Business Logic: Create audit trail
      audit_success = create_audit_trail(request.app_identifier, processing_result[:final_build])
      
      MonitorTestFlightProcessingResult.new(
        success: true,
        app_name: app.name,
        builds: builds,
        latest_build: processing_result[:final_build],
        processing_completed: processing_result[:completed],
        final_status: processing_result[:final_status],
        wait_time_elapsed: processing_result[:elapsed_time],
        audit_log_created: audit_success
      )
      
    rescue TestFlightMonitoringError => e
      @logger.error("TestFlight monitoring failed: #{e.message}")
      MonitorTestFlightProcessingResult.new(
        success: false,
        error: e.message,
        error_type: :monitoring_failed,
        recovery_suggestion: "Check App Store Connect API connectivity and permissions"
      )
      
    rescue => e
      @logger.error("Unexpected error during TestFlight monitoring: #{e.message}")
      MonitorTestFlightProcessingResult.new(
        success: false,
        error: e.message,
        error_type: :unexpected_error,
        recovery_suggestion: "Upload was successful, but status polling is unavailable"
      )
    end
  end
  
  private
  
  def create_disabled_result
    @logger.info("Enhanced mode disabled - skipping TestFlight status check")
    MonitorTestFlightProcessingResult.new(
      success: true,
      processing_completed: false,
      final_status: "DISABLED"
    )
  end
  
  def create_app_not_found_result
    MonitorTestFlightProcessingResult.new(
      success: false,
      error: "App not found with provided identifier",
      error_type: :app_not_found,
      recovery_suggestion: "Verify app identifier is correct and app exists in App Store Connect"
    )
  end
  
  def create_no_builds_result
    MonitorTestFlightProcessingResult.new(
      success: true,
      builds: [],
      processing_completed: false,
      final_status: "NO_BUILDS"
    )
  end
  
  def connect_to_app_store_api(request)
    begin
      # Import required modules for TestFlight API access
      require 'spaceship'
      
      # Set up the API connection using the provided key
      Spaceship::ConnectAPI.token = request.api_key
      
      @logger.info("🌐 Connecting to App Store Connect API...")
      
      # Find the app
      app = Spaceship::ConnectAPI::App.find(request.app_identifier)
      if app.nil?
        @logger.warn("⚠️  App not found with identifier: #{request.app_identifier}")
        return nil
      end
      
      app
      
    rescue => e
      @logger.error("Failed to connect to App Store Connect API: #{e.message}")
      raise TestFlightMonitoringError.new("API connection failed: #{e.message}")
    end
  end
  
  def retrieve_recent_builds(app)
    begin
      # Get recent builds
      builds = app.get_builds(
        sort: "version,-uploadedDate",
        limit: 5
      )
      
      if builds.empty?
        @logger.info("📦 No recent builds found")
      end
      
      builds
      
    rescue => e
      @logger.error("Failed to retrieve builds: #{e.message}")
      raise TestFlightMonitoringError.new("Build retrieval failed: #{e.message}")
    end
  end
  
  def display_builds_overview(builds)
    @logger.info("📊 Recent TestFlight Builds:")
    builds.each_with_index do |build, index|
      status_icon = get_status_icon(build.processing_state)
      @logger.info("   #{index + 1}. #{status_icon} Version #{build.version} (#{build.build_version}) - #{build.processing_state}")
    end
  end
  
  def get_status_icon(processing_state)
    case processing_state
    when "PROCESSING" then "🔄"
    when "VALID" then "✅"
    when "INVALID" then "❌"
    else "❓"
    end
  end
  
  def monitor_build_processing(app, latest_build, request)
    @logger.info("🎯 Latest Build Status: #{latest_build.processing_state}")
    
    # Enhanced confirmation: Wait for processing to complete
    if latest_build.processing_state == "PROCESSING"
      @logger.info("⏳ Build is still processing, waiting for completion...")
      
      elapsed_time = 0
      final_build = latest_build
      
      while elapsed_time < request.max_wait_time
        sleep(request.poll_interval)
        elapsed_time += request.poll_interval
        
        # Refresh build status
        final_build = app.get_builds(sort: "version,-uploadedDate", limit: 1).first
        
        @logger.info("🔄 Status check (#{elapsed_time}s): #{final_build.processing_state}")
        
        if final_build.processing_state != "PROCESSING"
          break
        end
      end
      
      # Report final status
      report_final_processing_status(final_build, elapsed_time)
      
      {
        final_build: final_build,
        completed: final_build.processing_state != "PROCESSING",
        final_status: final_build.processing_state,
        elapsed_time: elapsed_time
      }
    else
      @logger.info("📋 Build processing status: #{latest_build.processing_state}")
      
      {
        final_build: latest_build,
        completed: true,
        final_status: latest_build.processing_state,
        elapsed_time: 0
      }
    end
  end
  
  def report_final_processing_status(build, elapsed_time)
    case build.processing_state
    when "VALID"
      @logger.success("✅ TestFlight Build Processing Complete!")
      @logger.info("🎉 Build is ready for testing")
      @logger.info("📱 Version: #{build.version} (#{build.build_version})")
    when "INVALID"
      @logger.error("❌ Build processing failed")
      @logger.info("💡 Check App Store Connect for details")
    else
      @logger.info("⏱️  Build is still processing after #{elapsed_time} seconds")
      @logger.info("💭 Check TestFlight in a few minutes for final status")
    end
  end
  
  def create_audit_trail(app_identifier, build)
    return false unless build
    
    begin
      timestamp = Time.now.strftime('%Y-%m-%dT%H:%M:%S%z')
      
      # Create enhanced log entry
      log_entry = {
        timestamp: timestamp,
        app_identifier: app_identifier,
        version: build.version,
        build_number: build.build_version,
        processing_state: build.processing_state,
        upload_date: build.uploaded_date,
        testflight_enhanced: true
      }
      
      @logger.info("📝 Enhanced Audit Trail:")
      @logger.info("   - Timestamp: #{log_entry[:timestamp]}")
      @logger.info("   - App: #{log_entry[:app_identifier]}")
      @logger.info("   - Version: #{log_entry[:version]} (#{log_entry[:build_number]})")
      @logger.info("   - Status: #{log_entry[:processing_state]}")
      
      # Try to write to log file
      write_audit_log(timestamp, log_entry)
      
      true
      
    rescue => error
      @logger.warn("⚠️  Enhanced logging failed: #{error.message}")
      false
    end
  end
  
  def write_audit_log(timestamp, log_entry)
    begin
      log_file = File.join(Dir.pwd, 'apple_info', 'testflight_enhanced.log')
      FileUtils.mkdir_p(File.dirname(log_file))
      
      File.open(log_file, 'a') do |f|
        f.puts "#{timestamp}: ENHANCED_UPLOAD - #{log_entry[:app_identifier]} v#{log_entry[:version]} (#{log_entry[:build_number]}) - #{log_entry[:processing_state]}"
      end
      
      @logger.info("📄 Logged to: #{log_file}")
      
    rescue => log_error
      @logger.warn("⚠️  Could not write to log file: #{log_error.message}")
      raise log_error
    end
  end
end

# Custom exception for TestFlight monitoring operations
class TestFlightMonitoringError < StandardError; end