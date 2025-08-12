# Setup Keychain Use Case - Clean Architecture Domain Layer
# Business workflow: Create and configure temporary keychain for certificate operations

require_relative '../../fastlane/modules/core/logger'

class SetupKeychainRequest
  attr_reader :certificates_dir, :p12_password, :keychain_name, :team_id
  
  def initialize(certificates_dir:, p12_password: nil, keychain_name: nil, team_id: nil)
    @certificates_dir = certificates_dir
    @p12_password = p12_password || ENV['FL_P12_PASSWORD'] || "VoiceForms2024"
    @keychain_name = keychain_name || "fastlane_tmp_keychain"
    @team_id = team_id
    
    validate_request
  end
  
  private
  
  def validate_request
    raise ArgumentError, "certificates_dir cannot be nil or empty" if @certificates_dir.nil? || @certificates_dir.empty?
    raise ArgumentError, "certificates_dir must be a valid directory" unless Dir.exist?(File.dirname(@certificates_dir))
    raise ArgumentError, "certificates_dir must be writable" unless File.writable?(File.dirname(@certificates_dir))
  end
end

class SetupKeychainResult
  attr_reader :success, :keychain_path, :imported_certificates, :available_identities, :error, :error_type, :recovery_suggestion
  
  def initialize(success:, keychain_path: nil, imported_certificates: [], available_identities: [], error: nil, error_type: nil, recovery_suggestion: nil)
    @success = success
    @keychain_path = keychain_path
    @imported_certificates = imported_certificates
    @available_identities = available_identities
    @error = error
    @error_type = error_type
    @recovery_suggestion = recovery_suggestion
  end
end

