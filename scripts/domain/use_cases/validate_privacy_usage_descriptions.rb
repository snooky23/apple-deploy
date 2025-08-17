# frozen_string_literal: true

require_relative '../entities/privacy_compliance'
require_relative '../shared/validation_result'
require 'time'

##
# ValidatePrivacyUsageDescriptions Use Case
#
# Orchestrates the privacy validation workflow for iOS applications.
# Ensures apps have proper privacy usage descriptions before TestFlight upload
# to prevent ITMS-90683 and similar rejection errors.
#
# This use case follows Clean Architecture principles:
# - Uses PrivacyCompliance domain entity for business logic
# - Returns standardized ValidationResult objects
# - Provides comprehensive error reporting and fix guidance
# - Supports both strict and lenient validation modes
#
# @example Basic validation
#   request = ValidatePrivacyUsageDescriptionsRequest.new(
#     info_plist_path: "./MyApp/Info.plist"
#   )
#   use_case = ValidatePrivacyUsageDescriptions.new
#   result = use_case.execute(request)
#
# @example With framework detection
#   request = ValidatePrivacyUsageDescriptionsRequest.new(
#     info_plist_path: "./MyApp/Info.plist",
#     linked_frameworks: ["AVFoundation", "CoreLocation"],
#     strict_mode: true
#   )
#   result = use_case.execute(request)
#
class ValidatePrivacyUsageDescriptions
  ##
  # Execute privacy validation use case
  #
  # @param request [ValidatePrivacyUsageDescriptionsRequest] Validation request
  # @return [ValidationResult] Comprehensive validation result
  def execute(request)
    # Validate request parameters
    request_validation = validate_request(request)
    return request_validation if request_validation.failure?

    begin
      # Parse Info.plist data
      info_plist_data = parse_info_plist(request.info_plist_path)
      
      # Create privacy compliance entity
      privacy_compliance = PrivacyCompliance.new(
        info_plist_data, 
        strict_mode: request.strict_mode
      )
      
      # Perform privacy validation
      validation_result = privacy_compliance.validate_with_recommendations
      
      # Enhance result with additional context
      enhanced_result = enhance_validation_result(
        validation_result, 
        request, 
        privacy_compliance
      )
      
      enhanced_result
      
    rescue StandardError => e
      ValidationResult.new(
        success: false,
        errors: [{
          type: 'validation_error',
          message: "Privacy validation failed: #{e.message}",
          technical_details: e.backtrace&.first(3)
        }]
      )
    end
  end

  private

  ##
  # Validate the incoming request
  #
  # @param request [ValidatePrivacyUsageDescriptionsRequest] Request to validate
  # @return [ValidationResult] Validation result for request
  def validate_request(request)
    errors = []
    
    unless request.respond_to?(:info_plist_path)
      errors << {
        type: 'invalid_request',
        message: 'Request must have info_plist_path attribute'
      }
    end
    
    if request.info_plist_path.nil? || request.info_plist_path.strip.empty?
      errors << {
        type: 'missing_parameter',
        message: 'Info.plist path is required for privacy validation'
      }
    end
    
    if errors.any?
      return ValidationResult.new(success: false, errors: errors)
    end
    
    ValidationResult.new(success: true)
  end

  ##
  # Parse Info.plist file into hash data
  #
  # @param info_plist_path [String] Path to Info.plist file
  # @return [Hash] Parsed plist data
  # @raise [StandardError] If file cannot be read or parsed
  def parse_info_plist(info_plist_path)
    unless File.exist?(info_plist_path)
      raise "Info.plist file not found: #{info_plist_path}"
    end

    begin
      # Use plutil to convert plist to JSON for parsing
      json_output = `plutil -convert json -o - "#{info_plist_path}" 2>/dev/null`
      
      if $?.exitstatus != 0
        raise "Failed to parse Info.plist file: #{info_plist_path}"
      end
      
      require 'json'
      JSON.parse(json_output)
      
    rescue JSON::ParserError => e
      raise "Info.plist contains invalid data: #{e.message}"
    end
  end

  ##
  # Enhance validation result with additional context and recommendations
  #
  # @param result [ValidationResult] Original validation result
  # @param request [ValidatePrivacyUsageDescriptionsRequest] Original request
  # @param privacy_compliance [PrivacyCompliance] Privacy compliance entity
  # @return [ValidationResult] Enhanced validation result
  def enhance_validation_result(result, request, privacy_compliance)
    enhanced_data = result.data.dup
    
    # Add file information
    enhanced_data[:info_plist_path] = request.info_plist_path
    enhanced_data[:validation_timestamp] = Time.now.utc.iso8601
    
    # Add framework analysis if provided
    if request.linked_frameworks&.any?
      detected_requirements = privacy_compliance.detect_required_privacy_keys(
        frameworks: request.linked_frameworks
      )
      enhanced_data[:detected_framework_requirements] = detected_requirements
      enhanced_data[:linked_frameworks] = request.linked_frameworks
    end
    
    # Add category breakdown
    if result.data[:present_keys]&.any?
      categories = result.data[:present_keys].group_by do |key|
        privacy_compliance.privacy_key_info(key)&.dig(:category) || 'unknown'
      end
      enhanced_data[:privacy_categories] = categories
    end
    
    # Add detailed fix instructions
    if result.has_errors?
      enhanced_data[:fix_instructions] = generate_fix_instructions(result.errors)
    end
    
    # Add Apple documentation links
    enhanced_data[:reference_links] = {
      privacy_guide: 'https://developer.apple.com/documentation/uikit/protecting_the_user_s_privacy/requesting_access_to_protected_resources',
      app_store_review: 'https://developer.apple.com/app-store/review/guidelines/#privacy',
      privacy_manifest: 'https://developer.apple.com/documentation/bundleresources/privacy_manifest_files'
    }
    
    ValidationResult.new(
      success: result.success?,
      errors: result.errors,
      warnings: result.warnings,
      data: enhanced_data
    )
  end

  ##
  # Generate step-by-step fix instructions
  #
  # @param errors [Array<Hash>] Validation errors
  # @return [Array<Hash>] Fix instruction steps
  def generate_fix_instructions(errors)
    instructions = []
    
    missing_keys = errors.select { |e| e[:type] == 'missing_description' }
    
    if missing_keys.any?
      instructions << {
        step: 1,
        action: 'Open your Info.plist file in Xcode or text editor',
        details: 'Navigate to your app target and select Info.plist'
      }
      
      instructions << {
        step: 2,
        action: 'Add missing privacy usage description keys',
        details: "Add the following keys with appropriate descriptions:",
        keys_to_add: missing_keys.map do |error|
          {
            key: error[:key],
            description: error[:message],
            suggested_value: error[:fix_suggestion]
          }
        end
      }
      
      instructions << {
        step: 3,
        action: 'Test your changes',
        details: 'Run apple-deploy validate_privacy to verify all issues are resolved'
      }
      
      instructions << {
        step: 4,
        action: 'Deploy with confidence',
        details: 'Your app should now pass TestFlight upload validation'
      }
    end
    
    instructions
  end
end

##
# Request object for ValidatePrivacyUsageDescriptions use case
#
# Encapsulates all parameters needed for privacy validation
#
class ValidatePrivacyUsageDescriptionsRequest
  attr_reader :info_plist_path, :linked_frameworks, :strict_mode, :source_files

  ##
  # Initialize validation request
  #
  # @param info_plist_path [String] Path to Info.plist file to validate
  # @param linked_frameworks [Array<String>] List of linked frameworks for requirement detection
  # @param strict_mode [Boolean] Whether to apply strict validation (warnings as errors)
  # @param source_files [Array<String>] Source files for API usage analysis (future feature)
  def initialize(info_plist_path:, linked_frameworks: [], strict_mode: false, source_files: [])
    @info_plist_path = info_plist_path
    @linked_frameworks = linked_frameworks || []
    @strict_mode = strict_mode
    @source_files = source_files || []
  end
end