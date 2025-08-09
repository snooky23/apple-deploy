# BuildRepositoryImpl - Clean Architecture Infrastructure Layer
# Concrete implementation for Xcode build operations using xcodebuild and project manipulation

require 'open3'
require 'json'
require 'fileutils'
require 'tmpdir'
require 'rexml/document'
require_relative '../../domain/repositories/build_repository'

class BuildRepositoryImpl
  include BuildRepository

  BUILD_TIMEOUT = 900  # 15 minutes for build operations
  EXPORT_TIMEOUT = 300 # 5 minutes for IPA export
  PROJECT_TIMEOUT = 30 # 30 seconds for project operations
  
  # Build configurations
  VALID_CONFIGURATIONS = %w[Debug Release].freeze
  
  # Export methods
  EXPORT_METHODS = %w[app-store ad-hoc enterprise development].freeze
  
  attr_reader :xcode_version, :derived_data_path, :logger
  
  # Initialize BuildRepository implementation
  # @param derived_data_path [String, nil] Custom derived data path
  # @param logger [Logger, nil] Optional logger for operations
  def initialize(derived_data_path: nil, logger: nil)
    @derived_data_path = derived_data_path || default_derived_data_path
    @logger = logger
    @xcode_version = detect_xcode_version
    
    ensure_derived_data_directory
    validate_xcode_availability
  end
  
  # Build Operations Implementation
  
  # Build archive for iOS app
  # @param project_path [String] Path to Xcode project or workspace
  # @param scheme [String] Xcode scheme to build
  # @param configuration [String] Build configuration ('Debug', 'Release')
  # @param output_path [String] Path for archive output
  # @param signing_config [SigningConfiguration] Code signing configuration
  # @return [BuildResult] Build result with archive path and metadata
  def build_archive(project_path, scheme, configuration, output_path, signing_config)
    log_info("Building archive for scheme: #{scheme}, configuration: #{configuration}")
    
    validate_build_parameters(project_path, scheme, configuration, output_path)
    
    # Prepare archive directory
    archive_dir = File.dirname(output_path)
    FileUtils.mkdir_p(archive_dir)
    
    # Determine if it's a workspace or project
    is_workspace = project_path.end_with?('.xcworkspace')
    project_flag = is_workspace ? '-workspace' : '-project'
    
    # Build xcodebuild command
    cmd = [
      'xcodebuild',
      project_flag, "'#{project_path}'",
      '-scheme', "'#{scheme}'",
      '-configuration', configuration,
      '-archivePath', "'#{output_path}'",
      '-derivedDataPath', "'#{@derived_data_path}'",
      'archive'
    ]
    
    # Add signing configuration if provided
    if signing_config
      cmd.concat(build_signing_arguments(signing_config))
    end
    
    # Execute build command
    start_time = Time.now
    cmd_string = cmd.join(' ')
    
    log_info("Executing build command: #{cmd_string}")
    output, status = run_command_with_timeout(cmd_string, BUILD_TIMEOUT)
    
    duration = Time.now - start_time
    
    # Parse build result
    if status.success?
      archive_metadata = get_archive_metadata(output_path)
      
      build_result = BuildResult.new(
        success: true,
        archive_path: output_path,
        duration: duration,
        build_logs: output.lines,
        metadata: archive_metadata.to_hash,
        error: nil
      )
      
      log_info("Build completed successfully in #{duration.round(2)} seconds")
      build_result
    else
      error_message = extract_build_error(output)
      
      build_result = BuildResult.new(
        success: false,
        archive_path: nil,
        duration: duration,
        build_logs: output.lines,
        metadata: {},
        error: error_message
      )
      
      log_error("Build failed: #{error_message}")
      build_result
    end
  rescue => e
    log_error("Build archive error: #{e.message}")
    BuildResult.new(
      success: false,
      archive_path: nil,
      duration: 0,
      build_logs: [],
      metadata: {},
      error: e.message
    )
  end
  
  # Export IPA from archive
  # @param archive_path [String] Path to .xcarchive
  # @param export_options [Hash] Export options for IPA creation
  # @param output_path [String] Directory for IPA output
  # @return [BuildResult] Export result with IPA path and metadata
  def export_ipa(archive_path, export_options, output_path)
    log_info("Exporting IPA from archive: #{File.basename(archive_path)}")
    
    unless File.exist?(archive_path)
      raise ArgumentError, "Archive not found: #{archive_path}"
    end
    
    # Ensure output directory exists
    FileUtils.mkdir_p(output_path)
    
    # Create export options plist
    export_plist_path = create_export_options_plist(export_options, output_path)
    
    # Build export command
    cmd = [
      'xcodebuild',
      '-exportArchive',
      '-archivePath', "'#{archive_path}'",
      '-exportPath', "'#{output_path}'",
      '-exportOptionsPlist', "'#{export_plist_path}'"
    ]
    
    start_time = Time.now
    cmd_string = cmd.join(' ')
    
    log_info("Executing export command: #{cmd_string}")
    output, status = run_command_with_timeout(cmd_string, EXPORT_TIMEOUT)
    
    duration = Time.now - start_time
    
    # Find the generated IPA file
    ipa_files = Dir.glob(File.join(output_path, '*.ipa'))
    ipa_path = ipa_files.first
    
    # Parse export result
    if status.success? && ipa_path
      ipa_metadata = get_ipa_metadata(ipa_path)
      
      build_result = BuildResult.new(
        success: true,
        ipa_path: ipa_path,
        archive_path: archive_path,
        duration: duration,
        build_logs: output.lines,
        metadata: ipa_metadata.to_hash,
        error: nil
      )
      
      log_info("IPA export completed successfully: #{File.basename(ipa_path)}")
      build_result
    else
      error_message = extract_export_error(output)
      
      build_result = BuildResult.new(
        success: false,
        ipa_path: nil,
        archive_path: archive_path,
        duration: duration,
        build_logs: output.lines,
        metadata: {},
        error: error_message
      )
      
      log_error("IPA export failed: #{error_message}")
      build_result
    end
  rescue => e
    log_error("Export IPA error: #{e.message}")
    BuildResult.new(
      success: false,
      ipa_path: nil,
      archive_path: archive_path,
      duration: 0,
      build_logs: [],
      metadata: {},
      error: e.message
    )
  ensure
    # Clean up temporary export plist
    File.delete(export_plist_path) if export_plist_path && File.exist?(export_plist_path)
  end
  
  # Clean build directory
  # @param project_path [String] Path to Xcode project
  # @param scheme [String] Xcode scheme
  # @return [Boolean] True if clean successful
  def clean_build(project_path, scheme)
    log_info("Cleaning build for scheme: #{scheme}")
    
    is_workspace = project_path.end_with?('.xcworkspace')
    project_flag = is_workspace ? '-workspace' : '-project'
    
    cmd = [
      'xcodebuild',
      project_flag, "'#{project_path}'",
      '-scheme', "'#{scheme}'",
      '-derivedDataPath', "'#{@derived_data_path}'",
      'clean'
    ].join(' ')
    
    output, status = run_command_with_timeout(cmd, PROJECT_TIMEOUT)
    
    if status.success?
      log_info("Build clean completed successfully")
      true
    else
      log_error("Build clean failed: #{output}")
      false
    end
  rescue => e
    log_error("Clean build error: #{e.message}")
    false
  end
  
  # Project Operations Implementation
  
  # Update build number in project
  # @param project_path [String] Path to Xcode project
  # @param build_number [String, Integer] New build number
  # @return [Boolean] True if update successful
  def update_build_number(project_path, build_number)
    log_info("Updating build number to: #{build_number}")
    
    project_file_path = find_project_pbxproj(project_path)
    
    begin
      # Read project file
      content = File.read(project_file_path)
      
      # Update CURRENT_PROJECT_VERSION occurrences
      updated_content = content.gsub(
        /CURRENT_PROJECT_VERSION\s*=\s*\d+;/,
        "CURRENT_PROJECT_VERSION = #{build_number};"
      )
      
      # Write updated content back
      File.write(project_file_path, updated_content)
      
      # Verify the update
      verification = verify_build_number_update(project_file_path, build_number.to_s)
      
      if verification
        log_info("Build number updated successfully")
        true
      else
        log_error("Build number update verification failed")
        false
      end
    rescue => e
      log_error("Error updating build number: #{e.message}")
      false
    end
  end
  
  # Update marketing version in project
  # @param project_path [String] Path to Xcode project
  # @param version_number [String] New version number (e.g., "1.2.3")
  # @return [Boolean] True if update successful
  def update_version_number(project_path, version_number)
    log_info("Updating marketing version to: #{version_number}")
    
    project_file_path = find_project_pbxproj(project_path)
    
    begin
      # Read project file
      content = File.read(project_file_path)
      
      # Update MARKETING_VERSION occurrences
      updated_content = content.gsub(
        /MARKETING_VERSION\s*=\s*[^;]+;/,
        "MARKETING_VERSION = #{version_number};"
      )
      
      # Write updated content back
      File.write(project_file_path, updated_content)
      
      # Verify the update
      verification = verify_version_update(project_file_path, version_number)
      
      if verification
        log_info("Marketing version updated successfully")
        true
      else
        log_error("Marketing version update verification failed")
        false
      end
    rescue => e
      log_error("Error updating marketing version: #{e.message}")
      false
    end
  end
  
  # Get current version info from project
  # @param project_path [String] Path to Xcode project
  # @return [VersionInfo] Current version and build number information
  def get_current_version_info(project_path)
    log_info("Getting version info from project")
    
    project_file_path = find_project_pbxproj(project_path)
    content = File.read(project_file_path)
    
    # Extract marketing version
    marketing_match = content.match(/MARKETING_VERSION\s*=\s*([^;]+);/)
    marketing_version = marketing_match ? marketing_match[1].strip : '1.0.0'
    
    # Extract build number
    build_match = content.match(/CURRENT_PROJECT_VERSION\s*=\s*(\d+);/)
    build_number = build_match ? build_match[1].to_i : 1
    
    VersionInfo.new(
      marketing_version: marketing_version,
      build_number: build_number,
      project_path: project_path
    )
  rescue => e
    log_error("Error getting version info: #{e.message}")
    VersionInfo.new(
      marketing_version: '1.0.0',
      build_number: 1,
      project_path: project_path
    )
  end
  
  # Update code signing settings
  # @param project_path [String] Path to Xcode project
  # @param signing_config [SigningConfiguration] New signing configuration
  # @return [Boolean] True if update successful
  def update_signing_configuration(project_path, signing_config)
    log_info("Updating signing configuration")
    
    project_file_path = find_project_pbxproj(project_path)
    
    begin
      content = File.read(project_file_path)
      
      # Update various signing-related settings
      if signing_config.provisioning_profile
        content = content.gsub(
          /PROVISIONING_PROFILE_SPECIFIER\s*=\s*[^;]+;/,
          "PROVISIONING_PROFILE_SPECIFIER = \"#{signing_config.provisioning_profile}\";"
        )
      end
      
      if signing_config.code_sign_identity
        content = content.gsub(
          /CODE_SIGN_IDENTITY\s*=\s*[^;]+;/,
          "CODE_SIGN_IDENTITY = \"#{signing_config.code_sign_identity}\";"
        )
      end
      
      if signing_config.development_team
        content = content.gsub(
          /DEVELOPMENT_TEAM\s*=\s*[^;]+;/,
          "DEVELOPMENT_TEAM = #{signing_config.development_team};"
        )
      end
      
      # Write updated content
      File.write(project_file_path, content)
      
      log_info("Signing configuration updated successfully")
      true
    rescue => e
      log_error("Error updating signing configuration: #{e.message}")
      false
    end
  end
  
  # Validation Operations Implementation
  
  # Validate project configuration for building
  # @param project_path [String] Path to Xcode project
  # @param scheme [String] Xcode scheme
  # @param configuration [String] Build configuration
  # @return [ValidationResult] Validation result with any issues found
  def validate_project_configuration(project_path, scheme, configuration)
    issues = []
    warnings = []
    
    # Check if project exists
    unless File.exist?(project_path)
      issues << "Project not found: #{project_path}"
    end
    
    # Check if scheme exists
    unless scheme_exists?(project_path, scheme)
      issues << "Scheme not found: #{scheme}"
    end
    
    # Check if configuration is valid
    unless VALID_CONFIGURATIONS.include?(configuration)
      warnings << "Unusual build configuration: #{configuration}"
    end
    
    # Check if project can be opened
    if File.exist?(project_path)
      build_settings = get_build_settings(project_path, scheme, configuration) rescue {}
      
      if build_settings.empty?
        issues << "Unable to read build settings for scheme #{scheme}"
      end
    end
    
    ValidationResult.new(
      valid: issues.empty?,
      errors: issues,
      warnings: warnings
    )
  rescue => e
    log_error("Error validating project configuration: #{e.message}")
    ValidationResult.new(
      valid: false,
      errors: [e.message],
      warnings: []
    )
  end
  
  # Validate code signing configuration
  # @param project_path [String] Path to Xcode project
  # @param signing_config [SigningConfiguration] Signing configuration to validate
  # @return [ValidationResult] Validation result for signing setup
  def validate_signing_configuration(project_path, signing_config)
    issues = []
    warnings = []
    
    # Check required signing properties
    unless signing_config.development_team
      issues << "Development team ID is required"
    end
    
    unless signing_config.code_sign_identity
      warnings << "Code sign identity not specified"
    end
    
    unless signing_config.provisioning_profile
      warnings << "Provisioning profile not specified"
    end
    
    ValidationResult.new(
      valid: issues.empty?,
      errors: issues,
      warnings: warnings
    )
  end
  
  # Check if scheme exists in project
  # @param project_path [String] Path to Xcode project
  # @param scheme [String] Scheme name to check
  # @return [Boolean] True if scheme exists
  def scheme_exists?(project_path, scheme)
    available_schemes = get_available_schemes(project_path)
    available_schemes.include?(scheme)
  rescue => e
    log_error("Error checking scheme existence: #{e.message}")
    false
  end
  
  # Query Operations Implementation
  
  # Get available schemes for project
  # @param project_path [String] Path to Xcode project
  # @return [Array<String>] Array of available scheme names
  def get_available_schemes(project_path)
    is_workspace = project_path.end_with?('.xcworkspace')
    project_flag = is_workspace ? '-workspace' : '-project'
    
    cmd = "xcodebuild #{project_flag} '#{project_path}' -list -json"
    output, status = run_command_with_timeout(cmd, PROJECT_TIMEOUT)
    
    if status.success?
      data = JSON.parse(output)
      schemes = data.dig('project', 'schemes') || data.dig('workspace', 'schemes') || []
      log_info("Found #{schemes.length} schemes")
      schemes
    else
      log_error("Failed to get available schemes: #{output}")
      []
    end
  rescue => e
    log_error("Error getting available schemes: #{e.message}")
    []
  end
  
  # Get available configurations for project
  # @param project_path [String] Path to Xcode project
  # @return [Array<String>] Array of available configuration names
  def get_available_configurations(project_path)
    is_workspace = project_path.end_with?('.xcworkspace')
    project_flag = is_workspace ? '-workspace' : '-project'
    
    cmd = "xcodebuild #{project_flag} '#{project_path}' -list -json"
    output, status = run_command_with_timeout(cmd, PROJECT_TIMEOUT)
    
    if status.success?
      data = JSON.parse(output)
      configs = data.dig('project', 'configurations') || ['Debug', 'Release']
      log_info("Found #{configs.length} configurations")
      configs
    else
      log_error("Failed to get available configurations: #{output}")
      ['Debug', 'Release']
    end
  rescue => e
    log_error("Error getting available configurations: #{e.message}")
    ['Debug', 'Release']
  end
  
  # Get build settings for scheme and configuration
  # @param project_path [String] Path to Xcode project
  # @param scheme [String] Xcode scheme
  # @param configuration [String] Build configuration
  # @return [Hash] Build settings as key-value pairs
  def get_build_settings(project_path, scheme, configuration)
    is_workspace = project_path.end_with?('.xcworkspace')
    project_flag = is_workspace ? '-workspace' : '-project'
    
    cmd = [
      'xcodebuild',
      project_flag, "'#{project_path}'",
      '-scheme', "'#{scheme}'",
      '-configuration', configuration,
      '-showBuildSettings',
      '-json'
    ].join(' ')
    
    output, status = run_command_with_timeout(cmd, PROJECT_TIMEOUT)
    
    if status.success?
      data = JSON.parse(output)
      build_settings = data.first&.dig('buildSettings') || {}
      log_info("Retrieved #{build_settings.length} build settings")
      build_settings
    else
      log_error("Failed to get build settings: #{output}")
      {}
    end
  rescue => e
    log_error("Error getting build settings: #{e.message}")
    {}
  end
  
  # Archive Operations Implementation
  
  # Validate archive integrity
  # @param archive_path [String] Path to .xcarchive
  # @return [ValidationResult] Archive validation result
  def validate_archive(archive_path)
    issues = []
    warnings = []
    
    unless File.exist?(archive_path)
      issues << "Archive not found: #{archive_path}"
      return ValidationResult.new(valid: false, errors: issues, warnings: warnings)
    end
    
    unless File.directory?(archive_path)
      issues << "Archive is not a directory: #{archive_path}"
    end
    
    # Check for required archive components
    info_plist = File.join(archive_path, 'Info.plist')
    unless File.exist?(info_plist)
      issues << "Archive Info.plist not found"
    end
    
    products_dir = File.join(archive_path, 'Products')
    unless File.directory?(products_dir)
      issues << "Archive Products directory not found"
    end
    
    ValidationResult.new(
      valid: issues.empty?,
      errors: issues,
      warnings: warnings
    )
  end
  
  # Get archive metadata
  # @param archive_path [String] Path to .xcarchive
  # @return [ArchiveMetadata] Archive information and metadata
  def get_archive_metadata(archive_path)
    info_plist_path = File.join(archive_path, 'Info.plist')
    
    if File.exist?(info_plist_path)
      plist_data = read_plist(info_plist_path)
      
      ArchiveMetadata.new(
        archive_path: archive_path,
        name: plist_data['Name'] || File.basename(archive_path, '.xcarchive'),
        creation_date: plist_data['CreationDate'] || File.mtime(archive_path),
        scheme_name: plist_data['SchemeName'],
        archive_version: plist_data['ArchiveVersion'] || '2',
        application_properties: plist_data['ApplicationProperties'] || {}
      )
    else
      ArchiveMetadata.new(
        archive_path: archive_path,
        name: File.basename(archive_path, '.xcarchive'),
        creation_date: File.mtime(archive_path),
        scheme_name: 'Unknown',
        archive_version: '2',
        application_properties: {}
      )
    end
  rescue => e
    log_error("Error getting archive metadata: #{e.message}")
    ArchiveMetadata.new(
      archive_path: archive_path,
      name: File.basename(archive_path, '.xcarchive'),
      creation_date: File.mtime(archive_path),
      scheme_name: 'Unknown',
      archive_version: '2',
      application_properties: {}
    )
  end
  
  # IPA Operations Implementation
  
  # Validate IPA file
  # @param ipa_path [String] Path to .ipa file
  # @return [ValidationResult] IPA validation result
  def validate_ipa(ipa_path)
    issues = []
    warnings = []
    
    unless File.exist?(ipa_path)
      issues << "IPA file not found: #{ipa_path}"
      return ValidationResult.new(valid: false, errors: issues, warnings: warnings)
    end
    
    # Check file size
    file_size = File.size(ipa_path)
    if file_size < 1024 * 1024 # Less than 1MB
      warnings << "IPA file seems unusually small: #{file_size} bytes"
    end
    
    # Check file extension
    unless ipa_path.end_with?('.ipa')
      warnings << "File does not have .ipa extension"
    end
    
    ValidationResult.new(
      valid: issues.empty?,
      errors: issues,
      warnings: warnings
    )
  end
  
  # Get IPA metadata
  # @param ipa_path [String] Path to .ipa file
  # @return [IpaMetadata] IPA information and metadata
  def get_ipa_metadata(ipa_path)
    file_size = File.size(ipa_path)
    creation_time = File.mtime(ipa_path)
    
    IpaMetadata.new(
      ipa_path: ipa_path,
      file_size: file_size,
      creation_date: creation_time,
      filename: File.basename(ipa_path)
    )
  rescue => e
    log_error("Error getting IPA metadata: #{e.message}")
    IpaMetadata.new(
      ipa_path: ipa_path,
      file_size: 0,
      creation_date: Time.now,
      filename: File.basename(ipa_path)
    )
  end
  
  # Repository Information Implementation
  
  # Get repository type/source information
  # @return [String] Repository type identifier
  def repository_type
    'xcodebuild'
  end
  
  # Check if repository is available/accessible
  # @return [Boolean] True if build tools are available
  def available?
    !@xcode_version.nil? && system('which xcodebuild > /dev/null 2>&1')
  end
  
  # Get Xcode version information
  # @return [XcodeVersion] Xcode version and build tools information
  def get_xcode_version
    @xcode_version
  end
  
  private
  
  # Validate build parameters
  def validate_build_parameters(project_path, scheme, configuration, output_path)
    raise ArgumentError, "Project path is required" if project_path.nil? || project_path.empty?
    raise ArgumentError, "Scheme is required" if scheme.nil? || scheme.empty?
    raise ArgumentError, "Configuration is required" if configuration.nil? || configuration.empty?
    raise ArgumentError, "Output path is required" if output_path.nil? || output_path.empty?
    raise ArgumentError, "Project not found: #{project_path}" unless File.exist?(project_path)
  end
  
  # Build signing arguments for xcodebuild
  def build_signing_arguments(signing_config)
    args = []
    
    if signing_config.development_team
      args.concat(['DEVELOPMENT_TEAM=' + signing_config.development_team])
    end
    
    if signing_config.code_sign_identity
      args.concat(['CODE_SIGN_IDENTITY=' + signing_config.code_sign_identity])
    end
    
    if signing_config.provisioning_profile
      args.concat(['PROVISIONING_PROFILE_SPECIFIER=' + signing_config.provisioning_profile])
    end
    
    args
  end
  
  # Create export options plist file
  def create_export_options_plist(export_options, output_dir)
    plist_path = File.join(output_dir, 'ExportOptions.plist')
    
    # Default export options
    default_options = {
      'method' => export_options[:method] || 'app-store',
      'uploadBitcode' => export_options[:upload_bitcode] || false,
      'uploadSymbols' => export_options[:upload_symbols] || true,
      'compileBitcode' => export_options[:compile_bitcode] || false
    }
    
    # Add provisioning profile if specified
    if export_options[:provisioning_profiles]
      default_options['provisioningProfiles'] = export_options[:provisioning_profiles]
    end
    
    # Write plist file
    write_plist(plist_path, default_options)
    plist_path
  end
  
  # Extract build error from output
  def extract_build_error(output)
    error_lines = output.lines.select { |line| line.include?('error:') || line.include?('ERROR') }
    return error_lines.first&.strip if error_lines.any?
    
    # Look for other failure indicators
    if output.include?('BUILD FAILED')
      return 'Build failed - check build logs for details'
    elsif output.include?('Code Signing Error')
      return 'Code signing error - check certificates and provisioning profiles'
    else
      return 'Build failed with unknown error'
    end
  end
  
  # Extract export error from output
  def extract_export_error(output)
    error_lines = output.lines.select { |line| line.include?('error:') || line.include?('ERROR') }
    return error_lines.first&.strip if error_lines.any?
    
    if output.include?('EXPORT FAILED')
      return 'Export failed - check export options and certificates'
    else
      return 'Export failed with unknown error'
    end
  end
  
  # Find project.pbxproj file
  def find_project_pbxproj(project_path)
    if project_path.end_with?('.xcodeproj')
      File.join(project_path, 'project.pbxproj')
    elsif project_path.end_with?('.xcworkspace')
      # For workspaces, we need to find the main project
      # This is a simplified approach - in reality, workspaces can have multiple projects
      Dir.glob(File.join(File.dirname(project_path), '*.xcodeproj')).first + '/project.pbxproj'
    else
      raise ArgumentError, "Unsupported project type: #{project_path}"
    end
  end
  
  # Verify build number update
  def verify_build_number_update(project_file_path, expected_build_number)
    content = File.read(project_file_path)
    content.include?("CURRENT_PROJECT_VERSION = #{expected_build_number};")
  end
  
  # Verify version update
  def verify_version_update(project_file_path, expected_version)
    content = File.read(project_file_path)
    content.include?("MARKETING_VERSION = #{expected_version};")
  end
  
  # Detect Xcode version
  def detect_xcode_version
    cmd = 'xcodebuild -version'
    output, status = run_command_with_timeout(cmd, 10)
    
    if status.success?
      lines = output.lines
      version_line = lines.find { |line| line.start_with?('Xcode') }
      build_line = lines.find { |line| line.start_with?('Build version') }
      
      if version_line
        version = version_line.match(/Xcode (\d+\.\d+(?:\.\d+)?)/)[1] rescue 'Unknown'
        build = build_line&.match(/Build version (\S+)/)[1] rescue 'Unknown'
        
        XcodeVersion.new(
          version: version,
          build: build,
          path: `xcode-select -p`.strip
        )
      else
        nil
      end
    else
      nil
    end
  rescue => e
    log_error("Error detecting Xcode version: #{e.message}")
    nil
  end
  
  # Validate Xcode availability
  def validate_xcode_availability
    unless @xcode_version
      raise "Xcode not found or not properly configured"
    end
    
    log_info("Using Xcode #{@xcode_version.version} (Build #{@xcode_version.build})")
  end
  
  # Ensure derived data directory exists
  def ensure_derived_data_directory
    FileUtils.mkdir_p(@derived_data_path) unless File.directory?(@derived_data_path)
  rescue => e
    log_error("Error creating derived data directory: #{e.message}")
  end
  
  # Get default derived data path
  def default_derived_data_path
    File.expand_path('~/Library/Developer/Xcode/DerivedData/ios_deploy')
  end
  
  # Read plist file
  def read_plist(plist_path)
    cmd = "plutil -convert json -o - '#{plist_path}'"
    output, status = run_command_with_timeout(cmd, 10)
    
    if status.success?
      JSON.parse(output)
    else
      {}
    end
  rescue => e
    log_error("Error reading plist: #{e.message}")
    {}
  end
  
  # Write plist file
  def write_plist(plist_path, data)
    json_content = JSON.pretty_generate(data)
    
    # Write JSON to temporary file
    temp_file = Tempfile.new(['export_options', '.json'])
    temp_file.write(json_content)
    temp_file.close
    
    # Convert JSON to plist
    cmd = "plutil -convert xml1 '#{temp_file.path}' -o '#{plist_path}'"
    run_command_with_timeout(cmd, 10)
  ensure
    temp_file&.unlink
  end
  
  # Run command with timeout
  def run_command_with_timeout(command, timeout = 30)
    log_debug("Executing: #{command}")
    
    output = ""
    status = nil
    
    Open3.popen3(command) do |stdin, stdout, stderr, wait_thr|
      stdin.close
      
      begin
        Timeout.timeout(timeout) do
          output = stdout.read + stderr.read
          status = wait_thr.value
        end
      rescue Timeout::Error
        Process.kill('TERM', wait_thr.pid)
        raise "Command timed out after #{timeout} seconds"
      end
    end
    
    [output, status]
  end
  
  # Logging methods
  
  def log_info(message)
    @logger&.info("[BuildRepository] #{message}")
  end
  
  def log_error(message)
    @logger&.error("[BuildRepository] #{message}")
  end
  
  def log_debug(message)
    @logger&.debug("[BuildRepository] #{message}")
  end
