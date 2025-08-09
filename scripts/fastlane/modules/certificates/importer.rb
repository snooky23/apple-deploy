# Certificate Importer - Handles P12 certificate import with comprehensive error handling
# Provides secure import operations with keychain management and validation

require_relative '../core/logger'
require_relative '../core/error_handler'
require_relative '../auth/keychain_manager'
require_relative '../utils/file_utils'

class CertificateImporter
  class ImportError < ErrorHandler::CertificateError; end
  
  attr_reader :options, :keychain_name
  
  def initialize(options = {})
    @options = options
    @keychain_name = options[:keychain_name] || KeychainManager::DEFAULT_KEYCHAIN
    @team_id = options[:team_id]
    @import_history = []
  end
  
  # Import P12 certificate with comprehensive validation and error handling
  def import_p12_certificate(p12_path, password, certificate_type = 'development')
    log_step("P12 Certificate Import", "Importing #{certificate_type} certificate from P12 file") do
      
      # Pre-import validation
      validate_import_parameters(p12_path, password)
      validate_p12_file(p12_path)
      
      log_info("Starting P12 import",
              file: File.basename(p12_path),
              type: certificate_type,
              keychain: @keychain_name,
              team_id: @team_id)
      
      import_result = perform_p12_import(p12_path, password, certificate_type)
      
      # Post-import validation
      validate_import_success(import_result, certificate_type)
      
      # Record import history
      record_import(p12_path, certificate_type, import_result)
      
      log_success("P12 certificate import completed successfully",
                 file: File.basename(p12_path),
                 certificates_imported: import_result[:certificates_imported],
                 keychain: @keychain_name)
      
      import_result
    end
  end
  
  # Import multiple P12 certificates in batch
  def import_multiple_certificates(certificate_configs)
    log_step("Batch Certificate Import", "Importing #{certificate_configs.length} certificates") do
      
      import_results = []
      successful_imports = 0
      
      certificate_configs.each_with_index do |config, index|
        begin
          log_info("Importing certificate #{index + 1}/#{certificate_configs.length}",
                  file: File.basename(config[:p12_path]),
                  type: config[:certificate_type])
          
          result = import_p12_certificate(
            config[:p12_path],
            config[:password],
            config[:certificate_type]
          )
          
          import_results << result
          successful_imports += 1
          
        rescue ImportError => e
          log_error("Certificate import failed",
                   file: File.basename(config[:p12_path]),
                   error: e.message)
          
          import_results << {
            success: false,
            error: e.message,
            file: config[:p12_path]
          }
          
          # Continue with remaining certificates
        end
      end
      
      log_success("Batch import completed",
                 total: certificate_configs.length,
                 successful: successful_imports,
                 failed: certificate_configs.length - successful_imports)
      
      {
        total: certificate_configs.length,
        successful: successful_imports,
        failed: certificate_configs.length - successful_imports,
        results: import_results
      }
    end
  end
  
  # Auto-import certificates from detected P12 files
  def auto_import_certificates(password_map = {})
    log_step("Auto Certificate Import", "Automatically importing detected P12 certificates") do
      
      # Detect available P12 files
      certificates_dir = resolve_certificates_directory
      p12_files = find_p12_files(certificates_dir)
      
      if p12_files.empty?
        log_info("No P12 certificates found for auto-import")
        return { total: 0, successful: 0, failed: 0, results: [] }
      end
      
      log_info("Found P12 certificates for auto-import", count: p12_files.length)
      
      # Build import configurations
      import_configs = p12_files.map do |p12_path|
        {
          p12_path: p12_path,
          password: determine_p12_password(p12_path, password_map),
          certificate_type: infer_certificate_type(p12_path)
        }
      end
      
      # Filter out files without passwords
      valid_configs = import_configs.select { |config| config[:password] }
      
      if valid_configs.empty?
        log_warn("No P12 passwords available for auto-import")
        return { total: 0, successful: 0, failed: 0, results: [] }
      end
      
      # Import certificates
      import_multiple_certificates(valid_configs)
    end
  end
  
  # Re-import certificate (useful for fixing keychain issues)
  def reimport_certificate(certificate_info, password)
    log_step("Certificate Re-import", "Re-importing certificate to fix keychain issues") do
      
      if certificate_info[:source] == :files && certificate_info[:file_path]
        log_info("Re-importing certificate from file",
                file: File.basename(certificate_info[:file_path]))
        
        import_p12_certificate(
          certificate_info[:file_path],
          password,
          certificate_info[:type]
        )
      else
        raise ImportError.new(
          "Certificate cannot be re-imported: no file source available",
          error_code: 'REIMPORT_NOT_SUPPORTED'
        )
      end
    end
  end
  
  # Verify imported certificates are accessible
  def verify_imported_certificates(certificate_type = nil)
    log_step("Import Verification", "Verifying imported certificates are accessible") do
      
      log_info("Verifying certificate access in keychain", keychain: @keychain_name)
      
      # List certificates in keychain
      certificates = KeychainManager.list_certificates(@keychain_name, certificate_type)
      
      # Filter by team ID if specified
      if @team_id
        team_certificates = certificates.select do |cert|
          cert[:subject]&.include?(@team_id) || cert[:organizational_unit]&.include?(@team_id)
        end
      else
        team_certificates = certificates
      end
      
      if team_certificates.empty?
        log_warn("No matching certificates found in keychain after import",
                team_id: @team_id,
                type: certificate_type)
        return false
      end
      
      # Check certificate validity
      valid_certificates = team_certificates.select do |cert|
        cert[:expires] && cert[:expires] > Time.now
      end
      
      if valid_certificates.empty?
        log_warn("All imported certificates are expired",
                total_certificates: team_certificates.length)
        return false
      end
      
      log_success("Certificate import verification successful",
                 total_certificates: team_certificates.length,
                 valid_certificates: valid_certificates.length)
      
      true
    end
  end
  
  # Get import history
  def get_import_history
    @import_history
  end
  
  # Clear import history
  def clear_import_history
    @import_history.clear
  end
  
  private
  
  def validate_import_parameters(p12_path, password)
    missing_params = []
    missing_params << 'p12_path' if p12_path.nil? || p12_path.empty?
    missing_params << 'password' if password.nil? || password.empty?
    
    unless missing_params.empty?
      raise ImportError.new(
        "Missing required import parameters: #{missing_params.join(', ')}",
        error_code: 'MISSING_IMPORT_PARAMETERS'
      )
    end
  end
  
  def validate_p12_file(p12_path)
    # File existence
    unless File.exist?(p12_path)
      raise ImportError.new(
        "P12 file not found: #{p12_path}",
        error_code: 'P12_FILE_NOT_FOUND'
      )
    end
    
    # File readability
    unless File.readable?(p12_path)
      raise ImportError.new(
        "P12 file is not readable: #{p12_path}",
        error_code: 'P12_FILE_NOT_READABLE'
      )
    end
    
    # File extension
    unless p12_path.end_with?('.p12')
      raise ImportError.new(
        "Invalid file extension: expected .p12, got #{File.extname(p12_path)}",
        error_code: 'INVALID_P12_EXTENSION'
      )
    end
    
    # File size validation (not empty, not too large)
    file_size = File.size(p12_path)
    if file_size == 0
      raise ImportError.new(
        "P12 file is empty: #{p12_path}",
        error_code: 'P12_FILE_EMPTY'
      )
    end
    
    if file_size > 50 * 1024 * 1024 # 50MB limit
      raise ImportError.new(
        "P12 file is too large: #{file_size} bytes (max 50MB)",
        error_code: 'P12_FILE_TOO_LARGE'
      )
    end
    
    log_info("P12 file validation passed",
            file: File.basename(p12_path),
            size: "#{(file_size / 1024.0).round(1)}KB")
  end
  
  def perform_p12_import(p12_path, password, certificate_type)
    log_info("Performing P12 import operation")
    
    begin
      # Ensure keychain is properly set up
      KeychainManager.unlock_keychain(@keychain_name)
      
      # Import the P12 certificate
      KeychainManager.import_p12_certificate(p12_path, password, @keychain_name)
      
      # Set up keychain access permissions
      KeychainManager.setup_partition_list(@keychain_name)
      
      {
        success: true,
        certificates_imported: 1, # Would be parsed from actual import output
        keychain: @keychain_name,
        import_time: Time.now
      }
      
    rescue => e
      log_error("P12 import operation failed", error: e.message)
      
      raise ImportError.new(
        "P12 import failed: #{e.message}",
        error_code: 'P12_IMPORT_OPERATION_FAILED',
        recovery_suggestions: [
          "Verify P12 password is correct",
          "Check keychain permissions",
          "Ensure keychain is unlocked",
          "Try importing certificate manually"
        ],
        original: e
      )
    end
  end
  
  def validate_import_success(import_result, certificate_type)
    unless import_result[:success]
      raise ImportError.new(
        "Import operation reported failure",
        error_code: 'IMPORT_OPERATION_FAILED'
      )
    end
    
    # Verify certificates are actually accessible
    unless verify_imported_certificates(certificate_type)
      log_warn("Import completed but certificates may not be properly accessible")
    end
  end
  
  def record_import(p12_path, certificate_type, import_result)
    @import_history << {
      file_path: p12_path,
      file_name: File.basename(p12_path),
      certificate_type: certificate_type,
      import_time: Time.now,
      keychain: @keychain_name,
      success: import_result[:success],
      team_id: @team_id
    }
  end
  
  def resolve_certificates_directory
    if @options[:certificates_dir]
      FastlaneFileUtils.resolve_path(@options[:certificates_dir], @options[:app_dir])
    elsif @options[:app_dir]
      apple_info_certs = File.join(@options[:app_dir], 'apple_info', 'certificates')
      if File.directory?(apple_info_certs)
        apple_info_certs
      else
        File.join(@options[:app_dir], 'certificates')
      end
    else
      File.join(Dir.pwd, 'certificates')
    end
  end
  
  def find_p12_files(base_dir)
    return [] unless File.directory?(base_dir)
    
    FastlaneFileUtils.find_files('*.p12', base_dir, recursive: true)
  end
  
  def determine_p12_password(p12_path, password_map)
    # Check specific file password
    filename = File.basename(p12_path)
    return password_map[filename] if password_map[filename]
    
    # Check type-based password
    cert_type = infer_certificate_type(p12_path)
    return password_map[cert_type] if password_map[cert_type]
    
    # Check default password
    return password_map[:default] if password_map[:default]
    
    # Check options for global password
    return @options[:p12_password] if @options[:p12_password]
    
    nil
  end
  
  def infer_certificate_type(p12_path)
    filename = File.basename(p12_path).downcase
    
    return 'development' if filename.include?('dev') || filename.include?('debug')
    return 'distribution' if filename.include?('dist') || filename.include?('release') || filename.include?('prod')
    return 'development' # Default to development
  end
end

# Convenience methods for FastLane integration
def import_p12_certificate(p12_path, password, options = {})
  importer = CertificateImporter.new(options)
  importer.import_p12_certificate(p12_path, password)
end

def auto_import_certificates(options = {}, password_map = {})
  importer = CertificateImporter.new(options)
  importer.auto_import_certificates(password_map)
end

def verify_certificate_import(options = {}, certificate_type = nil)
  importer = CertificateImporter.new(options)
  importer.verify_imported_certificates(certificate_type)
end