# Ensure Valid Certificates Use Case - Clean Architecture Domain Layer
# Business workflow: Ensure development and distribution certificates are available and valid

class EnsureValidCertificates
  def initialize(certificate_repository:, team_repository:, logger:)
    @certificate_repository = certificate_repository
    @team_repository = team_repository
    @logger = logger
  end
  
  # Execute the use case to ensure valid certificates are available
  # @param request [EnsureValidCertificatesRequest] Input parameters
  # @return [EnsureValidCertificatesResult] Result with status and certificate info
  def execute(request)
    @logger.info("🔐 Starting certificate validation for team #{request.team_id}")
    
    begin
      # Business Logic: Validate input parameters
      validate_request(request)
      
      # Business Logic: Check team certificate limits and status
      team = @team_repository.find_by_id(request.team_id)
      certificate_status = analyze_team_certificates(team, request)
      
      # Business Logic: Determine required actions based on certificate status
      required_actions = determine_required_actions(certificate_status, request)
      
      # Business Logic: Execute required certificate operations
      execution_result = execute_certificate_operations(required_actions, request)
      
      # Business Logic: Validate final certificate state
      final_validation = validate_final_certificate_state(request)
      
      @logger.success("✅ Certificate validation completed successfully")
      
      EnsureValidCertificatesResult.new(
        success: true,
        development_certificate: execution_result[:development_certificate],
        distribution_certificate: execution_result[:distribution_certificate],
        actions_taken: execution_result[:actions_taken],
        validation_result: final_validation
      )
      
    rescue CertificateLimitExceededError => e
      @logger.error("❌ Certificate limit exceeded: #{e.message}")
      EnsureValidCertificatesResult.new(
        success: false,
        error: e.message,
        error_type: :certificate_limit_exceeded,
        recovery_suggestion: suggest_certificate_cleanup(request.team_id)
      )
      
    rescue InvalidCertificateError => e
      @logger.error("❌ Invalid certificate: #{e.message}")
      EnsureValidCertificatesResult.new(
        success: false,
        error: e.message,
        error_type: :invalid_certificate,
        recovery_suggestion: "Check certificate validity and team ownership"
      )
      
    rescue => e
      @logger.error("❌ Unexpected error in certificate validation: #{e.message}")
      EnsureValidCertificatesResult.new(
        success: false,
        error: e.message,
        error_type: :unexpected_error,
        recovery_suggestion: "Review certificate configuration and Apple Developer Portal status"
      )
    end
  end
  
  private
  
  # Validate input request parameters
  def validate_request(request)
    raise ArgumentError, "Team ID is required" if request.team_id.nil? || request.team_id.empty?
    raise ArgumentError, "App identifier is required" if request.app_identifier.nil? || request.app_identifier.empty?
    raise ArgumentError, "Invalid team ID format" unless request.team_id.match?(/^[A-Z0-9]{10}$/)
  end
  
  # Analyze current certificate status for the team
  def analyze_team_certificates(team, request)
    @logger.info("🔍 Analyzing certificate status for team #{team.team_id}")
    
    # Get existing certificates for team
    existing_certificates = @certificate_repository.find_by_team(request.team_id)
    development_certs = existing_certificates.select(&:development?)
    distribution_certs = existing_certificates.select(&:distribution?)
    
    # Apply business rules for certificate validation
    {
      team: team,
      existing_development: development_certs,
      existing_distribution: distribution_certs,
      development_valid: development_certs.any? { |cert| cert.valid_for_team?(request.team_id) && !cert.expired? },
      distribution_valid: distribution_certs.any? { |cert| cert.valid_for_team?(request.team_id) && !cert.expired? },
      development_at_limit: Certificate.at_development_limit?(request.team_id),
      distribution_at_limit: Certificate.at_distribution_limit?(request.team_id)
    }
  end
  
  # Determine what certificate operations are required
  def determine_required_actions(certificate_status, request)
    actions = []
    
    # Business Logic: Development certificate requirements
    if !certificate_status[:development_valid]
      if certificate_status[:development_at_limit]
        actions << { type: :cleanup_development, reason: "At development certificate limit" }
      end
      actions << { type: :create_development, reason: "No valid development certificate" }
    end
    
    # Business Logic: Distribution certificate requirements  
    if !certificate_status[:distribution_valid]
      if certificate_status[:distribution_at_limit]
        actions << { type: :cleanup_distribution, reason: "At distribution certificate limit" }
      end
      actions << { type: :create_distribution, reason: "No valid distribution certificate" }
    end
    
    # Business Logic: Import existing certificates if available
    if request.certificates_directory && Dir.exist?(request.certificates_directory)
      actions << { type: :import_existing, reason: "Import certificates from directory" }
    end
    
    @logger.info("📋 Required certificate actions: #{actions.length}")
    actions.each { |action| @logger.info("   - #{action[:type]}: #{action[:reason]}") }
    
    actions
  end
  
  # Execute the required certificate operations
  def execute_certificate_operations(required_actions, request)
    @logger.info("⚙️ Executing certificate operations...")
    
    result = {
      development_certificate: nil,
      distribution_certificate: nil,
      actions_taken: []
    }
    
    required_actions.each do |action|
      case action[:type]
      when :cleanup_development
        execute_development_cleanup(request, result)
      when :cleanup_distribution
        execute_distribution_cleanup(request, result)
      when :import_existing
        execute_certificate_import(request, result)
      when :create_development
        execute_development_creation(request, result)
      when :create_distribution
        execute_distribution_creation(request, result)
      end
    end
    
    result
  end
  
  # Execute development certificate cleanup
  def execute_development_cleanup(request, result)
    @logger.info("🧹 Cleaning up development certificates...")
    
    cleanup_result = @certificate_repository.cleanup_development_certificates(request.team_id)
    result[:actions_taken] << {
      action: :cleanup_development,
      success: cleanup_result.success?,
      details: cleanup_result.details
    }
    
    @logger.info("✅ Development certificate cleanup completed") if cleanup_result.success?
  end
  
  # Execute distribution certificate cleanup
  def execute_distribution_cleanup(request, result)
    @logger.info("🧹 Cleaning up distribution certificates...")
    
    cleanup_result = @certificate_repository.cleanup_distribution_certificates(request.team_id)
    result[:actions_taken] << {
      action: :cleanup_distribution,
      success: cleanup_result.success?,
      details: cleanup_result.details
    }
    
    @logger.info("✅ Distribution certificate cleanup completed") if cleanup_result.success?
  end
  
  # Execute certificate import from directory
  def execute_certificate_import(request, result)
    @logger.info("📦 Importing existing certificates...")
    
    import_result = @certificate_repository.import_certificates_from_directory(request.certificates_directory)
    result[:actions_taken] << {
      action: :import_existing,
      success: import_result.success?,
      certificates_imported: import_result.certificates_imported,
      details: import_result.details
    }
    
    @logger.info("✅ Certificate import completed: #{import_result.certificates_imported} certificates") if import_result.success?
  end
  
  # Execute development certificate creation
  def execute_development_creation(request, result)
    @logger.info("📱 Creating development certificate...")
    
    certificate = @certificate_repository.create_development_certificate(
      team_id: request.team_id,
      app_identifier: request.app_identifier,
      output_path: request.certificates_directory
    )
    
    result[:development_certificate] = certificate
    result[:actions_taken] << {
      action: :create_development,
      success: true,
      certificate_id: certificate.certificate_id
    }
    
    @logger.info("✅ Development certificate created: #{certificate.certificate_id}")
  end
  
  # Execute distribution certificate creation
  def execute_distribution_creation(request, result)
    @logger.info("🏢 Creating distribution certificate...")
    
    certificate = @certificate_repository.create_distribution_certificate(
      team_id: request.team_id,
      app_identifier: request.app_identifier,
      output_path: request.certificates_directory
    )
    
    result[:distribution_certificate] = certificate
    result[:actions_taken] << {
      action: :create_distribution,
      success: true,
      certificate_id: certificate.certificate_id
    }
    
    @logger.info("✅ Distribution certificate created: #{certificate.certificate_id}")
  end
  
  # Validate final certificate state after operations
  def validate_final_certificate_state(request)
    @logger.info("🔍 Validating final certificate state...")
    
    certificates = @certificate_repository.find_by_team(request.team_id)
    development_valid = certificates.any? { |cert| cert.development? && cert.valid_for_team?(request.team_id) && !cert.expired? }
    distribution_valid = certificates.any? { |cert| cert.distribution? && cert.valid_for_team?(request.team_id) && !cert.expired? }
    
    validation_result = {
      development_certificate_valid: development_valid,
      distribution_certificate_valid: distribution_valid,
      total_certificates: certificates.length,
      ready_for_build: development_valid && distribution_valid
    }
    
    @logger.info("📊 Final validation: development=#{development_valid}, distribution=#{distribution_valid}")
    validation_result
  end
  
  # Suggest certificate cleanup strategy when limits exceeded
  def suggest_certificate_cleanup(team_id)
    certificates = @certificate_repository.find_by_team(team_id)
    cleanup_strategy = Certificate.cleanup_strategy(certificates)
    
    "Consider removing #{cleanup_strategy.certificates_to_remove.length} certificates: " \
    "#{cleanup_strategy.certificates_to_remove.map(&:name).join(', ')}"
  end
