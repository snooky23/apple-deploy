# frozen_string_literal: true

require_relative '../entities/validation_environment'
require_relative '../shared/validation_result'
require_relative 'validate_privacy_usage_descriptions'

##
# ValidateDeploymentEnvironment Use Case
#
# Orchestrates comprehensive pre-deployment validation by coordinating
# multiple validation domains through the ValidationEnvironment entity.
# This use case provides a unified interface for all deployment validation
# needs and integrates with existing validation functions.
#
# This use case follows Clean Architecture principles:
# - Orchestrates business logic through domain entities
# - Coordinates with other use cases (privacy validation)
# - Provides comprehensive validation reporting
# - Supports multiple validation modes and strategies
#
# Validation Capabilities:
# - Environment validation (Xcode, tools, system requirements)
# - Network connectivity (Internet, Apple Developer services)
# - API authentication (App Store Connect credentials)
# - Privacy compliance (Info.plist usage descriptions)
# - Certificate health (Code signing certificates and profiles)
# - Project structure (Xcode configuration and build settings)
#
# @example Quick validation
#   request = ValidateDeploymentEnvironmentRequest.new(mode: 'quick')
#   use_case = ValidateDeploymentEnvironment.new
#   result = use_case.execute(request)
#
# @example Full app validation
#   request = ValidateDeploymentEnvironmentRequest.new(
#     app_identifier: "com.mycompany.myapp",
#     team_id: "ABC1234567",
#     scheme: "MyApp",
#     mode: 'full'
#   )
#   result = use_case.execute(request)
#
class ValidateDeploymentEnvironment
  ##
  # Execute deployment environment validation
  #
  # @param request [ValidateDeploymentEnvironmentRequest] Validation request
  # @return [ValidationResult] Comprehensive validation result
  def execute(request)
    # Validate request parameters
    request_validation = validate_request(request)
    return request_validation if request_validation.failure?

    begin
      # Create validation environment entity
      validation_environment = create_validation_environment(request)
      
      # Execute validation based on mode
      validation_result = execute_validation_mode(validation_environment, request)
      
      # Enhance result with integration data
      enhanced_result = enhance_validation_result(validation_result, request, validation_environment)
      
      enhanced_result
      
    rescue StandardError => e
      ValidationResult.new(
        success: false,
        errors: [{
          type: 'validation_error',
          message: "Deployment environment validation failed: #{e.message}",
          technical_details: e.backtrace&.first(3)
        }]
      )
    end
  end

  private

  ##
  # Validate the incoming request
  #
  # @param request [ValidateDeploymentEnvironmentRequest] Request to validate
  # @return [ValidationResult] Validation result for request
  def validate_request(request)
    errors = []
    
    unless request.respond_to?(:mode)
      errors << {
        type: 'invalid_request',
        message: 'Request must have mode attribute'
      }
    end
    
    unless ValidationEnvironment::VALIDATION_MODES.include?(request.mode)
      errors << {
        type: 'invalid_mode',
        message: "Invalid validation mode: #{request.mode}",
        valid_modes: ValidationEnvironment::VALIDATION_MODES
      }
    end
    
    # Validate app-specific parameters if provided
    if request.app_identifier && !valid_bundle_identifier?(request.app_identifier)
      errors << {
        type: 'invalid_app_identifier',
        message: 'App identifier must be a valid reverse DNS format (e.g., com.company.app)'
      }
    end
    
    if request.team_id && !valid_team_id?(request.team_id)
      errors << {
        type: 'invalid_team_id',
        message: 'Team ID must be a 10-character alphanumeric string'
      }
    end
    
    if errors.any?
      return ValidationResult.new(success: false, errors: errors)
    end
    
    ValidationResult.new(success: true)
  end

  ##
  # Create validation environment entity from request
  #
  # @param request [ValidateDeploymentEnvironmentRequest] Validation request
  # @return [ValidationEnvironment] Configured validation environment
  def create_validation_environment(request)
    ValidationEnvironment.new(
      app_identifier: request.app_identifier,
      team_id: request.team_id,
      scheme: request.scheme,
      project_directory: request.project_directory || '.',
      apple_info_dir: request.apple_info_dir,
      validation_mode: request.mode,
      strict_mode: request.strict_mode
    )
  end

  ##
  # Execute validation based on specified mode
  #
  # @param environment [ValidationEnvironment] Validation environment
  # @param request [ValidateDeploymentEnvironmentRequest] Original request
  # @return [ValidationResult] Mode-specific validation result
  def execute_validation_mode(environment, request)
    case request.mode.downcase
    when 'quick'
      environment.validate_quick
    when 'comprehensive'
      environment.validate_comprehensive
    else # full
      environment.validate_full
    end
  end

  ##
  # Enhance validation result with additional context and integrations
  #
  # @param result [ValidationResult] Original validation result
  # @param request [ValidateDeploymentEnvironmentRequest] Original request
  # @param environment [ValidationEnvironment] Validation environment
  # @return [ValidationResult] Enhanced validation result
  def enhance_validation_result(result, request, environment)
    enhanced_data = result.data.dup
    
    # Add request context
    enhanced_data[:validation_request] = {
      mode: request.mode,
      app_identifier: request.app_identifier,
      team_id: request.team_id,
      scheme: request.scheme,
      strict_mode: request.strict_mode,
      timestamp: Time.now.utc.iso8601
    }
    
    # Add deployment readiness assessment
    enhanced_data[:deployment_readiness] = {
      ready: environment.deployment_ready?,
      failed_domains: environment.failed_domains,
      warning_domains: environment.warning_domains,
      critical_issues: get_critical_issues(result),
      blocking_issues: get_blocking_issues(result)
    }
    
    # Add validation performance metrics
    enhanced_data[:validation_metrics] = {
      total_domains: ValidationEnvironment::VALIDATION_DOMAINS.size,
      validated_domains: environment.get_validation_summary[:domain_results].size,
      success_rate: environment.get_validation_summary[:success_rate],
      execution_mode: request.mode
    }
    
    # Add integration recommendations
    enhanced_data[:integration_recommendations] = generate_integration_recommendations(result, request)
    
    # Add next actions based on results
    enhanced_data[:next_actions] = generate_next_actions(result, environment)
    
    ValidationResult.new(
      success: result.success?,
      errors: result.errors,
      warnings: result.warnings,
      data: enhanced_data
    )
  end

  ##
  # Generate integration recommendations based on validation results
  #
  # @param result [ValidationResult] Validation result
  # @param request [ValidateDeploymentEnvironmentRequest] Original request
  # @return [Array<Hash>] Integration recommendations
  def generate_integration_recommendations(result, request)
    recommendations = []
    
    # Privacy validation integration
    if request.app_identifier && request.scheme
      if has_privacy_issues?(result)
        recommendations << {
          type: 'privacy_integration',
          priority: 'high',
          action: 'Run standalone privacy validation',
          command: "apple-deploy validate_privacy scheme=\"#{request.scheme}\"",
          description: 'Get detailed privacy validation with fix instructions'
        }
      end
    end
    
    # Certificate management integration
    if has_certificate_issues?(result)
      recommendations << {
        type: 'certificate_integration',
        priority: 'high',
        action: 'Setup or renew certificates',
        command: build_certificate_command(request),
        description: 'Resolve certificate and provisioning profile issues'
      }
    end
    
    # Build verification integration
    if request.mode == 'comprehensive' && result.success?
      recommendations << {
        type: 'build_verification',
        priority: 'medium',
        action: 'Verify build before deployment',
        command: "apple-deploy verify_build scheme=\"#{request.scheme}\"",
        description: 'Test build integrity before TestFlight upload'
      }
    end
    
    recommendations
  end

  ##
  # Generate next actions based on validation results
  #
  # @param result [ValidationResult] Validation result
  # @param environment [ValidationEnvironment] Validation environment
  # @return [Array<Hash>] Next actions to take
  def generate_next_actions(result, environment)
    actions = []
    
    if result.success? && environment.deployment_ready?
      actions << {
        type: 'deploy',
        priority: 'primary',
        message: '🚀 Environment validated! Ready for deployment.',
        command: 'apple-deploy deploy [your parameters]'
      }
    else
      # Add actions for each failed domain
      environment.failed_domains.each do |domain|
        domain_config = ValidationEnvironment::VALIDATION_DOMAINS[domain]
        actions << {
          type: 'fix',
          priority: 'high',
          domain: domain,
          message: "Fix #{domain_config[:description]} issues",
          command: get_domain_fix_command(domain)
        }
      end
      
      # Add re-validation action
      actions << {
        type: 'revalidate',
        priority: 'medium',
        message: 'Re-run validation after fixes',
        command: 'apple-deploy validate [same parameters]'
      }
    end
    
    actions
  end

  ##
  # Get critical issues from validation result
  #
  # @param result [ValidationResult] Validation result
  # @return [Array<Hash>] Critical issues
  def get_critical_issues(result)
    result.errors.select { |error| error[:type] != 'warning' }
  end

  ##
  # Get blocking issues that prevent deployment
  #
  # @param result [ValidationResult] Validation result
  # @return [Array<Hash>] Blocking issues
  def get_blocking_issues(result)
    blocking_types = ['environment_error', 'network_error', 'authentication_error']
    result.errors.select { |error| blocking_types.include?(error[:type]) }
  end

  ##
  # Check if result has privacy-related issues
  #
  # @param result [ValidationResult] Validation result
  # @return [Boolean] True if privacy issues found
  def has_privacy_issues?(result)
    result.errors.any? { |error| error[:type]&.include?('privacy') } ||
    result.warnings.any? { |warning| warning[:type]&.include?('privacy') }
  end

  ##
  # Check if result has certificate-related issues
  #
  # @param result [ValidationResult] Validation result
  # @return [Boolean] True if certificate issues found
  def has_certificate_issues?(result)
    result.errors.any? { |error| error[:type]&.include?('certificate') } ||
    result.warnings.any? { |warning| warning[:type]&.include?('certificate') }
  end

  ##
  # Build certificate setup command based on request
  #
  # @param request [ValidateDeploymentEnvironmentRequest] Validation request
  # @return [String] Certificate setup command
  def build_certificate_command(request)
    cmd_parts = ['apple-deploy setup_certificates']
    
    cmd_parts << "team_id=\"#{request.team_id}\"" if request.team_id
    cmd_parts << "app_identifier=\"#{request.app_identifier}\"" if request.app_identifier
    cmd_parts << "apple_info_dir=\"#{request.apple_info_dir}\"" if request.apple_info_dir
    
    cmd_parts.join(' ')
  end

  ##
  # Get fix command for specific domain
  #
  # @param domain [Symbol] Domain that failed validation
  # @return [String] Recommended fix command
  def get_domain_fix_command(domain)
    case domain
    when :environment
      'Install Xcode and Command Line Tools from App Store'
    when :network
      'Check internet connection and firewall settings'
    when :authentication
      'apple-deploy help # Check API credentials setup'
    when :privacy
      'apple-deploy validate_privacy # Get detailed privacy guidance'
    when :certificates
      'apple-deploy setup_certificates # Setup signing certificates'
    when :project
      'Check Xcode project configuration and scheme'
    else
      "apple-deploy help # Get help for #{domain} issues"
    end
  end

  ##
  # Validate bundle identifier format
  #
  # @param identifier [String] Bundle identifier to validate
  # @return [Boolean] True if valid
  def valid_bundle_identifier?(identifier)
    return false unless identifier.is_a?(String)
    # Basic reverse DNS format validation
    identifier.match?(/\A[a-zA-Z0-9.-]+\.[a-zA-Z0-9.-]+\z/) && !identifier.start_with?('.') && !identifier.end_with?('.')
  end

  ##
  # Validate team ID format
  #
  # @param team_id [String] Team ID to validate
  # @return [Boolean] True if valid
  def valid_team_id?(team_id)
    return false unless team_id.is_a?(String)
    team_id.match?(/\A[A-Z0-9]{10}\z/)
  end