class SetupKeychain
  def initialize(logger: FastlaneLogger)
    @logger = logger
  end
  
  # Execute the use case to setup temporary keychain for certificate operations
  # @param request [SetupKeychainRequest] Input parameters
  # @return [SetupKeychainResult] Result with keychain path and imported certificates
  def execute(request)
    @logger.step("Setting up temporary keychain for certificate operations")
    
    begin
      # Business Logic: Create temporary keychain path
      keychain_path = create_keychain_path(request)
      
      # Business Logic: Remove existing keychain if present
      cleanup_existing_keychain(keychain_path)
      
      # Business Logic: Create and configure new temporary keychain
      create_temporary_keychain(keychain_path, request.p12_password)
      
      # Business Logic: Import existing certificates to keychain
      imported_certificates = import_existing_certificates(keychain_path, request)
      
      # Business Logic: Verify available identities
      available_identities = verify_available_identities(keychain_path)
      
      @logger.success("Temporary keychain setup completed successfully")
      @logger.info("Keychain path: #{keychain_path}")
      @logger.info("Imported #{imported_certificates.size} certificates")
      @logger.info("Available identities: #{available_identities.size}")
      
      SetupKeychainResult.new(
        success: true,
        keychain_path: keychain_path,
        imported_certificates: imported_certificates,
        available_identities: available_identities
      )
      
    rescue KeychainCreationError => e
      @logger.error("Keychain creation failed: #{e.message}")
      SetupKeychainResult.new(
        success: false,
        error: e.message,
        error_type: :keychain_creation_failed,
        recovery_suggestion: "Ensure certificates directory is writable and security framework is available"
      )
      
    rescue CertificateImportError => e
      @logger.warn("Certificate import partially failed: #{e.message}")
      # Partial success - keychain created but some certificates failed
      SetupKeychainResult.new(
        success: true,
        keychain_path: keychain_path,
        imported_certificates: e.imported_certificates || [],
        available_identities: verify_available_identities(keychain_path),
        error: e.message,
        error_type: :certificate_import_partial_failure,
        recovery_suggestion: "Some certificates failed to import but keychain is ready for new certificate creation"
      )
      
    rescue => e
      @logger.error("Unexpected error during keychain setup: #{e.message}")
      SetupKeychainResult.new(
        success: false,
        error: e.message,
        error_type: :unexpected_error,
        recovery_suggestion: "Check system security framework and file permissions"
      )
    end
  end
  
  # Clean up temporary keychain - should be called after deployment completion
  # @param keychain_path [String] Path to the temporary keychain to remove
  # @return [Boolean] True if cleanup successful, false otherwise
  def cleanup_keychain(keychain_path)
    return false if keychain_path.nil? || keychain_path.empty?
    
    @logger.step("Cleaning up temporary keychain")
    @logger.info("Keychain path: #{keychain_path}")
    
    begin
      # Clean up keychain and related files
      cleanup_performed = false
      
      if File.exist?(keychain_path)
        # Remove keychain from security framework
        result = system("security delete-keychain '#{keychain_path}' 2>/dev/null")
        
        # Remove the main keychain-db file if it still exists
        File.delete(keychain_path) if File.exist?(keychain_path)
        cleanup_performed = true
      end
      
      # Clean up companion keychain files (.ff* files and others)
      keychain_dir = File.dirname(keychain_path)
      keychain_name = File.basename(keychain_path, '.keychain-db')
      
      companion_files = Dir.glob(File.join(keychain_dir, "#{keychain_name}.*"))
      companion_files += Dir.glob(File.join(keychain_dir, ".ff*"))  # FastLane temporary files
      
      companion_files.each do |file|
        if File.exist?(file) && file != keychain_path
          File.delete(file)
          @logger.debug("Cleaned up companion file: #{File.basename(file)}")
          cleanup_performed = true
        end
      end
      
      if cleanup_performed
        @logger.success("Temporary keychain and companion files cleaned up successfully")
      else
        @logger.info("No keychain files found, cleanup not needed")
      end
      
      true
      
    rescue => e
      @logger.warn("Keychain cleanup failed: #{e.message}")
      @logger.info("This is non-critical and will not affect future deployments")
      false
    end
  end
  
  private
  
  def create_keychain_path(request)
    keychain_path = File.join(request.certificates_dir, "#{request.keychain_name}.keychain-db")
    @logger.info("Creating keychain at path: #{keychain_path}")
    @logger.info("Directory writable: #{File.writable?(File.dirname(keychain_path))}")
    
    # Ensure certificates directory exists
    FileUtils.mkdir_p(File.dirname(keychain_path))
    
    keychain_path
  end
  
  def cleanup_existing_keychain(keychain_path)
    if File.exist?(keychain_path)
      @logger.info("Removing existing temporary keychain")
      begin
        system("security delete-keychain '#{keychain_path}' 2>/dev/null || true")
        File.delete(keychain_path) if File.exist?(keychain_path)
        @logger.success("Existing keychain removed")
      rescue => e
        @logger.warn("Failed to remove existing keychain: #{e.message}")
        # Continue anyway - new keychain creation might overwrite
      end
    end
  end
  
  def create_temporary_keychain(keychain_path, password)
    @logger.info("Creating temporary keychain with security framework")
    
    # Create keychain
    result = system("security create-keychain -p '#{password}' '#{keychain_path}'")
    raise KeychainCreationError.new("Failed to create keychain") unless result
    
    # Set timeout to prevent lockout
    system("security set-keychain-settings -t 3600 '#{keychain_path}'")
    
    # Add to search list
    system("security list-keychains -d user -s '#{keychain_path}' $(security list-keychains -d user | sed s/\\\"//g)")
    
    # Unlock keychain
    result = system("security unlock-keychain -p '#{password}' '#{keychain_path}'")
    raise KeychainCreationError.new("Failed to unlock keychain") unless result
    
    @logger.success("Temporary keychain created and configured")
    @logger.info("This avoids system keychain permissions issues in CI/CD")
  end
  
  def import_existing_certificates(keychain_path, request)
    existing_p12_files = Dir.glob(File.join(request.certificates_dir, "*.p12"))
    existing_cer_files = Dir.glob(File.join(request.certificates_dir, "*.cer"))
    imported_certificates = []
    failed_imports = []
    
    if existing_p12_files.empty? && existing_cer_files.empty?
      @logger.info("No existing certificates found to import")
      return imported_certificates
    end
    
    @logger.info("Importing existing certificates to keychain")
    
    # Import P12 files (private keys)
    existing_p12_files.each do |p12_file|
      begin
        @logger.info("Importing P12: #{File.basename(p12_file)}")
        result = system("security import '#{p12_file}' -k '#{keychain_path}' -P '#{request.p12_password}' -T /usr/bin/codesign -T /usr/bin/security 2>/dev/null")
        
        if result
          imported_certificates << { file: File.basename(p12_file), type: :p12 }
          @logger.success("Imported #{File.basename(p12_file)}")
        else
          failed_imports << { file: File.basename(p12_file), type: :p12, reason: "Import command failed" }
          @logger.warn("Failed to import #{File.basename(p12_file)}")
        end
      rescue => e
        failed_imports << { file: File.basename(p12_file), type: :p12, reason: e.message }
        @logger.warn("Failed to import #{File.basename(p12_file)}: #{e.message}")
      end
    end
    
    # Import CER files (public certificates) 
    existing_cer_files.each do |cer_file|
      begin
        @logger.info("Importing CER: #{File.basename(cer_file)}")
        result = system("security import '#{cer_file}' -k '#{keychain_path}' -T /usr/bin/codesign -T /usr/bin/security 2>/dev/null")
        
        if result
          imported_certificates << { file: File.basename(cer_file), type: :cer }
          @logger.success("Imported #{File.basename(cer_file)}")
        else
          failed_imports << { file: File.basename(cer_file), type: :cer, reason: "Import command failed" }
          @logger.warn("Failed to import #{File.basename(cer_file)}")
        end
      rescue => e
        failed_imports << { file: File.basename(cer_file), type: :cer, reason: e.message }
        @logger.warn("Failed to import #{File.basename(cer_file)}: #{e.message}")
      end
    end
    
    @logger.success("Certificate import completed")
    @logger.info("Imported: #{imported_certificates.size}, Failed: #{failed_imports.size}")
    
    # If some imports failed but we have some successes, it's partial success
    if failed_imports.any? && imported_certificates.any?
      raise CertificateImportError.new("Some certificates failed to import", imported_certificates)
    elsif failed_imports.any?
      raise CertificateImportError.new("All certificate imports failed", [])
    end
    
    imported_certificates
  end
  
  def verify_available_identities(keychain_path)
    @logger.info("Verifying certificate identities in keychain")
    
    begin
      identities_output = `security find-identity -v -p codesigning '#{keychain_path}' 2>/dev/null`
      identities = []
      
      if $?.success? && !identities_output.empty?
        @logger.info("Available identities:")
        identities_output.split("\n").each do |line|
          line = line.strip
          if line.length > 0 && !line.include?("0 valid identities found")
            @logger.info("  #{line}")
            identities << line
          end
        end
      else
        @logger.info("No valid identities found in keychain")
      end
      
      identities
      
    rescue => e
      @logger.warn("Could not verify identities: #{e.message}")
      []
    end
  end
end

# Custom exceptions for keychain operations
class KeychainCreationError < StandardError; end

class CertificateImportError < StandardError
  attr_reader :imported_certificates
  
  def initialize(message, imported_certificates = [])
    super(message)
    @imported_certificates = imported_certificates
  end
end