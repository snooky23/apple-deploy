# Certificate Repository Interface - Clean Architecture Domain Layer
# Defines all certificate-related operations without implementation details

module CertificateRepository
  # Query Operations
  
  # Find all certificates for a given team
  # @param team_id [String] Apple Developer Team ID
  # @return [Array<Certificate>] Array of Certificate entities
  def find_by_team(team_id)
    raise NotImplementedError, "Subclass must implement find_by_team"
  end
  
  # Find development certificates for a team
  # @param team_id [String] Apple Developer Team ID  
  # @return [Array<Certificate>] Array of development Certificate entities
  def find_development_certificates(team_id)
    raise NotImplementedError, "Subclass must implement find_development_certificates"
  end
  
  # Find distribution certificates for a team
  # @param team_id [String] Apple Developer Team ID
  # @return [Array<Certificate>] Array of distribution Certificate entities
  def find_distribution_certificates(team_id)
    raise NotImplementedError, "Subclass must implement find_distribution_certificates"
  end
  
  # Count certificates by type for a team
  # @param team_id [String] Apple Developer Team ID
  # @param certificate_type [String] 'development' or 'distribution'
  # @return [Integer] Count of certificates of the specified type
  def count_by_type(team_id, certificate_type)
    raise NotImplementedError, "Subclass must implement count_by_type"
  end
  
  # Find certificate by ID
  # @param certificate_id [String] Unique certificate identifier
  # @return [Certificate, nil] Certificate entity or nil if not found
  def find_by_id(certificate_id)
    raise NotImplementedError, "Subclass must implement find_by_id"
  end
  
  # Creation Operations
  
  # Create a new development certificate
  # @param team_id [String] Apple Developer Team ID
  # @param name [String, nil] Optional certificate name
  # @return [Certificate] Created Certificate entity
  def create_development_certificate(team_id, name = nil)
    raise NotImplementedError, "Subclass must implement create_development_certificate"
  end
  
  # Create a new distribution certificate
  # @param team_id [String] Apple Developer Team ID
  # @param name [String, nil] Optional certificate name
  # @return [Certificate] Created Certificate entity
  def create_distribution_certificate(team_id, name = nil)
    raise NotImplementedError, "Subclass must implement create_distribution_certificate"
  end
  
  # Import Operations
  
  # Import certificate from P12 file
  # @param file_path [String] Path to P12 file
  # @param password [String] P12 file password
  # @param keychain_path [String, nil] Optional keychain path
  # @return [Certificate] Imported Certificate entity
  def import_from_p12(file_path, password, keychain_path = nil)
    raise NotImplementedError, "Subclass must implement import_from_p12"
  end
  
  # Export certificate to P12 file
  # @param certificate [Certificate] Certificate entity to export
  # @param password [String] Password for P12 file
  # @param output_path [String] Output file path
  # @return [Boolean] True if export successful
  def export_to_p12(certificate, password, output_path)
    raise NotImplementedError, "Subclass must implement export_to_p12"
  end
  
  # Management Operations
  
  # Delete a certificate
  # @param certificate_id [String] Certificate ID to delete
  # @return [Boolean] True if deletion successful
  def delete_certificate(certificate_id)
    raise NotImplementedError, "Subclass must implement delete_certificate"
  end
  
  # Revoke a certificate (Apple Developer Portal)
  # @param certificate_id [String] Certificate ID to revoke
  # @return [Boolean] True if revocation successful
  def revoke_certificate(certificate_id)
    raise NotImplementedError, "Subclass must implement revoke_certificate"
  end
  
  # Validation Operations
  
  # Validate certificate for team
  # @param certificate [Certificate] Certificate entity
  # @param team_id [String] Team ID to validate against
  # @return [Boolean] True if certificate is valid for team
  def validate_certificate(certificate, team_id)
    raise NotImplementedError, "Subclass must implement validate_certificate"
  end
  
  # Check if certificate is expired
  # @param certificate [Certificate] Certificate entity
  # @return [Boolean] True if certificate is expired
  def is_expired?(certificate)
    raise NotImplementedError, "Subclass must implement is_expired?"
  end
  
  # Check if certificate has matching private key
  # @param certificate [Certificate] Certificate entity
  # @param keychain_path [String, nil] Optional keychain path
  # @return [Boolean] True if private key is available
  def has_private_key?(certificate, keychain_path = nil)
    raise NotImplementedError, "Subclass must implement has_private_key?"
  end
  
  # Repository Information
  
  # Get repository type/source information
  # @return [String] Repository type identifier ('keychain', 'api', 'file')
  def repository_type
    raise NotImplementedError, "Subclass must implement repository_type"
  end
  
  # Check if repository is available/accessible
  # @return [Boolean] True if repository is accessible
  def available?
    raise NotImplementedError, "Subclass must implement available?"
  end
end