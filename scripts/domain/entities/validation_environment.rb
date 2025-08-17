# frozen_string_literal: true

require_relative '../shared/validation_result'

##
# ValidationEnvironment Domain Entity
#
# Encapsulates all aspects of the iOS deployment environment that need validation
# before a successful deployment can occur. This entity orchestrates comprehensive
# pre-deployment checks across multiple validation domains.
#
# Validation Domains:
# - Environment: Xcode, Command Line Tools, system requirements
# - Network: Internet connectivity, Apple Developer services
# - Authentication: App Store Connect API credentials
# - Privacy: Info.plist privacy usage descriptions
# - Certificates: Code signing certificates and provisioning profiles
# - Project: Xcode project configuration and build settings
#
# This entity follows Clean Architecture principles:
# - Contains business logic for validation orchestration
# - Independent of external frameworks and tools
# - Provides comprehensive validation reporting
# - Supports flexible validation modes (quick, full, strict)
#
# @example Basic validation
#   environment = ValidationEnvironment.new(
#     app_identifier: "com.mycompany.myapp",
#     team_id: "ABC1234567",
#     scheme: "MyApp"
#   )
#   result = environment.validate_all
#
# @example Quick validation (environment and network only)
#   environment = ValidationEnvironment.new
#   result = environment.validate_quick
#
class ValidationEnvironment
  attr_reader :app_identifier, :team_id, :scheme, :project_directory, 
              :apple_info_dir, :validation_mode, :strict_mode

  ##
  # Validation modes supported by the system
  VALIDATION_MODES = %w[quick full comprehensive].freeze

  ##
  # Validation domain definitions with priority and dependencies
  VALIDATION_DOMAINS = {
    environment: {
      priority: 1,
      description: 'System environment and tools',
      dependencies: [],
      required_for_quick: true
    },
    network: {
      priority: 2,
      description: 'Network connectivity and services',
      dependencies: [],
      required_for_quick: true
    },
    authentication: {
      priority: 3,
      description: 'Apple Developer API credentials',
      dependencies: [:environment, :network],
      required_for_quick: false
    },
    privacy: {
      priority: 4,
      description: 'Privacy usage descriptions validation',
      dependencies: [:environment],
      required_for_quick: false
    },
    certificates: {
      priority: 5,
      description: 'Code signing certificates and profiles',
      dependencies: [:environment, :authentication],
      required_for_quick: false
    },
    project: {
      priority: 6,
      description: 'Xcode project configuration',
      dependencies: [:environment],
      required_for_quick: false
    }
  }.freeze

  ##
  # Initialize validation environment
  #
  # @param app_identifier [String] Bundle identifier for the iOS app
  # @param team_id [String] Apple Developer Team ID
  # @param scheme [String] Xcode scheme name
  # @param project_directory [String] Path to Xcode project directory
  # @param apple_info_dir [String] Path to apple_info directory
  # @param validation_mode [String] Validation mode (quick, full, comprehensive)
  # @param strict_mode [Boolean] Whether to treat warnings as errors
  def initialize(app_identifier: nil, team_id: nil, scheme: nil, 
                 project_directory: '.', apple_info_dir: nil, 
                 validation_mode: 'full', strict_mode: false)
    @app_identifier = app_identifier
    @team_id = team_id  
    @scheme = scheme
    @project_directory = project_directory
    @apple_info_dir = apple_info_dir
    @validation_mode = validation_mode
    @strict_mode = strict_mode
    
    # Validation results storage
    @domain_results = {}
    @overall_success = true
    @total_checks = 0
    @successful_checks = 0
  end

  ##
  # Run quick validation (environment and network only)
  #
  # @return [ValidationResult] Quick validation result
  def validate_quick
    validate_with_mode('quick')
  end

  ##
  # Run full validation (all domains except project-specific)
  #
  # @return [ValidationResult] Full validation result
  def validate_full
    validate_with_mode('full')
  end

  ##
  # Run comprehensive validation (all domains including deep project analysis)
  #
  # @return [ValidationResult] Comprehensive validation result
  def validate_comprehensive
    validate_with_mode('comprehensive')
  end

  ##
  # Run all validation checks based on current validation_mode
  #
  # @return [ValidationResult] Complete validation result
  def validate_all
    case @validation_mode.downcase
    when 'quick'
      validate_quick
    when 'comprehensive'
      validate_comprehensive
    else
      validate_full
    end
  end

  ##
  # Validate specific domain only
  #
  # @param domain [Symbol] Validation domain to check
  # @return [ValidationResult] Domain-specific validation result
  def validate_domain(domain)
    unless VALIDATION_DOMAINS.key?(domain)
      return ValidationResult.new(
        success: false,
        errors: [{ 
          type: 'invalid_domain',
          message: "Unknown validation domain: #{domain}",
          available_domains: VALIDATION_DOMAINS.keys
        }]
      )
    end

    case domain
    when :environment
      validate_environment_domain
    when :network
      validate_network_domain
    when :authentication
      validate_authentication_domain
    when :privacy
      validate_privacy_domain
    when :certificates
      validate_certificates_domain
    when :project
      validate_project_domain
    end
  end

  ##
  # Get validation summary and recommendations
  #
  # @return [Hash] Summary of validation results with recommendations
  def get_validation_summary
    {
      overall_success: @overall_success,
      total_checks: @total_checks,
      successful_checks: @successful_checks,
      failed_checks: @total_checks - @successful_checks,
      success_rate: @total_checks > 0 ? (@successful_checks.to_f / @total_checks * 100).round(1) : 0,
      domain_results: @domain_results,
      recommendations: generate_recommendations,
      next_steps: generate_next_steps
    }
  end

  ##
  # Check if environment is ready for deployment
  #
  # @return [Boolean] True if environment passes all required validations
  def deployment_ready?
    @overall_success && required_domains_valid?
  end

  ##
  # Get list of failed validation domains
  #
  # @return [Array<Symbol>] List of domains that failed validation
  def failed_domains
    @domain_results.select { |_domain, result| !result[:success] }.keys
  end

  ##
  # Get list of domains with warnings
  #
  # @return [Array<Symbol>] List of domains with warnings
  def warning_domains
    @domain_results.select { |_domain, result| result[:warnings]&.any? }.keys
  end

  private

  ##
  # Run validation with specific mode
  #
  # @param mode [String] Validation mode to use
  # @return [ValidationResult] Mode-specific validation result
  def validate_with_mode(mode)
    reset_validation_state
    domains_to_validate = get_domains_for_mode(mode)
    
    # Execute validations in dependency order
    ordered_domains = sort_domains_by_priority(domains_to_validate)
    
    ordered_domains.each do |domain|
      # Check dependencies first
      if dependencies_satisfied?(domain)
        domain_result = validate_domain(domain)
        record_domain_result(domain, domain_result)
      else
        record_dependency_failure(domain)
      end
    end

    generate_final_result
  end

  ##
  # Get domains to validate for specific mode
  #
  # @param mode [String] Validation mode
  # @return [Array<Symbol>] List of domains to validate
  def get_domains_for_mode(mode)
    case mode.downcase
    when 'quick'
      VALIDATION_DOMAINS.select { |_domain, config| config[:required_for_quick] }.keys
    when 'comprehensive'
      VALIDATION_DOMAINS.keys
    else # full
      VALIDATION_DOMAINS.keys - [:project] # Full mode excludes deep project analysis
    end
  end

  ##
  # Sort domains by validation priority
  #
  # @param domains [Array<Symbol>] Domains to sort
  # @return [Array<Symbol>] Sorted domains
  def sort_domains_by_priority(domains)
    domains.sort_by { |domain| VALIDATION_DOMAINS[domain][:priority] }
  end

  ##
  # Check if domain dependencies are satisfied
  #
  # @param domain [Symbol] Domain to check
  # @return [Boolean] True if dependencies are satisfied
  def dependencies_satisfied?(domain)
    dependencies = VALIDATION_DOMAINS[domain][:dependencies]
    dependencies.all? { |dep| @domain_results[dep]&.dig(:success) }
  end

  ##
  # Validate environment domain (Xcode, tools, system)
  #
  # @return [ValidationResult] Environment validation result
  def validate_environment_domain
    checks = []
    errors = []
    warnings = []

    # Check Xcode installation
    xcode_check = check_xcode_installation
    checks << xcode_check
    errors.concat(xcode_check[:errors] || [])
    warnings.concat(xcode_check[:warnings] || [])

    # Check Command Line Tools
    cli_tools_check = check_command_line_tools
    checks << cli_tools_check
    errors.concat(cli_tools_check[:errors] || [])
    warnings.concat(cli_tools_check[:warnings] || [])

    # Check required system tools
    system_tools_check = check_system_tools
    checks << system_tools_check
    errors.concat(system_tools_check[:errors] || [])
    warnings.concat(system_tools_check[:warnings] || [])

    success = errors.empty? && (@strict_mode ? warnings.empty? : true)

    ValidationResult.new(
      success: success,
      errors: errors,
      warnings: warnings,
      data: {
        domain: :environment,
        checks_performed: checks,
        environment_info: get_environment_info
      }
    )
  end

  ##
  # Validate network domain (connectivity, services)
  #
  # @return [ValidationResult] Network validation result
  def validate_network_domain
    checks = []
    errors = []
    warnings = []

    # Check internet connectivity
    internet_check = check_internet_connectivity
    checks << internet_check
    errors.concat(internet_check[:errors] || [])
    warnings.concat(internet_check[:warnings] || [])

    # Check Apple Developer services
    apple_services_check = check_apple_services
    checks << apple_services_check
    errors.concat(apple_services_check[:errors] || [])
    warnings.concat(apple_services_check[:warnings] || [])

    success = errors.empty? && (@strict_mode ? warnings.empty? : true)

    ValidationResult.new(
      success: success,
      errors: errors,
      warnings: warnings,
      data: {
        domain: :network,
        checks_performed: checks,
        connectivity_info: get_connectivity_info
      }
    )
  end

  ##
  # Validate authentication domain (API credentials)
  #
  # @return [ValidationResult] Authentication validation result
  def validate_authentication_domain
    # Implementation will delegate to existing validate_api_credentials function
    # This is a placeholder for Clean Architecture integration
    ValidationResult.new(
      success: true,
      data: { domain: :authentication, placeholder: true }
    )
  end

  ##
  # Validate privacy domain (Info.plist usage descriptions)
  #
  # @return [ValidationResult] Privacy validation result
  def validate_privacy_domain
    # Implementation will delegate to existing ValidatePrivacyUsageDescriptions use case
    # This is a placeholder for Clean Architecture integration
    ValidationResult.new(
      success: true,
      data: { domain: :privacy, placeholder: true }
    )
  end

  ##
  # Validate certificates domain (signing certificates and profiles)
  #
  # @return [ValidationResult] Certificates validation result
  def validate_certificates_domain
    # Implementation will delegate to existing certificate validation functions
    # This is a placeholder for Clean Architecture integration
    ValidationResult.new(
      success: true,
      data: { domain: :certificates, placeholder: true }
    )
  end

  ##
  # Validate project domain (Xcode configuration)
  #
  # @return [ValidationResult] Project validation result
  def validate_project_domain
    # Implementation will delegate to existing validate_project_configuration function
    # This is a placeholder for Clean Architecture integration
    ValidationResult.new(
      success: true,
      data: { domain: :project, placeholder: true }
    )
  end

  ##
  # Reset validation state for new validation run
  def reset_validation_state
    @domain_results = {}
    @overall_success = true
    @total_checks = 0
    @successful_checks = 0
  end

  ##
  # Record result for a validation domain
  #
  # @param domain [Symbol] Validation domain
  # @param result [ValidationResult] Domain validation result
  def record_domain_result(domain, result)
    @domain_results[domain] = {
      success: result.success?,
      errors: result.errors,
      warnings: result.warnings,
      data: result.data
    }

    @total_checks += 1
    @successful_checks += 1 if result.success?
    @overall_success = false unless result.success?
  end

  ##
  # Record dependency failure for a domain
  #
  # @param domain [Symbol] Domain with failed dependencies
  def record_dependency_failure(domain)
    failed_deps = VALIDATION_DOMAINS[domain][:dependencies].select do |dep|
      !@domain_results[dep]&.dig(:success)
    end

    @domain_results[domain] = {
      success: false,
      errors: [{
        type: 'dependency_failure',
        message: "Cannot validate #{domain} - dependencies failed: #{failed_deps.join(', ')}",
        failed_dependencies: failed_deps
      }],
      warnings: [],
      data: { domain: domain, skipped: true }
    }

    @total_checks += 1
    @overall_success = false
  end

  ##
  # Generate final validation result
  #
  # @return [ValidationResult] Complete validation result
  def generate_final_result
    all_errors = @domain_results.values.flat_map { |result| result[:errors] }
    all_warnings = @domain_results.values.flat_map { |result| result[:warnings] }

    ValidationResult.new(
      success: @overall_success,
      errors: all_errors,
      warnings: all_warnings,
      data: get_validation_summary
    )
  end

  ##
  # Generate recommendations based on validation results
  #
  # @return [Array<Hash>] List of recommendations
  def generate_recommendations
    recommendations = []

    failed_domains.each do |domain|
      domain_config = VALIDATION_DOMAINS[domain]
      recommendations << {
        priority: 'high',
        domain: domain,
        message: "Fix #{domain_config[:description]} issues before deployment",
        action: get_domain_fix_action(domain)
      }
    end

    warning_domains.each do |domain|
      domain_config = VALIDATION_DOMAINS[domain]
      recommendations << {
        priority: 'medium',
        domain: domain,
        message: "Address #{domain_config[:description]} warnings for optimal deployment",
        action: get_domain_warning_action(domain)
      }
    end

    recommendations
  end

  ##
  # Generate next steps based on validation results
  #
  # @return [Array<String>] List of next steps
  def generate_next_steps
    if deployment_ready?
      ['✅ Environment validated! Ready for deployment.', 'Run: apple-deploy deploy [your parameters]']
    else
      ['❌ Fix validation issues before deployment', 'Run: apple-deploy validate to check progress']
    end
  end

  ##
  # Check if required domains are valid for deployment
  #
  # @return [Boolean] True if all required domains are valid
  def required_domains_valid?
    required_domains = [:environment, :network]
    required_domains.all? { |domain| @domain_results[domain]&.dig(:success) }
  end

  ##
  # Get fix action for failed domain
  #
  # @param domain [Symbol] Failed domain
  # @return [String] Recommended fix action
  def get_domain_fix_action(domain)
    case domain
    when :environment
      'Install/update Xcode and Command Line Tools'
    when :network
      'Check internet connection and firewall settings'
    when :authentication
      'Verify App Store Connect API credentials'
    when :privacy
      'Add missing privacy usage descriptions to Info.plist'
    when :certificates
      'Setup or renew code signing certificates'
    when :project
      'Fix Xcode project configuration issues'
    else
      "Fix #{domain} validation issues"
    end
  end

  ##
  # Get warning action for domain with warnings
  #
  # @param domain [Symbol] Domain with warnings
  # @return [String] Recommended warning action
  def get_domain_warning_action(domain)
    case domain
    when :environment
      'Update tools to latest versions for best compatibility'
    when :certificates
      'Renew certificates approaching expiration'
    else
      "Review #{domain} warnings for optimization"
    end
  end

  # Placeholder methods for environment checks
  # These will be implemented to call existing shell script functions

  def check_xcode_installation
    { success: true, errors: [], warnings: [] }
  end

  def check_command_line_tools
    { success: true, errors: [], warnings: [] }
  end

  def check_system_tools
    { success: true, errors: [], warnings: [] }
  end

  def check_internet_connectivity
    { success: true, errors: [], warnings: [] }
  end

  def check_apple_services
    { success: true, errors: [], warnings: [] }
  end

  def get_environment_info
    { placeholder: 'Environment info will be populated' }
  end

  def get_connectivity_info
    { placeholder: 'Connectivity info will be populated' }
  end
end