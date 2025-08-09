# Certificate Detector - Detects existing certificates from multiple sources
# Implements 3-tier detection: Keychain → Files → API

require_relative '../core/logger'
require_relative '../core/error_handler'
require_relative '../auth/keychain_manager'
require_relative '../utils/file_utils'

class CertificateDetector
  class DetectionError < ErrorHandler::CertificateError; end
  
  # Detection source priorities (higher number = higher priority)
  DETECTION_SOURCES = {
    keychain: 3,
    files: 2,
    api: 1
  }.freeze
  
  attr_reader :options, :team_id, :app_identifier
  
  def initialize(options = {})
    @options = options
    @team_id = options[:team_id]
    @app_identifier = options[:app_identifier]
    @certificates_dir = resolve_certificates_directory(options)
    @detection_cache = {}
  end
  
  # Main detection method - implements 3-tier strategy
  def detect_certificates(certificate_type = 'development')
    log_step("Certificate Detection", "Detecting #{certificate_type} certificates using 3-tier strategy") do
      
      log_info("Starting certificate detection",
              certificate_type: certificate_type,
              team_id: @team_id,
              certificates_dir: @certificates_dir)
      
      detection_results = {
        keychain: detect_keychain_certificates(certificate_type),
        files: detect_file_certificates(certificate_type),
        api: detect_api_certificates(certificate_type)
      }
      
      # Combine and prioritize results
      best_certificates = select_best_certificates(detection_results)
      
      log_success("Certificate detection completed",
                 sources_checked: detection_results.keys.length,
                 certificates_found: best_certificates.length,
                 best_source: best_certificates.first&.dig(:source))
      
      best_certificates
    end
  end
  
  # Detect certificates in system keychain
  def detect_keychain_certificates(certificate_type)
    log_step("Keychain Detection", "Searching for certificates in system keychain") do
      
      begin
        certificates = KeychainManager.list_certificates(
          KeychainManager::DEFAULT_KEYCHAIN, 
          certificate_type
        )
        
        # Filter by team ID
        team_certificates = certificates.select do |cert|
          certificate_matches_team?(cert, @team_id)
        end
        
        # Convert to standard format
        keychain_results = team_certificates.map do |cert|
          {
            source: :keychain,
            type: certificate_type,
            subject: cert[:subject],
            team_id: extract_team_id_from_subject(cert[:subject]),
            expires: cert[:expires],
            sha1: cert[:sha1],
            keychain_name: KeychainManager::DEFAULT_KEYCHAIN,
            available: true,
            priority: DETECTION_SOURCES[:keychain]
          }
        end
        
        log_success("Keychain detection completed",
                   certificates_found: keychain_results.length)
        
        keychain_results
        
      rescue => e
        log_warn("Keychain detection failed", error: e.message)
        []
      end
    end
  end
  
  # Detect P12 certificate files in directories
  def detect_file_certificates(certificate_type)
    log_step("File Detection", "Searching for P12 certificate files") do
      
      search_directories = build_search_directories
      p12_files = []
      
      search_directories.each do |dir|
        next unless File.directory?(dir)
        
        log_info("Searching directory for P12 files", directory: dir)
        
        found_files = FastlaneFileUtils.find_files('*.p12', dir, recursive: true)
        p12_files.concat(found_files)
        
        log_info("P12 files found in directory", 
                directory: File.basename(dir),
                count: found_files.length)
      end
      
      # Analyze each P12 file
      file_results = p12_files.map do |p12_path|
        analyze_p12_file(p12_path, certificate_type)
      end.compact
      
      log_success("File detection completed",
                 directories_searched: search_directories.length,
                 p12_files_found: p12_files.length,
                 valid_certificates: file_results.length)
      
      file_results
    end
  end
  
  # Detect certificates via Apple API
  def detect_api_certificates(certificate_type)
    log_step("API Detection", "Querying certificates from Apple Developer Portal") do
      
      begin
        # This would integrate with AppleAPIManager to query certificates
        # For now, return placeholder structure
        
        log_info("Querying Apple API for certificates",
                certificate_type: certificate_type,
                team_id: @team_id)
        
        # Placeholder API results
        api_results = []
        
        log_success("API detection completed",
                   certificates_found: api_results.length)
        
        api_results
        
      rescue => e
        log_warn("API detection failed", error: e.message)
        []
      end
    end
  end
  
  # Get the best available certificate for a given type
  def get_best_certificate(certificate_type = 'development')
    cache_key = "best_#{certificate_type}"
    
    return @detection_cache[cache_key] if @detection_cache[cache_key]
    
    certificates = detect_certificates(certificate_type)
    best_cert = certificates.first
    
    @detection_cache[cache_key] = best_cert
    best_cert
  end
  
  # Check if certificates are available for all required types
  def certificates_available?(required_types = ['development', 'distribution'])
    log_step("Certificate Availability Check", "Verifying all required certificates are available") do
      
      availability_results = {}
      
      required_types.each do |cert_type|
        cert = get_best_certificate(cert_type)
        availability_results[cert_type] = {
          available: !cert.nil?,
          source: cert&.dig(:source),
          expires: cert&.dig(:expires)
        }
        
        log_info("Certificate availability",
                type: cert_type,
                available: availability_results[cert_type][:available],
                source: availability_results[cert_type][:source])
      end
      
      all_available = availability_results.values.all? { |result| result[:available] }
      
      if all_available
        log_success("All required certificates are available")
      else
        missing_types = availability_results.select { |_, result| !result[:available] }.keys
        log_warn("Missing certificates", types: missing_types)
      end
      
      {
        all_available: all_available,
        results: availability_results,
        missing_types: availability_results.select { |_, result| !result[:available] }.keys
      }
    end
  end
  
  # Clear detection cache
  def clear_cache
    @detection_cache.clear
    log_info("Certificate detection cache cleared")
  end
  
  private
  
  def resolve_certificates_directory(options)
    if options[:certificates_dir]
      FastlaneFileUtils.resolve_path(options[:certificates_dir], options[:app_dir])
    elsif options[:app_dir]
      apple_info_certs = File.join(options[:app_dir], 'apple_info', 'certificates')
      if File.directory?(apple_info_certs)
        apple_info_certs
      else
        File.join(options[:app_dir], 'certificates')
      end
    else
      File.join(Dir.pwd, 'certificates')
    end
  end
  
  def build_search_directories
    directories = [@certificates_dir]
    
    # Add apple_info directory if available
    if @options[:app_dir]
      apple_info_dir = File.join(@options[:app_dir], 'apple_info', 'certificates')
      directories << apple_info_dir if File.directory?(apple_info_dir)
    end
    
    # Add default certificates directory
    default_certs_dir = File.join(Dir.pwd, 'certificates')
    directories << default_certs_dir unless directories.include?(default_certs_dir)
    
    directories.uniq.select { |dir| File.directory?(dir) }
  end
  
  def analyze_p12_file(p12_path, certificate_type)
    begin
      file_info = FastlaneFileUtils.file_info(p12_path)
      return nil unless file_info
      
      log_info("Analyzing P12 file",
              file: File.basename(p12_path),
              size: file_info[:size_human])
      
      # Basic file validation
      integrity = FastlaneFileUtils.verify_file_integrity(p12_path, expected_extension: '.p12')
      return nil unless integrity[:valid]
      
      # Extract certificate information (would require actual P12 parsing)
      # For now, infer from filename and directory structure
      inferred_type = infer_certificate_type_from_path(p12_path)
      
      return nil unless inferred_type == certificate_type || inferred_type == 'unknown'
      
      {
        source: :files,
        type: certificate_type,
        file_path: p12_path,
        file_size: file_info[:size],
        file_size_human: file_info[:size_human],
        modified: file_info[:modified],
        team_id: @team_id, # Assume matches team ID
        available: true,
        priority: DETECTION_SOURCES[:files]
      }
      
    rescue => e
      log_warn("Failed to analyze P12 file",
              file: File.basename(p12_path),
              error: e.message)
      nil
    end
  end
  
  def infer_certificate_type_from_path(p12_path)
    filename = File.basename(p12_path).downcase
    
    return 'development' if filename.include?('dev') || filename.include?('debug')
    return 'distribution' if filename.include?('dist') || filename.include?('release') || filename.include?('prod')
    return 'unknown'
  end
  
  def certificate_matches_team?(certificate, team_id)
    return false unless certificate[:subject] && team_id
    
    # Check if subject contains team ID
    certificate[:subject].include?(team_id) ||
      certificate[:organizational_unit]&.include?(team_id)
  end
  
  def extract_team_id_from_subject(subject)
    return nil unless subject
    
    # Extract organizational unit (OU) which contains team ID
    ou_match = subject.match(/OU=([^,]+)/)
    ou_match ? ou_match[1] : nil
  end
  
  def select_best_certificates(detection_results)
    all_certificates = []
    
    # Combine all detection results
    detection_results.each do |source, certificates|
      all_certificates.concat(certificates) if certificates.is_a?(Array)
    end
    
    # Sort by priority (highest first), then by expiration date (latest first)
    all_certificates.sort_by do |cert|
      [
        -(cert[:priority] || 0),
        -(cert[:expires]&.to_i || 0)
      ]
    end
  end
end

# Convenience methods for FastLane integration
def detect_certificates(options, certificate_type = 'development')
  detector = CertificateDetector.new(options)
  detector.detect_certificates(certificate_type)
end

def certificates_available?(options, required_types = ['development', 'distribution'])
  detector = CertificateDetector.new(options)
  detector.certificates_available?(required_types)
end

def get_best_certificate(options, certificate_type = 'development')
  detector = CertificateDetector.new(options)
  detector.get_best_certificate(certificate_type)
end