end

# Supporting classes for build operations

class BuildResult
  attr_reader :success, :archive_path, :ipa_path, :duration, :build_logs, :metadata, :error
  
  def initialize(success:, archive_path: nil, ipa_path: nil, duration: 0, build_logs: [], metadata: {}, error: nil)
    @success = success
    @archive_path = archive_path
    @ipa_path = ipa_path
    @duration = duration
    @build_logs = build_logs
    @metadata = metadata
    @error = error
  end
  
  def success?
    @success
  end
  
  def to_hash
    {
      success: @success,
      archive_path: @archive_path,
      ipa_path: @ipa_path,
      duration: @duration,
      metadata: @metadata,
      error: @error
    }
  end
end

class VersionInfo
  attr_reader :marketing_version, :build_number, :project_path
  
  def initialize(marketing_version:, build_number:, project_path:)
    @marketing_version = marketing_version
    @build_number = build_number
    @project_path = project_path
  end
  
  def to_hash
    {
      marketing_version: @marketing_version,
      build_number: @build_number,
      project_path: @project_path
    }
  end
end

class ValidationResult
  attr_reader :valid, :errors, :warnings
  
  def initialize(valid:, errors: [], warnings: [])
    @valid = valid
    @errors = errors
    @warnings = warnings
  end
  
  def valid?
    @valid
  end
  
  def has_warnings?
    !@warnings.empty?
  end
  
  def to_hash
    {
      valid: @valid,
      errors: @errors,
      warnings: @warnings
    }
  end