end

##
# Request object for ValidateDeploymentEnvironment use case
#
# Encapsulates all parameters needed for deployment environment validation
#
class ValidateDeploymentEnvironmentRequest
  attr_reader :app_identifier, :team_id, :scheme, :project_directory, 
              :apple_info_dir, :mode, :strict_mode, :domains

  ##
  # Initialize validation request
  #
  # @param app_identifier [String] Bundle identifier for the iOS app
  # @param team_id [String] Apple Developer Team ID
  # @param scheme [String] Xcode scheme name
  # @param project_directory [String] Path to Xcode project directory
  # @param apple_info_dir [String] Path to apple_info directory
  # @param mode [String] Validation mode (quick, full, comprehensive)
  # @param strict_mode [Boolean] Whether to treat warnings as errors
  # @param domains [Array<String>] Specific domains to validate (optional)
  def initialize(app_identifier: nil, team_id: nil, scheme: nil, 
                 project_directory: nil, apple_info_dir: nil, 
                 mode: 'full', strict_mode: false, domains: [])
    @app_identifier = app_identifier
    @team_id = team_id
    @scheme = scheme
    @project_directory = project_directory
    @apple_info_dir = apple_info_dir
    @mode = mode
    @strict_mode = strict_mode
    @domains = domains || []
  end
end