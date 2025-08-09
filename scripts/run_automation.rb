#!/usr/bin/env ruby

# iOS Publishing Automation Platform - Main Runner Script
# This script demonstrates the complete workflow and provides easy command-line access

require 'optparse'
require 'fileutils'
require_relative 'fastlane/modules/core/logger'

class IOSAutomationRunner
  def initialize
    @options = {}
    @parser = setup_option_parser
  end
  
  def run(args)
    @parser.parse!(args)
    
    command = args.first
    
    case command
    when 'setup'
      run_setup
    when 'build'
      run_build_and_upload
    when 'status'
      run_status
    when 'validate'
      run_validate
    when 'cleanup'
      run_cleanup
    when 'help', nil
      show_help
    else
      FastlaneLogger.error("Unknown command: #{command}")
      show_help
      exit 1
    end
  end
  
  private
  
  def setup_option_parser
    OptionParser.new do |opts|
      opts.banner = "Usage: ruby run_automation.rb [command] [options]"
      
      opts.separator ""
      opts.separator "Commands:"
      opts.separator "    setup     - Setup certificates and provisioning profiles only"
      opts.separator "    build     - Complete build and upload pipeline"
      opts.separator "    status    - Show current certificate and profile status"  
      opts.separator "    validate  - Validate certificate lifecycle and expiration"
      opts.separator "    cleanup   - Clean up certificates and profiles"
      opts.separator "    help      - Show this help message"
      
      opts.separator ""
      opts.separator "Options:"
      
      opts.on("--app-identifier ID", "Bundle ID (e.g., com.yourcompany.yourapp)") do |v|
        @options[:app_identifier] = v
      end
      
      opts.on("--apple-id EMAIL", "Apple ID email") do |v|
        @options[:apple_id] = v
      end
      
      opts.on("--team-id ID", "Developer Team ID") do |v|
        @options[:team_id] = v
      end
      
      opts.on("--api-key-path PATH", "Path to App Store Connect API key (.p8 file)") do |v|
        @options[:api_key_path] = v
      end
      
      opts.on("--api-key-id ID", "App Store Connect API Key ID") do |v|
        @options[:api_key_id] = v
      end
      
      opts.on("--api-issuer-id ID", "App Store Connect API Issuer ID") do |v|
        @options[:api_issuer_id] = v
      end
      
      opts.on("--app-name NAME", "App display name") do |v|
        @options[:app_name] = v
      end
      
      opts.on("--scheme SCHEME", "Xcode scheme to build") do |v|
        @options[:scheme] = v
      end
      
      opts.on("--configuration CONFIG", "Build configuration (Debug/Release)") do |v|
        @options[:configuration] = v
      end
      
      opts.on("--config-file FILE", "Load configuration from file") do |v|
        load_config_file(v)
      end
      
      opts.on("-v", "--verbose", "Verbose output") do |v|
        @options[:verbose] = v
      end
      
      opts.on("-h", "--help", "Show this help message") do
        FastlaneLogger.info(opts.to_s)
        exit
      end
    end
  end
  
  def load_config_file(file)
    unless File.exist?(file)
      FastlaneLogger.error("Configuration file not found: #{file}")
      exit 1
    end
    
    config = {}
    File.readlines(file).each do |line|
      line = line.strip
      next if line.empty? || line.start_with?('#')
      
      key, value = line.split('=', 2)
      config[key.strip.to_sym] = value.strip.gsub(/^["']|["']$/, '') if key && value
    end
    
    @options.merge!(config)
    FastlaneLogger.success("Loaded configuration from: #{file}")
  end
  
  def run_setup
    FastlaneLogger.info("Running Certificate and Provisioning Profile Setup...")
    execute_fastlane_command("setup_certificates")
  end
  
  def run_build_and_upload
    FastlaneLogger.info("Running Complete Build and Upload Pipeline...")
    execute_fastlane_command("build_and_upload")
  end
  
  def run_status
    FastlaneLogger.info("Checking Certificate and Profile Status...")
    execute_fastlane_command("status")
  end
  
  def run_validate
    FastlaneLogger.info("Running Certificate Lifecycle Validation...")
    execute_fastlane_command("validate_certificates")
  end
  
  def run_cleanup
    FastlaneLogger.info("Running Cleanup...")
    execute_fastlane_command("cleanup")
  end
  
  def execute_fastlane_command(lane)
    # Change to scripts directory
    scripts_dir = File.expand_path(".", __dir__)
    
    # Build fastlane command with options
    cmd = ["fastlane", lane]
    
    @options.each do |key, value|
      cmd << "#{key}:#{value}" if value
    end
    
    FastlaneLogger.info("Executing from: #{scripts_dir}")
    FastlaneLogger.info("Command: #{cmd.join(' ')}")
    
    # Execute the command
    Dir.chdir(scripts_dir) do
      system(*cmd)
    end
    
    if $?.success?
      FastlaneLogger.success("Command completed successfully!")
    else
      FastlaneLogger.error("Command failed with exit code: #{$?.exitstatus}")
      exit $?.exitstatus
    end
  end
  
  def show_help
    help_text = <<~HELP
      #{@parser}

      Examples:

        # Setup certificates and provisioning profiles:
        ruby run_automation.rb setup \\
          --app-identifier com.yourcompany.yourapp \\
          --apple-id your.email@example.com \\
          --team-id YOUR_TEAM_ID \\
          --api-key-path ../certificates/AuthKey_YOUR_KEY_ID.p8 \\
          --api-key-id YOUR_KEY_ID \\
          --api-issuer-id YOUR_ISSUER_ID \\
          --app-name "Your App Name"

        # Complete build and upload:
        ruby run_automation.rb build \\
          --app-identifier com.yourcompany.yourapp \\
          --apple-id your.email@example.com \\
          --team-id YOUR_TEAM_ID \\
          --api-key-path ../certificates/AuthKey_YOUR_KEY_ID.p8 \\
          --api-key-id YOUR_KEY_ID \\
          --api-issuer-id YOUR_ISSUER_ID \\
          --app-name "Your App Name" \\
          --scheme YourAppScheme \\
          --configuration Release

        # Use configuration file:
        ruby run_automation.rb setup --config-file config.txt

        # Check status:
        ruby run_automation.rb status
    HELP
    
    FastlaneLogger.info(help_text)
  end
end

# Run the automation if called directly
if __FILE__ == $0
  runner = IOSAutomationRunner.new
  runner.run(ARGV)
end