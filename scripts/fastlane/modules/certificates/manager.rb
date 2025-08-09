# Certificate Manager - Orchestrates complete certificate lifecycle management
# Integrates detection, import, validation, and cleanup operations

require_relative '../core/logger'
require_relative '../core/error_handler'
require_relative 'detector'
require_relative 'importer'
require_relative 'validator'

class CertificateManager
  class CertificateError < ErrorHandler::CertificateError; end
  
  attr_reader :options, :detector, :importer, :validator
  
  def initialize(options = {})
    @options = options
    @detector = CertificateDetector.new(options)
    @importer = CertificateImporter.new(options)
    @validator = CertificateValidator.new(options)
    @managed_certificates = {}
  end
  
  # Main certificate management method - ensures certificates are available and valid
  def ensure_certificates_available(required_types = ['development', 'distribution'])
    log_step("Certificate Management", "Ensuring all required certificates are available") do
      
      log_info("Starting certificate management",
              required_types: required_types,
              team_id: @options[:team_id])
      
      certificate_status = {}
      
      required_types.each do |cert_type|
        log_info("Processing certificate type", type: cert_type)
        
        begin
          cert_status = ensure_certificate_type_available(cert_type)
          certificate_status[cert_type] = cert_status
          
          if cert_status[:available]
            log_success("Certificate type is available",
                       type: cert_type,
                       source: cert_status[:source])
          else
            log_error("Certificate type is not available",
                     type: cert_type,
                     reason: cert_status[:reason])
          end
          
        rescue => e
          log_error("Certificate type processing failed",
                   type: cert_type,
                   error: e.message)
          
          certificate_status[cert_type] = {
            available: false,
            reason: e.message,
            error: e
          }
        end
      end
      
      # Overall status
      all_available = certificate_status.values.all? { |status| status[:available] }
      
      if all_available
        log_success("All required certificates are available",
                   types: required_types,
                   sources: certificate_status.values.map { |s| s[:source] }.uniq)
      else
        missing_types = certificate_status.select { |_, status| !status[:available] }.keys
        
        raise CertificateError.new(
          "Required certificates are not available: #{missing_types.join(', ')}",
          error_code: 'CERTIFICATES_NOT_AVAILABLE',
          recovery_suggestions: [
            "Check P12 files are present in certificates directory",
            "Verify P12 passwords are correct",
            "Create certificates via Apple Developer Portal",
            "Import certificates manually to keychain"
          ],
          context: { 
            missing_types: missing_types,
            certificate_status: certificate_status
          }
        )
      end
      
      certificate_status
    end
  end
  
  # Ensure a specific certificate type is available
  def ensure_certificate_type_available(certificate_type)
    log_step("Certificate Type Management", "Ensuring #{certificate_type} certificate is available") do
      
      # Step 1: Detect existing certificates
      certificates = @detector.detect_certificates(certificate_type)
      
      if certificates.empty?
        log_warn("No certificates found for type", type: certificate_type)
        return attempt_certificate_creation(certificate_type)
      end
      
      # Step 2: Validate the best certificate
      best_certificate = certificates.first
      validation_result = @validator.validate_certificate(best_certificate, :standard)
      
      if validation_result[:valid]
        log_success("Valid certificate found",
                   type: certificate_type,
                   source: best_certificate[:source])
        
        # Ensure certificate is imported to keychain if needed
        if best_certificate[:source] == :files
          ensure_certificate_imported(best_certificate, certificate_type)
        end
        
        @managed_certificates[certificate_type] = best_certificate
        
        return {
          available: true,
          certificate: best_certificate,
          source: best_certificate[:source],
          validation: validation_result
        }
      else
        log_warn("Certificate validation failed",
                type: certificate_type,
                failed_checks: validation_result[:results].select { |_, r| !r[:valid] }.keys)
        
        # Attempt to fix or recreate certificate
        return attempt_certificate_recovery(best_certificate, certificate_type, validation_result)
      end
    end
  end
  
  # Import P12 certificates from files directory
  def import_certificates_from_files(password_map = {})
    log_step("Certificate Import from Files", "Importing P12 certificates from files directory") do
      
      # Use auto-import functionality
      import_result = @importer.auto_import_certificates(password_map)
      
      if import_result[:successful] > 0
        log_success("Certificates imported successfully",
                   successful: import_result[:successful],
                   failed: import_result[:failed])
        
        # Clear detection cache to pick up newly imported certificates
        @detector.clear_cache
      else
        log_warn("No certificates were imported",
                failed: import_result[:failed],
                total: import_result[:total])
      end
      
      import_result
    end
  end
  
  # Validate all managed certificates
  def validate_all_certificates(validation_level = :standard)
    log_step("Certificate Validation", "Validating all managed certificates") do
      
      if @managed_certificates.empty?
        log_info("No managed certificates to validate")
        return { valid: true, certificates: [] }
      end
      
      validation_results = {}
      all_valid = true
      
      @managed_certificates.each do |cert_type, certificate|
        log_info("Validating certificate", type: cert_type)
        
        result = @validator.validate_certificate(certificate, validation_level)
        validation_results[cert_type] = result
        
        unless result[:valid]
          all_valid = false
          log_warn("Certificate validation failed",
                  type: cert_type,
                  failed_checks: result[:results].select { |_, r| !r[:valid] }.keys)
        end
      end
      
      if all_valid
        log_success("All certificates are valid",
                   certificates: @managed_certificates.keys)
      else
        invalid_types = validation_results.select { |_, r| !r[:valid] }.keys
        log_error("Some certificates are invalid", invalid_types: invalid_types)
      end
      
      {
        valid: all_valid,
        certificates: validation_results,
        invalid_types: validation_results.select { |_, r| !r[:valid] }.keys
      }
    end
  end
  
  # Clean up expired or invalid certificates
  def cleanup_certificates(dry_run: false)
    log_step("Certificate Cleanup", "Cleaning up expired and invalid certificates") do
      
      log_info("Starting certificate cleanup", dry_run: dry_run)
      
      cleanup_results = {
        keychain_cleaned: 0,
        files_cleaned: 0,
        errors: []
      }
      
      # Clean up keychain certificates
      begin
        keychain_cleaned = KeychainManager.cleanup_expired_certificates
        cleanup_results[:keychain_cleaned] = keychain_cleaned
        
        log_info("Keychain cleanup completed", removed: keychain_cleaned)
        
      rescue => e
        log_error("Keychain cleanup failed", error: e.message)
        cleanup_results[:errors] << { source: :keychain, error: e.message }
      end
      
      # Clean up certificate files (optional)
      if @options[:cleanup_files]
        begin
          files_cleaned = cleanup_certificate_files(dry_run)
          cleanup_results[:files_cleaned] = files_cleaned
          
        rescue => e
          log_error("File cleanup failed", error: e.message)
          cleanup_results[:errors] << { source: :files, error: e.message }
        end
      end
      
      log_success("Certificate cleanup completed",
                 keychain_cleaned: cleanup_results[:keychain_cleaned],
                 files_cleaned: cleanup_results[:files_cleaned],
                 errors: cleanup_results[:errors].length)
      
      cleanup_results
    end
  end
  
  # Get status of all certificate types
  def get_certificate_status(certificate_types = ['development', 'distribution'])
    log_step("Certificate Status Check", "Checking status of all certificate types") do
      
      status_results = {}
      
      certificate_types.each do |cert_type|
        begin
          certificates = @detector.detect_certificates(cert_type)
          
          if certificates.empty?
            status_results[cert_type] = {
              available: false,
              count: 0,
              source: nil,
              status: :not_found
            }
          else
            best_cert = certificates.first
            validation = @validator.validate_certificate(best_cert, :basic)
            
            status_results[cert_type] = {
              available: validation[:valid],
              count: certificates.length,
              source: best_cert[:source],
              status: validation[:valid] ? :valid : :invalid,
              expires: best_cert[:expires],
              validation: validation
            }
          end
          
        rescue => e
          status_results[cert_type] = {
            available: false,
            count: 0,
            source: nil,
            status: :error,
            error: e.message
          }
        end
      end
      
      log_success("Certificate status check completed",
                 types_checked: certificate_types.length,
                 available_count: status_results.values.count { |s| s[:available] })
      
      status_results
    end
  end
  
  # Get managed certificates
  def get_managed_certificates
    @managed_certificates
  end
  
  # Reset certificate management state
  def reset_state
    @managed_certificates.clear
    @detector.clear_cache
    @importer.clear_import_history
    
    log_info("Certificate manager state reset")
  end
  
  private
  
  def ensure_certificate_imported(certificate, certificate_type)
    return unless certificate[:source] == :files && certificate[:file_path]
    
    log_info("Ensuring certificate is imported to keychain",
            file: File.basename(certificate[:file_path]))
    
    # Check if already imported by validating keychain access
    if @validator.validate_certificate(certificate, :keychain_access)[:valid]
      log_info("Certificate is already accessible in keychain")
      return
    end
    
    # Import the certificate
    password = @options[:p12_password]
    
    unless password
      log_warn("Cannot import certificate: no P12 password provided")
      return
    end
    
    begin
      @importer.import_p12_certificate(
        certificate[:file_path],
        password,
        certificate_type
      )
      
      log_success("Certificate imported to keychain",
                 file: File.basename(certificate[:file_path]))
      
    rescue => e
      log_error("Certificate import failed",
               file: File.basename(certificate[:file_path]),
               error: e.message)
    end
  end
  
  def attempt_certificate_creation(certificate_type)
    log_info("Attempting to create certificate via API", type: certificate_type)
    
    begin
      # Create certificate using FastLane cert action
      if certificate_type == "distribution"
        log_info("Creating App Store distribution certificate")
        
        # Create API key hash instead of passing file path
        api_key_hash = {
          key_id: @options[:api_key_id],
          issuer_id: @options[:api_issuer_id],
          key_filepath: @options[:api_key_path]
        }
        
        cert_result = Fastlane::Actions::CertAction.run(
          development: false,
          output_path: File.join(@options[:certificates_dir], ""),
          api_key: api_key_hash
        )
        
        if cert_result
          log_success("Distribution certificate created successfully")
          return {
            available: true,
            reason: "Certificate created via API",
            source: :api,
            path: cert_result
          }
        end
        
      elsif certificate_type == "development"
        log_info("Creating development certificate")
        
        # Create API key hash instead of passing file path
        api_key_hash = {
          key_id: @options[:api_key_id],
          issuer_id: @options[:api_issuer_id],
          key_filepath: @options[:api_key_path]
        }
        
        cert_result = Fastlane::Actions::CertAction.run(
          development: true,
          output_path: File.join(@options[:certificates_dir], ""),
          api_key: api_key_hash
        )
        
        if cert_result
          log_success("Development certificate created successfully")
          return {
            available: true,
            reason: "Certificate created via API",
            source: :api,
            path: cert_result
          }
        end
      end
      
    rescue => e
      log_error("Certificate creation failed", 
               type: certificate_type,
               error: e.message)
    end
    
    {
      available: false,
      reason: "Certificate creation failed",
      source: nil
    }
  end
  
  def attempt_certificate_recovery(certificate, certificate_type, validation_result)
    log_info("Attempting certificate recovery",
            type: certificate_type,
            source: certificate[:source])
    
    # Try different recovery strategies based on validation failures
    failed_checks = validation_result[:results].select { |_, r| !r[:valid] }.keys
    
    if failed_checks.include?(:expiration)
      log_info("Certificate is expired, attempting to find or create new certificate")
      return attempt_certificate_creation(certificate_type)
    end
    
    if failed_checks.include?(:team_match)
      log_warn("Certificate team ID mismatch, cannot recover automatically")
      return {
        available: false,
        reason: "Certificate team ID does not match expected team ID",
        source: certificate[:source]
      }
    end
    
    if failed_checks.include?(:keychain_access) && certificate[:source] == :files
      log_info("Attempting to re-import certificate to fix keychain access")
      
      password = @options[:p12_password]
      if password
        begin
          @importer.reimport_certificate(certificate, password)
          
          # Re-validate after import
          new_validation = @validator.validate_certificate(certificate, :standard)
          
          return {
            available: new_validation[:valid],
            reason: new_validation[:valid] ? "Certificate re-imported successfully" : "Re-import validation failed",
            source: certificate[:source],
            validation: new_validation
          }
          
        rescue => e
          return {
            available: false,
            reason: "Certificate re-import failed: #{e.message}",
            source: certificate[:source]
          }
        end
      else
        return {
          available: false,
          reason: "Cannot re-import certificate: no P12 password provided",
          source: certificate[:source]
        }
      end
    end
    
    {
      available: false,
      reason: "Certificate recovery not possible for failed checks: #{failed_checks.join(', ')}",
      source: certificate[:source]
    }
  end
  
  def cleanup_certificate_files(dry_run)
    # This would implement cleanup of old/invalid certificate files
    # For now, return 0
    0
  end
end

# Convenience methods for FastLane integration
def ensure_certificates_available(options, required_types = ['development', 'distribution'])
  manager = CertificateManager.new(options)
  manager.ensure_certificates_available(required_types)
end

def import_certificates_from_files(options, password_map = {})
  manager = CertificateManager.new(options)
  manager.import_certificates_from_files(password_map)
end

def get_certificate_status(options, certificate_types = ['development', 'distribution'])
  manager = CertificateManager.new(options)
  manager.get_certificate_status(certificate_types)
end

def cleanup_certificates(options, dry_run: false)
  manager = CertificateManager.new(options)
  manager.cleanup_certificates(dry_run: dry_run)
end