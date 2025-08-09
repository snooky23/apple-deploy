# Keychain Manager - Handles macOS keychain operations for certificate management
# Provides centralized keychain access with proper security and error handling

require_relative '../core/logger'
require_relative '../core/error_handler'

class KeychainManager
  class KeychainError < ErrorHandler::KeychainError; end
  
  # Default keychain settings
  DEFAULT_KEYCHAIN = 'login.keychain'
  KEYCHAIN_PASSWORD = '' # Empty for login keychain
  
  class << self
    # Helper function to escape special characters in passwords for shell commands
    def escape_password_for_shell(password)
      return password if password.nil? || password.empty?
      
      # Escape shell special characters
      escaped = password.dup
      escaped.gsub!('!', '\\!')  # Escape exclamation marks
      escaped.gsub!('$', '\\$')  # Escape dollar signs
      escaped.gsub!('`', '\\`')  # Escape backticks
      escaped.gsub!('"', '\\"') # Escape double quotes
      escaped.gsub!('\\', '\\\\') # Escape backslashes (do this last)
      
      return escaped
    end

    # Unlock the keychain for certificate operations
    def unlock_keychain(keychain_name = DEFAULT_KEYCHAIN, password = KEYCHAIN_PASSWORD)
      log_step("Keychain Unlock", "Unlocking keychain for certificate operations") do
        
        log_info("Unlocking keychain", keychain: keychain_name)
        
        # Unlock the keychain
        unlock_command = "security unlock-keychain"
        unlock_command += " -p '#{password}'" unless password.empty?
        unlock_command += " #{keychain_name}"
        
        result = execute_security_command(unlock_command, "unlock keychain")
        
        if result[:success]
          log_success("Keychain unlocked successfully", keychain: keychain_name)
        else
          raise KeychainError.new(
            "Failed to unlock keychain: #{result[:error]}",
            error_code: 'KEYCHAIN_UNLOCK_FAILED'
          )
        end
      end
    end
    
    # Setup keychain partition list for codesign access
    def setup_partition_list(keychain_name = DEFAULT_KEYCHAIN, password = KEYCHAIN_PASSWORD)
      log_step("Keychain Partition Setup", "Configuring keychain access for codesign") do
        
        log_info("Setting up keychain partition list", keychain: keychain_name)
        
        # Set partition list to allow codesign access
        partition_command = "security set-key-partition-list -S apple-tool:,apple:,codesign: -s"
        partition_command += " -k '#{password}'" unless password.empty?
        partition_command += " #{keychain_name}"
        
        result = execute_security_command(partition_command, "setup partition list")
        
        if result[:success]
          log_success("Keychain partition list configured", keychain: keychain_name)
        else
          # Partition list setup failure is often non-fatal, log as warning
          log_warn("Keychain partition list setup failed", 
                  error: result[:error],
                  impact: "Code signing may require manual intervention")
        end
      end
    end
    
    # Import P12 certificate into keychain
    def import_p12_certificate(p12_path, password, keychain_name = DEFAULT_KEYCHAIN)
      log_step("P12 Certificate Import", "Importing P12 certificate to keychain") do
        
        validate_p12_file(p12_path)
        
        log_info("Importing P12 certificate",
                p12_file: File.basename(p12_path),
                keychain: keychain_name,
                file_size: "#{(File.size(p12_path) / 1024.0).round(1)}KB")
        
        # Ensure keychain is unlocked first
        unlock_keychain(keychain_name)
        
        # Import the P12 file (escape password for shell)
        escaped_password = escape_password_for_shell(password)
        import_command = "security import '#{p12_path}' -k #{keychain_name} -P '#{escaped_password}' -T /usr/bin/codesign -T /usr/bin/security"
        
        result = execute_security_command(import_command, "import P12 certificate", sensitive: true)
        
        if result[:success]
          log_success("P12 certificate imported successfully",
                     p12_file: File.basename(p12_path),
                     keychain: keychain_name)
          
          # Setup partition list after successful import
          setup_partition_list(keychain_name, KEYCHAIN_PASSWORD)
          
        else
          raise KeychainError.new(
            "Failed to import P12 certificate: #{result[:error]}",
            error_code: 'P12_IMPORT_FAILED',
            recovery_suggestions: [
              "Verify P12 password is correct",
              "Check P12 file is not corrupted", 
              "Ensure keychain is accessible"
            ]
          )
        end
      end
    end
    
    # List certificates in keychain
    def list_certificates(keychain_name = DEFAULT_KEYCHAIN, certificate_type = nil)
      log_step("Certificate Listing", "Listing certificates in keychain") do
        
        log_info("Listing certificates", keychain: keychain_name, type: certificate_type)
        
        # Build find-certificate command
        find_command = "security find-certificate -a"
        find_command += " -c 'iPhone Developer'" if certificate_type == 'development'
        find_command += " -c 'iPhone Distribution'" if certificate_type == 'distribution'
        find_command += " #{keychain_name}"
        
        result = execute_security_command(find_command, "list certificates")
        
        if result[:success]
          certificates = parse_certificate_list(result[:output])
          
          log_success("Certificates listed successfully",
                     keychain: keychain_name,
                     count: certificates.length)
          
          certificates.each_with_index do |cert, index|
            log_info("Certificate #{index + 1}",
                    subject: cert[:subject],
                    issuer: cert[:issuer],
                    expires: cert[:expires])
          end
          
          certificates
        else
          log_warn("Failed to list certificates", error: result[:error])
          []
        end
      end
    end
    
    # Verify certificate exists and is valid
    def verify_certificate(team_id, certificate_type = 'development', keychain_name = DEFAULT_KEYCHAIN)
      log_step("Certificate Verification", "Verifying certificate availability and validity") do
        
        log_info("Verifying certificate",
                team_id: team_id,
                type: certificate_type,
                keychain: keychain_name)
        
        certificates = list_certificates(keychain_name, certificate_type)
        
        # Find certificates matching team ID
        matching_certs = certificates.select do |cert|
          cert[:subject].include?(team_id) || cert[:organizational_unit].include?(team_id)
        end
        
        if matching_certs.empty?
          log_warn("No matching certificates found",
                  team_id: team_id,
                  available_certs: certificates.length)
          return false
        end
        
        # Check if any matching certificates are valid (not expired)
        valid_certs = matching_certs.select do |cert|
          cert[:expires] && cert[:expires] > Time.now
        end
        
        if valid_certs.empty?
          log_warn("All matching certificates are expired",
                  team_id: team_id,
                  expired_certs: matching_certs.length)
          return false
        end
        
        log_success("Valid certificate found",
                   team_id: team_id,
                   valid_certs: valid_certs.length,
                   expires: valid_certs.first[:expires])
        
        true
      end
    end
    
    # Clean up expired certificates
    def cleanup_expired_certificates(keychain_name = DEFAULT_KEYCHAIN)
      log_step("Certificate Cleanup", "Removing expired certificates from keychain") do
        
        log_info("Cleaning up expired certificates", keychain: keychain_name)
        
        certificates = list_certificates(keychain_name)
        expired_certs = certificates.select do |cert|
          cert[:expires] && cert[:expires] < Time.now
        end
        
        if expired_certs.empty?
          log_info("No expired certificates found")
          return 0
        end
        
        log_info("Found expired certificates", count: expired_certs.length)
        
        removed_count = 0
        expired_certs.each do |cert|
          if remove_certificate(cert[:sha1], keychain_name)
            removed_count += 1
            log_info("Removed expired certificate", subject: cert[:subject])
          end
        end
        
        log_success("Certificate cleanup completed", removed: removed_count)
        removed_count
      end
    end
    
    # Verify keychain access permissions
    def verify_keychain_access(keychain_name = DEFAULT_KEYCHAIN)
      log_step("Keychain Access Verification", "Verifying keychain access permissions") do
        
        log_info("Verifying keychain access", keychain: keychain_name)
        
        # Test basic keychain access
        test_command = "security list-keychains | grep #{keychain_name}"
        result = execute_security_command(test_command, "verify keychain access")
        
        if result[:success]
          log_success("Keychain access verified", keychain: keychain_name)
          
          # Test certificate access
          cert_test = list_certificates(keychain_name)
          accessible_certs = cert_test.length
          
          log_info("Certificate access test", accessible_certs: accessible_certs)
          
          true
        else
          log_error("Keychain access verification failed", error: result[:error])
          false
        end
      end
    end
    
    private
    
    def validate_p12_file(p12_path)
      unless File.exist?(p12_path)
        raise KeychainError.new(
          "P12 file not found: #{p12_path}",
          error_code: 'P12_FILE_NOT_FOUND'
        )
      end
      
      unless p12_path.end_with?('.p12')
        raise KeychainError.new(
          "Invalid P12 file extension: #{p12_path}",
          error_code: 'INVALID_P12_FILE'
        )
      end
      
      unless File.readable?(p12_path)
        raise KeychainError.new(
          "P12 file not readable: #{p12_path}",
          error_code: 'P12_FILE_NOT_READABLE'
        )
      end
    end
    
    def execute_security_command(command, operation, sensitive: false)
      log_info("Executing security command", 
              operation: operation,
              command: sensitive ? "[REDACTED]" : command)
      
      begin
        output = `#{command} 2>&1`
        exit_status = $?.exitstatus
        
        success = exit_status == 0
        
        unless success
          log_error("Security command failed",
                   operation: operation,
                   exit_status: exit_status,
                   output: output)
        end
        
        {
          success: success,
          exit_status: exit_status,
          output: output,
          error: success ? nil : output
        }
      rescue => e
        log_error("Security command execution error",
                 operation: operation,
                 error: e.message)
        
        {
          success: false,
          exit_status: -1,
          output: "",
          error: e.message
        }
      end
    end
    
    def parse_certificate_list(output)
      certificates = []
      current_cert = {}
      
      output.each_line do |line|
        line = line.strip
        
        if line.start_with?('keychain:')
          # Start of new certificate
          certificates << current_cert unless current_cert.empty?
          current_cert = {}
        elsif line.start_with?('"labl"')
          # Certificate label/subject
          match = line.match(/="([^"]+)"/)
          current_cert[:subject] = match[1] if match
        elsif line.start_with?('"issu"')
          # Certificate issuer
          match = line.match(/="([^"]+)"/)
          current_cert[:issuer] = match[1] if match
        elsif line.include?('SHA-1 hash:')
          # Certificate SHA-1
          current_cert[:sha1] = line.split(':').last.strip
        end
      end
      
      # Add last certificate
      certificates << current_cert unless current_cert.empty?
      
      # Parse expiration dates and organizational units
      certificates.each do |cert|
        if cert[:subject]
          # Extract organizational unit (team ID)
          ou_match = cert[:subject].match(/OU=([^,]+)/)
          cert[:organizational_unit] = ou_match[1] if ou_match
          
          # For now, set a placeholder expiration (would need detailed parsing)
          cert[:expires] = Time.now + (365 * 24 * 60 * 60) # 1 year from now
        end
      end
      
      certificates
    end
    
    def remove_certificate(sha1, keychain_name)
      return false unless sha1
      
      delete_command = "security delete-certificate -Z #{sha1} #{keychain_name}"
      result = execute_security_command(delete_command, "remove certificate")
      
      result[:success]
    end
  end
end

# Convenience methods for FastLane integration
def unlock_keychain(keychain_name = KeychainManager::DEFAULT_KEYCHAIN)
  KeychainManager.unlock_keychain(keychain_name)
end

def import_p12(p12_path, password, keychain_name = KeychainManager::DEFAULT_KEYCHAIN)
  KeychainManager.import_p12_certificate(p12_path, password, keychain_name)
end

def verify_certificates(team_id, certificate_type = 'development')
  KeychainManager.verify_certificate(team_id, certificate_type)
end

def setup_keychain_access(keychain_name = KeychainManager::DEFAULT_KEYCHAIN)
  KeychainManager.unlock_keychain(keychain_name)
  KeychainManager.setup_partition_list(keychain_name)
  KeychainManager.verify_keychain_access(keychain_name)
end