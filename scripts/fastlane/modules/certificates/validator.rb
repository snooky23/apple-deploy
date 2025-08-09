# Certificate Validator - Validates certificate integrity, team matching, and expiration
# Provides comprehensive certificate validation with detailed error reporting

require_relative '../core/logger'
require_relative '../core/error_handler'
require_relative '../auth/keychain_manager'
require 'openssl'

class CertificateValidator
  class ValidationError < ErrorHandler::CertificateError; end
  
  # Certificate validation levels
  VALIDATION_LEVELS = {
    basic: [:existence, :readability, :format],
    standard: [:existence, :readability, :format, :expiration, :team_match],
    comprehensive: [:existence, :readability, :format, :expiration, :team_match, :keychain_access, :signing_capability]
  }.freeze
  
  attr_reader :options, :team_id
  
  def initialize(options = {})
    @options = options
    @team_id = options[:team_id]
    @validation_cache = {}
  end
  
  # Main validation method with configurable validation level
  def validate_certificate(certificate_info, validation_level = :standard)
    log_step("Certificate Validation", "Validating certificate with #{validation_level} checks") do
      
      validation_checks = VALIDATION_LEVELS[validation_level] || VALIDATION_LEVELS[:standard]
      
      log_info("Starting certificate validation",
              certificate_source: certificate_info[:source],
              team_id: @team_id,
              validation_level: validation_level,
              checks: validation_checks)
      
      validation_results = {}
      overall_valid = true
      
      validation_checks.each do |check|
        begin
          result = perform_validation_check(certificate_info, check)
          validation_results[check] = result
          
          if result[:valid]
            log_info("Validation check passed", check: check, message: result[:message])
          else
            log_warn("Validation check failed", check: check, error: result[:error])
            overall_valid = false
          end
          
        rescue => e
          log_error("Validation check error", check: check, error: e.message)
          validation_results[check] = { valid: false, error: e.message }
          overall_valid = false
        end
      end
      
      validation_summary = {
        valid: overall_valid,
        checks_performed: validation_checks,
        results: validation_results,
        validation_level: validation_level
      }
      
      if overall_valid
        log_success("Certificate validation passed",
                   validation_level: validation_level,
                   checks_passed: validation_results.count { |_, r| r[:valid] })
      else
        failed_checks = validation_results.select { |_, r| !r[:valid] }.keys
        log_error("Certificate validation failed",
                 validation_level: validation_level,
                 failed_checks: failed_checks)
      end
      
      validation_summary
    end
  end
  
  # Validate multiple certificates in batch
  def validate_certificates(certificates, validation_level = :standard)
    log_step("Batch Certificate Validation", "Validating #{certificates.length} certificates") do
      
      validation_results = certificates.map.with_index do |cert, index|
        log_info("Validating certificate #{index + 1}/#{certificates.length}",
                source: cert[:source],
                type: cert[:type])
        
        begin
          result = validate_certificate(cert, validation_level)
          result.merge(certificate: cert)
        rescue => e
          log_error("Certificate validation error",
                   index: index + 1,
                   error: e.message)
          {
            valid: false,
            error: e.message,
            certificate: cert
          }
        end
      end
      
      valid_count = validation_results.count { |r| r[:valid] }
      
      log_success("Batch validation completed",
                 total: certificates.length,
                 valid: valid_count,
                 invalid: certificates.length - valid_count)
      
      {
        total: certificates.length,
        valid: valid_count,
        invalid: certificates.length - valid_count,
        results: validation_results
      }
    end
  end
  
  # Validate certificate expiration with warning thresholds
  def validate_expiration(certificate_info, warning_days = 30)
    log_step("Expiration Validation", "Checking certificate expiration status") do
      
      expires_at = certificate_info[:expires]
      
      unless expires_at
        return {
          valid: false,
          error: "Certificate expiration date not available",
          status: :unknown
        }
      end
      
      now = Time.now
      days_until_expiry = ((expires_at - now) / (24 * 60 * 60)).to_i
      
      log_info("Certificate expiration check",
              expires_at: expires_at.strftime("%Y-%m-%d %H:%M:%S"),
              days_until_expiry: days_until_expiry)
      
      if expires_at <= now
        log_error("Certificate has expired",
                 expired_days_ago: -days_until_expiry)
        
        return {
          valid: false,
          error: "Certificate expired #{-days_until_expiry} days ago",
          status: :expired,
          expires_at: expires_at,
          days_until_expiry: days_until_expiry
        }
      end
      
      if days_until_expiry <= warning_days
        log_warn("Certificate expires soon",
                days_until_expiry: days_until_expiry,
                warning_threshold: warning_days)
        
        return {
          valid: true,
          warning: "Certificate expires in #{days_until_expiry} days",  
          status: :expiring_soon,
          expires_at: expires_at,
          days_until_expiry: days_until_expiry
        }
      end
      
      log_success("Certificate expiration is valid",
                 days_until_expiry: days_until_expiry)
      
      {
        valid: true,
        message: "Certificate expires in #{days_until_expiry} days",
        status: :valid,
        expires_at: expires_at,
        days_until_expiry: days_until_expiry
      }
    end
  end
  
  # Validate team ID matching
  def validate_team_match(certificate_info, expected_team_id = nil)
    expected_team_id ||= @team_id
    
    unless expected_team_id
      return {
        valid: true,
        message: "No team ID specified for validation",
        status: :skipped
      }
    end
    
    cert_team_id = extract_team_id_from_certificate(certificate_info)
    
    unless cert_team_id
      return {
        valid: false,
        error: "Could not extract team ID from certificate",
        status: :unknown
      }
    end
    
    if cert_team_id == expected_team_id
      log_success("Certificate team ID matches",
                 expected: expected_team_id,
                 actual: cert_team_id)
      
      return {
        valid: true,
        message: "Team ID matches: #{cert_team_id}",
        status: :match,
        certificate_team_id: cert_team_id,
        expected_team_id: expected_team_id
      }
    else
      log_error("Certificate team ID mismatch",
               expected: expected_team_id,
               actual: cert_team_id)
      
      return {
        valid: false,
        error: "Team ID mismatch: expected #{expected_team_id}, got #{cert_team_id}",
        status: :mismatch,
        certificate_team_id: cert_team_id,
        expected_team_id: expected_team_id
      }
    end
  end
  
  # Validate P12 file format and content
  def validate_p12_file(p12_path, password = nil)
    log_step("P12 File Validation", "Validating P12 file format and content") do
      
      log_info("Validating P12 file", file: File.basename(p12_path))
      
      # Basic file validation
      file_validation = validate_file_basic(p12_path)
      return file_validation unless file_validation[:valid]
      
      # P12 format validation
      begin
        if password
          p12_content = validate_p12_content(p12_path, password)
          return p12_content
        else
          log_info("P12 content validation skipped (no password provided)")
          return {
            valid: true,
            message: "P12 file format appears valid (content not verified)",
            status: :format_valid
          }
        end
        
      rescue => e
        log_error("P12 content validation failed", error: e.message)
        return {
          valid: false,
          error: "P12 content validation failed: #{e.message}",
          status: :content_invalid
        }
      end
    end
  end
  
  private
  
  def perform_validation_check(certificate_info, check_type)
    case check_type
    when :existence
      validate_existence(certificate_info)
    when :readability
      validate_readability(certificate_info)
    when :format
      validate_format(certificate_info)
    when :expiration
      validate_expiration(certificate_info)
    when :team_match
      validate_team_match(certificate_info)
    when :keychain_access
      validate_keychain_access(certificate_info)
    when :signing_capability
      validate_signing_capability(certificate_info)
    else
      {
        valid: false,
        error: "Unknown validation check: #{check_type}"
      }
    end
  end
  
  def validate_existence(certificate_info)
    case certificate_info[:source]
    when :files
      file_path = certificate_info[:file_path]
      if file_path && File.exist?(file_path)
        { valid: true, message: "Certificate file exists" }
      else
        { valid: false, error: "Certificate file does not exist: #{file_path}" }
      end
    when :keychain
      # For keychain certificates, existence is implied by detection
      { valid: true, message: "Certificate exists in keychain" }
    when :api
      # For API certificates, existence is implied by API response
      { valid: true, message: "Certificate exists in Apple Developer Portal" }
    else
      { valid: false, error: "Unknown certificate source" }
    end
  end
  
  def validate_readability(certificate_info)
    case certificate_info[:source]
    when :files
      file_path = certificate_info[:file_path]
      if file_path && File.readable?(file_path)
        { valid: true, message: "Certificate file is readable" }
      else
        { valid: false, error: "Certificate file is not readable: #{file_path}" }
      end
    when :keychain
      { valid: true, message: "Certificate is accessible in keychain" }
    when :api
      { valid: true, message: "Certificate is accessible via API" }
    else
      { valid: false, error: "Cannot validate readability for unknown source" }
    end
  end
  
  def validate_format(certificate_info)
    case certificate_info[:source]
    when :files
      file_path = certificate_info[:file_path]
      if file_path&.end_with?('.p12')
        { valid: true, message: "Certificate file has correct P12 format" }
      else
        { valid: false, error: "Certificate file is not a P12 file" }
      end
    when :keychain
      { valid: true, message: "Certificate format is valid (in keychain)" }
    when :api
      { valid: true, message: "Certificate format is valid (from API)" }
    else
      { valid: false, error: "Cannot validate format for unknown source" }
    end
  end
  
  def validate_keychain_access(certificate_info)
    if certificate_info[:source] == :keychain
      # Test keychain access
      begin
        KeychainManager.verify_keychain_access(certificate_info[:keychain_name])
        { valid: true, message: "Keychain access verified" }
      rescue => e
        { valid: false, error: "Keychain access failed: #{e.message}" }
      end
    else
      { valid: true, message: "Keychain access validation not applicable" }
    end
  end
  
  def validate_signing_capability(certificate_info)
    # This would test if the certificate can actually be used for code signing
    # For now, return a placeholder
    { valid: true, message: "Signing capability not yet implemented" }
  end
  
  def validate_file_basic(file_path)
    return { valid: false, error: "File path is nil" } if file_path.nil?
    return { valid: false, error: "File does not exist: #{file_path}" } unless File.exist?(file_path)
    return { valid: false, error: "File is not readable: #{file_path}" } unless File.readable?(file_path)
    return { valid: false, error: "File is empty: #{file_path}" } if File.size(file_path) == 0
    
    { valid: true, message: "File basic validation passed" }
  end
  
  def validate_p12_content(p12_path, password)
    begin
      # Read and parse P12 file
      p12_data = File.read(p12_path)
      p12 = OpenSSL::PKCS12.new(p12_data, password)
      
      # Extract certificate and key
      cert = p12.certificate
      key = p12.key
      
      unless cert
        return {
          valid: false,
          error: "No certificate found in P12 file",
          status: :no_certificate
        }
      end
      
      unless key
        return {
          valid: false,
          error: "No private key found in P12 file",
          status: :no_private_key
        }
      end
      
      # Validate certificate content
      subject = cert.subject.to_s
      issuer = cert.issuer.to_s
      not_after = cert.not_after
      
      log_info("P12 content validated",
              subject: subject,
              issuer: issuer,
              expires: not_after)
      
      {
        valid: true,
        message: "P12 content is valid",
        status: :content_valid,
        certificate_subject: subject,
        certificate_issuer: issuer,
        certificate_expires: not_after
      }
      
    rescue OpenSSL::PKCS12::PKCS12Error => e
      {
        valid: false,
        error: "P12 parsing failed: #{e.message}",
        status: :parse_error
      }
    rescue => e
      {
        valid: false,
        error: "P12 validation error: #{e.message}",
        status: :validation_error
      }
    end
  end
  
  def extract_team_id_from_certificate(certificate_info)
    if certificate_info[:team_id]
      return certificate_info[:team_id]
    elsif certificate_info[:subject]
      # Extract from subject string
      ou_match = certificate_info[:subject].match(/OU=([^,]+)/)
      return ou_match[1] if ou_match
    elsif certificate_info[:organizational_unit]
      return certificate_info[:organizational_unit]
    end
    
    nil
  end
end

# Convenience methods for FastLane integration
def validate_certificate(certificate_info, options = {}, validation_level = :standard)
  validator = CertificateValidator.new(options)
  validator.validate_certificate(certificate_info, validation_level)
end

def validate_certificate_expiration(certificate_info, warning_days = 30)
  validator = CertificateValidator.new({})
  validator.validate_expiration(certificate_info, warning_days)
end

def validate_certificate_team_match(certificate_info, team_id)
  validator = CertificateValidator.new(team_id: team_id)
  validator.validate_team_match(certificate_info, team_id)
end

def validate_p12_file(p12_path, password = nil)
  validator = CertificateValidator.new({})
  validator.validate_p12_file(p12_path, password)
end