# Create Certificates Use Case - Clean Architecture Domain Layer
# Business workflow: Create Apple Developer certificates (development and distribution)

require_relative '../../fastlane/modules/core/logger'
require_relative '../../infrastructure/apple_api/certificates_api'

class CreateCertificatesRequest
  attr_reader :team_id, :apple_id, :keychain_path, :keychain_password, :output_path, :create_development, :create_distribution
  
  def initialize(team_id:, apple_id:, keychain_path:, keychain_password:, output_path:, create_development: true, create_distribution: true)
    @team_id = team_id
    @apple_id = apple_id
    @keychain_path = keychain_path
    @keychain_password = keychain_password
    @output_path = output_path
    @create_development = create_development
    @create_distribution = create_distribution
    
    validate_request
  end
  
  private
  
  def validate_request
    raise ArgumentError, "team_id cannot be nil or empty" if @team_id.nil? || @team_id.empty?
    raise ArgumentError, "apple_id cannot be nil or empty" if @apple_id.nil? || @apple_id.empty?
    raise ArgumentError, "keychain_path cannot be nil or empty" if @keychain_path.nil? || @keychain_path.empty?
    raise ArgumentError, "keychain_password cannot be nil or empty" if @keychain_password.nil? || @keychain_password.empty?
    raise ArgumentError, "output_path cannot be nil or empty" if @output_path.nil? || @output_path.empty?
    raise ArgumentError, "output_path must be a valid directory" unless Dir.exist?(File.dirname(@output_path))
    raise ArgumentError, "keychain_path must exist" unless File.exist?(@keychain_path)
  end
end

class CreateCertificatesResult
  attr_reader :success, :created_certificates, :error, :error_type, :recovery_suggestion
  
  def initialize(success:, created_certificates: [], error: nil, error_type: nil, recovery_suggestion: nil)
    @success = success
    @created_certificates = created_certificates
    @error = error
    @error_type = error_type
    @recovery_suggestion = recovery_suggestion
  end
  
  def development_certificate_created?
    @created_certificates.any? { |cert| cert[:type] == :development }
  end
  
  def distribution_certificate_created?
    @created_certificates.any? { |cert| cert[:type] == :distribution }
  end
  
  def development_certificates_count
    @created_certificates.count { |cert| cert[:type] == :development }
  end
  
  def distribution_certificates_count
    @created_certificates.count { |cert| cert[:type] == :distribution }
  end
  
  def development_certificates
    @created_certificates.select { |cert| cert[:type] == :development }
  end
  
  def distribution_certificates
    @created_certificates.select { |cert| cert[:type] == :distribution }
  end
end

class CreateCertificates
  def initialize(logger: FastlaneLogger, certificates_api: nil)
    @logger = logger
    @certificates_api = certificates_api || CertificatesAPI.new(logger: logger)
  end
  
  # Execute the use case to create Apple Developer certificates
  # @param request [CreateCertificatesRequest] Input parameters
  # @return [CreateCertificatesResult] Result with created certificate information
  def execute(request)
    @logger.step("Creating Apple Developer certificates")
    
    begin
      created_certificates = []
      
      # Business Logic: Create development certificate if requested
      if request.create_development
        development_cert = create_development_certificate(request)
        created_certificates << development_cert if development_cert
      end
      
      # Business Logic: Create distribution certificate if requested  
      if request.create_distribution
        distribution_cert = create_distribution_certificate(request)
        created_certificates << distribution_cert if distribution_cert
      end
      
      if created_certificates.empty?
        @logger.warn("No certificates were created")
        CreateCertificatesResult.new(
          success: false,
          error: "No certificates were created",
          error_type: :certificate_creation_failed,
          recovery_suggestion: "Check Apple Developer Portal limits and account permissions"
        )
      else
        @logger.success("Certificate creation completed successfully")
        @logger.info("Created #{created_certificates.size} certificates")
        
        CreateCertificatesResult.new(
          success: true,
          created_certificates: created_certificates
        )
      end
      
    rescue CertificateCreationError => e
      @logger.error("Certificate creation failed: #{e.message}")
      CreateCertificatesResult.new(
        success: false,
        error: e.message,
        error_type: :certificate_creation_failed,
        recovery_suggestion: "Check Apple Developer account permissions and certificate limits"
      )
      
    rescue => e
      @logger.error("Unexpected error during certificate creation: #{e.message}")
      CreateCertificatesResult.new(
        success: false,
        error: e.message,
        error_type: :unexpected_error,
        recovery_suggestion: "Check Apple Developer Portal connectivity and account status"
      )
    end
  end
  
  private
  
  def create_development_certificate(request)
    @logger.info("Creating Development Certificate via API adapter...")
    
    begin
      # Use CertificatesAPI adapter to create development certificate
      result = @certificates_api.create_development_certificate(
        team_id: request.team_id,
        username: request.apple_id,
        keychain_path: request.keychain_path,
        keychain_password: request.keychain_password,
        output_path: request.output_path
      )
      
      if result[:success]
        @logger.success("✅ Development certificate created in #{request.output_path}")
        {
          type: :development,
          team_id: request.team_id,
          output_path: request.output_path,
          certificate_id: result[:certificate_id],
          certificate_path: result[:certificate_path],
          created_at: result[:created_at]
        }
      else
        @logger.warn("Development certificate creation failed: #{result[:error]}")
        nil
      end
      
    rescue => e
      @logger.warn("⚠️  Development certificate creation failed: #{e.message}")
      @logger.info("💡 Continuing without development certificate...")
      nil
    end
  end
  
  def create_distribution_certificate(request)
    @logger.info("Creating Distribution Certificate via API adapter...")
    
    begin
      # Use CertificatesAPI adapter to create distribution certificate
      result = @certificates_api.create_distribution_certificate(
        team_id: request.team_id,
        username: request.apple_id,
        keychain_path: request.keychain_path,
        keychain_password: request.keychain_password,
        output_path: request.output_path
      )
      
      if result[:success]
        @logger.success("✅ Distribution certificate created in #{request.output_path}")
        {
          type: :distribution,
          team_id: request.team_id,
          output_path: request.output_path,
          certificate_id: result[:certificate_id],
          certificate_path: result[:certificate_path],
          created_at: result[:created_at]
        }
      else
        @logger.error("❌ Distribution certificate creation failed: #{result[:error]}")
        raise CertificateCreationError.new("Distribution certificate creation failed: #{result[:error]}")
      end
      
    rescue CertificateCreationError
      raise
    rescue => e
      @logger.error("❌ Distribution certificate creation failed: #{e.message}")
      @logger.info("💡 Trying to continue with existing certificates in keychain...")
      raise CertificateCreationError.new("Distribution certificate creation failed: #{e.message}")
    end
  end
  
end

# Custom exception for certificate creation operations
class CertificateCreationError < StandardError; end