end

class SigningConfiguration
  attr_reader :development_team, :code_sign_identity, :provisioning_profile
  
  def initialize(development_team:, code_sign_identity: nil, provisioning_profile: nil)
    @development_team = development_team
    @code_sign_identity = code_sign_identity
    @provisioning_profile = provisioning_profile
  end
end

class ArchiveMetadata
  attr_reader :archive_path, :name, :creation_date, :scheme_name, :archive_version, :application_properties
  
  def initialize(archive_path:, name:, creation_date:, scheme_name:, archive_version:, application_properties:)
    @archive_path = archive_path
    @name = name
    @creation_date = creation_date
    @scheme_name = scheme_name
    @archive_version = archive_version
    @application_properties = application_properties
  end
  
  def to_hash
    {
      archive_path: @archive_path,
      name: @name,
      creation_date: @creation_date.iso8601,
      scheme_name: @scheme_name,
      archive_version: @archive_version,
      application_properties: @application_properties
    }
  end
end

class IpaMetadata
  attr_reader :ipa_path, :file_size, :creation_date, :filename
  
  def initialize(ipa_path:, file_size:, creation_date:, filename:)
    @ipa_path = ipa_path
    @file_size = file_size
    @creation_date = creation_date
    @filename = filename
  end
  
  def to_hash
    {
      ipa_path: @ipa_path,
      file_size: @file_size,
      creation_date: @creation_date.iso8601,
      filename: @filename
    }
  end
end

class XcodeVersion
  attr_reader :version, :build, :path
  
  def initialize(version:, build:, path:)
    @version = version
    @build = build
    @path = path
  end
  
  def to_hash
    {
      version: @version,
      build: @build,
      path: @path
    }
  end
end