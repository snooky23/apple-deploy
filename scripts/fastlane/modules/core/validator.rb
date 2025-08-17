# Comprehensive Parameter and Environment Validation System
# Ensures all required parameters are present and valid before operations begin

require_relative 'logger'

class ParameterValidator
  class ValidationError < StandardError
    attr_reader :field, :value, :reason
    
    def initialize(field, value, reason)
      @field = field
      @value = value
      @reason = reason
      super("Validation failed for #{field}: #{reason}")
    end
  end
  
  # Required parameters for different operations
  REQUIRED_PARAMS = {
    basic: [:app_identifier, :team_id, :api_key_id, :api_issuer_id, :api_key_path],
    build: [:scheme, :configuration],
    upload: [:apple_id],
    team: [:p12_password]
  }.freeze
  
  # Parameter format validators
  VALIDATORS = {
    app_identifier: ->(val) { val.match?(/^[a-zA-Z0-9\.-]+\.[a-zA-Z0-9\.-]+$/) },
    team_id: ->(val) { val.match?(/^[A-Z0-9]{10}$/) },
    api_key_id: ->(val) { val.match?(/^[A-Z0-9]{10}$/) },
    api_issuer_id: ->(val) { val.match?(/^[a-f0-9\-]{36}$/) },
    scheme: ->(val) { val.is_a?(String) && !val.empty? },
    configuration: ->(val) { %w[Debug Release].include?(val) },
    version_bump: ->(val) { %w[major minor patch].include?(val) }
  }.freeze
  
  class << self
    # Validate all required parameters for a given operation
    def validate_all(options, operation_type = :basic)
      log_step("Parameter Validation", "Validating #{operation_type} parameters") do
        
        # Get required parameters for this operation
        required_params = get_required_params(operation_type)
        
        # Validate presence and format
        validate_required_presence(options, required_params)
        validate_parameter_formats(options)
        validate_file_references(options)
        validate_directory_structure(options)
        
        log_success("All parameters validated successfully", 
                   operation: operation_type, 
                   validated_params: required_params.length)
      end
    end
    
    # Validate specific parameter groups
    def validate_required_presence(options, required_params)
      missing_params = []
      
      required_params.each do |param|
        value = options[param]
        if value.nil? || (value.is_a?(String) && value.strip.empty?)
          missing_params << param
        end
      end
      
      unless missing_params.empty?
        log_error("Missing required parameters", missing: missing_params)
        raise ValidationError.new("required_params", missing_params, 
                                "Required parameters are missing: #{missing_params.join(', ')}")
      end
      
      log_info("Required parameters present", count: required_params.length)
    end
    
    def validate_parameter_formats(options)
      invalid_params = []
      
      VALIDATORS.each do |param, validator|
        value = options[param]
        next if value.nil? # Skip validation for optional params
        
        unless validator.call(value)
          invalid_params << { param: param, value: value }
          log_warn("Invalid parameter format", param: param, value: value)
        end
      end
      
      unless invalid_params.empty?
        details = invalid_params.map { |p| "#{p[:param]}='#{p[:value]}'" }.join(", ")
        raise ValidationError.new("format", invalid_params, 
                                "Invalid parameter formats: #{details}")
      end
      
      log_info("Parameter formats validated", validated: VALIDATORS.keys.length)
    end
    
    def validate_file_references(options)
      file_params = {
        api_key_path: "API key file",
        app_dir: "App directory"
      }
      
      missing_files = []
      
      file_params.each do |param, description|
        path = options[param]
        next if path.nil?
        
        # Resolve relative paths
        resolved_path = resolve_path(path, options)
        
        if param == :api_key_path
          unless validate_api_key_file(resolved_path)
            missing_files << { param: param, path: resolved_path, description: description }
          end
        elsif param == :app_dir
          unless validate_directory(resolved_path)
            missing_files << { param: param, path: resolved_path, description: description }
          end
        end
      end
      
      unless missing_files.empty?
        missing_files.each do |file|
          log_error("File not found", param: file[:param], path: file[:path])
        end
        
        details = missing_files.map { |f| "#{f[:description]} at #{f[:path]}" }.join(", ")
        raise ValidationError.new("files", missing_files, 
                                "Required files not found: #{details}")
      end
      
      log_info("File references validated", validated: file_params.length)
    end
    
    def validate_directory_structure(options)
      app_dir = options[:app_dir]
      return unless app_dir
      
      required_items = {
        xcode_project: "Xcode project file (.xcodeproj or .xcworkspace)",
        apple_info_dir: "apple_info directory (optional but recommended)"
      }
      
      issues = []
      
      # Check for Xcode project
      project_files = Dir.glob(File.join(app_dir, "*.{xcodeproj,xcworkspace}"))
      if project_files.empty?
        issues << "No Xcode project found in #{app_dir}"
      else
        log_info("Xcode project found", project: File.basename(project_files.first))
      end
      
      # Check for apple_info directory (warning, not error)
      apple_info_path = File.join(app_dir, "apple_info")
      unless File.directory?(apple_info_path)
        log_warn("apple_info directory not found", 
                path: apple_info_path,
                recommendation: "Consider using apple_info structure for better organization")
      else
        validate_apple_info_structure(apple_info_path)
      end
      
      unless issues.empty?
        raise ValidationError.new("directory_structure", app_dir, issues.join("; "))
      end
    end
    
    def validate_apple_info_structure(apple_info_path)
      subdirs = %w[certificates profiles]
      existing_subdirs = []
      
      subdirs.each do |subdir|
        subdir_path = File.join(apple_info_path, subdir)
        if File.directory?(subdir_path)
          existing_subdirs << subdir
        end
      end
      
      log_info("apple_info structure validated", 
              path: apple_info_path,
              subdirectories: existing_subdirs)
    end
    
    # Environment validation
    def validate_environment
      log_step("Environment Validation", "Checking system requirements") do
        validate_xcode_tools
        validate_fastlane_tools
        validate_network_connectivity
        validate_disk_space
        
        log_success("Environment validation completed")
      end
    end
    
    def validate_xcode_tools
      required_tools = {
        'xcodebuild' => 'Xcode command line tools',
        'security' => 'macOS security framework',
        'agvtool' => 'Apple generic versioning tool'
      }
      
      missing_tools = []
      
      required_tools.each do |tool, description|
        unless system("which #{tool} > /dev/null 2>&1")
          missing_tools << "#{tool} (#{description})"
        end
      end
      
      unless missing_tools.empty?
        log_error("Missing required tools", tools: missing_tools)
        raise ValidationError.new("tools", missing_tools, 
                                "Missing required tools: #{missing_tools.join(', ')}")
      end
      
      log_info("Xcode tools validated", tools: required_tools.keys)
    end
    
    def validate_fastlane_tools
      # Check FastLane installation
      unless system("which fastlane > /dev/null 2>&1")
        raise ValidationError.new("fastlane", nil, "FastLane is not installed")
      end
      
      # Check Ruby version compatibility
      ruby_version = RUBY_VERSION
      if Gem::Version.new(ruby_version) < Gem::Version.new('2.5.0')
        log_warn("Ruby version may be too old", version: ruby_version, recommended: "2.5.0+")
      end
      
      log_info("FastLane tools validated", ruby_version: ruby_version)
    end
    
    def validate_network_connectivity
      # Test connection to Apple services
      test_urls = [
        'https://api.appstoreconnect.apple.com',
        'https://developer.apple.com'
      ]
      
      failed_connections = []
      
      test_urls.each do |url|
        unless test_http_connectivity(url)
          failed_connections << url
        end
      end
      
      if failed_connections.any?
        log_warn("Network connectivity issues", failed: failed_connections)
        # Don't fail validation for network issues, just warn
      else
        log_info("Network connectivity validated")
      end
    end
    
    def validate_disk_space(minimum_gb = 5)
      # Check available disk space
      disk_info = `df -h . 2>/dev/null | tail -1`.split
      available_space = disk_info[3] if disk_info.length >= 4
      
      if available_space
        log_info("Disk space check", available: available_space)
      else
        log_warn("Could not determine available disk space")
      end
    end
    
    private
    
    def get_required_params(operation_type)
      case operation_type
      when :build_and_upload
        REQUIRED_PARAMS[:basic] + REQUIRED_PARAMS[:build] + REQUIRED_PARAMS[:upload]
      when :setup_certificates
        REQUIRED_PARAMS[:basic]
      when :team_setup
        REQUIRED_PARAMS[:basic] + REQUIRED_PARAMS[:team]
      else
        REQUIRED_PARAMS[:basic]
      end
    end
    
    def resolve_path(path, options)
      return path if path.start_with?('/')
      
      # Try to resolve relative to app_dir first
      if options[:app_dir]
        candidate = File.join(options[:app_dir], path)
        return candidate if File.exist?(candidate)
        
        # Try apple_info directory
        apple_info_candidate = File.join(options[:app_dir], 'apple_info', path)
        return apple_info_candidate if File.exist?(apple_info_candidate)
      end
      
      # Fallback to current directory
      File.expand_path(path)
    end
    
    def validate_api_key_file(path)
      return false unless File.exist?(path)
      return false unless path.end_with?('.p8')
      return false unless File.readable?(path)
      
      # Basic format validation
      content = File.read(path)
      content.include?('-----BEGIN PRIVATE KEY-----') && 
        content.include?('-----END PRIVATE KEY-----')
    rescue
      false
    end
    
    def validate_directory(path)
      File.directory?(path) && File.readable?(path)
    end
    
    def test_http_connectivity(url, timeout = 10)
      require 'net/http'
      require 'uri'
      
      uri = URI(url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = (uri.scheme == 'https')
      http.open_timeout = timeout
      http.read_timeout = timeout
      
      response = http.head('/')
      response.code.to_i < 400
    rescue
      false
    end
  end
end

# Convenience methods for FastLane integration
def validate_parameters(options, operation_type = :basic)
  ParameterValidator.validate_all(options, operation_type)
end

def validate_environment
  ParameterValidator.validate_environment
end