end

# Request object for EnsureValidCertificates use case
class EnsureValidCertificatesRequest
  attr_reader :team_id, :app_identifier, :certificates_directory, :force_recreate
  
  def initialize(team_id:, app_identifier:, certificates_directory: nil, force_recreate: false)
    @team_id = team_id
    @app_identifier = app_identifier
    @certificates_directory = certificates_directory
    @force_recreate = force_recreate
  end
end

# Result object for EnsureValidCertificates use case
class EnsureValidCertificatesResult
  attr_reader :success, :development_certificate, :distribution_certificate, 
              :actions_taken, :validation_result, :error, :error_type, :recovery_suggestion
  
  def initialize(success:, development_certificate: nil, distribution_certificate: nil,
                 actions_taken: [], validation_result: nil, error: nil, 
                 error_type: nil, recovery_suggestion: nil)
    @success = success
    @development_certificate = development_certificate
    @distribution_certificate = distribution_certificate
    @actions_taken = actions_taken
    @validation_result = validation_result
    @error = error
    @error_type = error_type
    @recovery_suggestion = recovery_suggestion
  end
  
  def success?
    @success
  end
  
  def ready_for_build?
    success? && @validation_result&.dig(:ready_for_build)
  end
end

# Custom exceptions for certificate management
class CertificateLimitExceededError < StandardError; end
class InvalidCertificateError < StandardError; end