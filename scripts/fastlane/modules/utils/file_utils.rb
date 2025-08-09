# File Utilities - Provides file system operations with error handling and logging
# Handles path resolution, file detection, and directory management

require_relative '../core/logger'
require_relative '../core/error_handler'
require 'fileutils'
require 'pathname'

class FastlaneFileUtils
  class FileError < ErrorHandler::DeploymentError; end
  
  class << self
    # Resolve and normalize file paths
    def resolve_path(path, base_dir = nil)
      return nil if path.nil? || path.empty?
      
      # Return absolute paths as-is
      return File.expand_path(path) if Pathname.new(path).absolute?
      
      # Resolve relative paths
      if base_dir
        candidate_path = File.join(base_dir, path)
        return File.expand_path(candidate_path) if File.exist?(candidate_path)
        
        # Try apple_info subdirectory
        apple_info_path = File.join(base_dir, 'apple_info', path)
        return File.expand_path(apple_info_path) if File.exist?(apple_info_path)
      end
      
      # Fallback to current directory
      File.expand_path(path)
    end
    
    # Find files matching a pattern with optional base directory
    def find_files(pattern, base_dir = Dir.pwd, recursive: true)
      log_info("Searching for files", pattern: pattern, base_dir: base_dir, recursive: recursive)
      
      search_pattern = recursive ? File.join(base_dir, '**', pattern) : File.join(base_dir, pattern)
      files = Dir.glob(search_pattern)
      
      log_info("File search completed", pattern: pattern, found: files.length)
      
      files.map { |f| File.expand_path(f) }
    end
    
    # Find Xcode project files (.xcodeproj or .xcworkspace)
    def find_xcode_project(base_dir)
      log_step("Xcode Project Detection", "Finding Xcode project files") do
        
        log_info("Searching for Xcode project", directory: base_dir)
        
        # Look for .xcworkspace first (preferred)
        workspaces = find_files('*.xcworkspace', base_dir, recursive: false)
        unless workspaces.empty?
          project_path = workspaces.first
          log_success("Found Xcode workspace", 
                     project: File.basename(project_path),
                     path: project_path)
          return { type: :workspace, path: project_path }
        end
        
        # Look for .xcodeproj
        projects = find_files('*.xcodeproj', base_dir, recursive: false)
        unless projects.empty?
          project_path = projects.first
          log_success("Found Xcode project",
                     project: File.basename(project_path),
                     path: project_path) 
          return { type: :project, path: project_path }
        end
        
        raise FileError.new(
          "No Xcode project found in #{base_dir}",
          error_code: 'XCODE_PROJECT_NOT_FOUND',
          recovery_suggestions: [
            "Ensure you're in the correct directory",
            "Check that the Xcode project exists",
            "Verify directory permissions"
          ]
        )
      end
    end
    
    # Detect project scheme from Xcode project
    def detect_project_scheme(project_path)
      log_step("Scheme Detection", "Detecting available Xcode schemes") do
        
        log_info("Detecting schemes", project: File.basename(project_path))
        
        # Use xcodebuild to list schemes
        list_command = "xcodebuild -list -project '#{project_path}' 2>/dev/null"
        output = `#{list_command}`
        
        unless $?.success?
          raise FileError.new(
            "Failed to list schemes for project: #{File.basename(project_path)}",
            error_code: 'SCHEME_DETECTION_FAILED'
          )
        end
        
        # Parse schemes from output
        schemes = []
        in_schemes_section = false
        
        output.each_line do |line|
          line = line.strip
          
          if line == "Schemes:"
            in_schemes_section = true
            next
          end
          
          if in_schemes_section
            if line.empty? || line.start_with?("Build Configurations:")
              break
            end
            schemes << line
          end
        end
        
        if schemes.empty?
          raise FileError.new(
            "No schemes found in project: #{File.basename(project_path)}",
            error_code: 'NO_SCHEMES_FOUND'
          )
        end
        
        log_success("Schemes detected", 
                   count: schemes.length,
                   schemes: schemes)
        
        schemes
      end
    end
    
    # Ensure directory exists and is writable
    def ensure_directory(dir_path, create_if_missing: true)
      log_info("Ensuring directory exists", path: dir_path)
      
      if File.exist?(dir_path)
        unless File.directory?(dir_path)
          raise FileError.new(
            "Path exists but is not a directory: #{dir_path}",
            error_code: 'PATH_NOT_DIRECTORY'
          )
        end
        
        unless File.writable?(dir_path)
          raise FileError.new(
            "Directory is not writable: #{dir_path}",
            error_code: 'DIRECTORY_NOT_WRITABLE'
          )
        end
        
        log_info("Directory exists and is writable", path: dir_path)
        return true
      end
      
      if create_if_missing
        log_info("Creating directory", path: dir_path)
        begin
          FastlaneFileUtils.mkdir_p(dir_path)
          log_success("Directory created", path: dir_path)
          return true
        rescue => e
          raise FileError.new(
            "Failed to create directory: #{dir_path} - #{e.message}",
            error_code: 'DIRECTORY_CREATION_FAILED',
            original: e
          )
        end
      else
        raise FileError.new(
          "Directory does not exist: #{dir_path}",
          error_code: 'DIRECTORY_NOT_FOUND'
        )
      end
    end
    
    # Copy file with verification
    def copy_file(source, destination, verify: true)
      log_info("Copying file", source: File.basename(source), destination: destination)
      
      unless File.exist?(source)
        raise FileError.new(
          "Source file does not exist: #{source}",
          error_code: 'SOURCE_FILE_NOT_FOUND'
        )
      end
      
      # Ensure destination directory exists
      dest_dir = File.dirname(destination)
      ensure_directory(dest_dir)
      
      begin
        FastlaneFileUtils.cp(source, destination)
        
        if verify
          unless File.exist?(destination)
            raise FileError.new(
              "File copy verification failed: #{destination}",
              error_code: 'COPY_VERIFICATION_FAILED'
            )
          end
          
          # Verify file sizes match
          source_size = File.size(source)
          dest_size = File.size(destination)
          
          unless source_size == dest_size
            raise FileError.new(
              "File copy size mismatch: expected #{source_size}, got #{dest_size}",
              error_code: 'COPY_SIZE_MISMATCH'
            )
          end
        end
        
        log_success("File copied successfully",
                   source: File.basename(source),
                   destination: destination,
                   size: "#{(File.size(destination) / 1024.0).round(1)}KB")
        
      rescue => e
        raise FileError.new(
          "Failed to copy file: #{e.message}",
          error_code: 'FILE_COPY_FAILED',
          original: e
        )
      end
    end
    
    # Move file with verification
    def move_file(source, destination, verify: true)
      log_info("Moving file", source: File.basename(source), destination: destination)
      
      copy_file(source, destination, verify: verify)
      
      begin
        File.delete(source)
        log_success("File moved successfully", destination: destination)
      rescue => e
        log_warn("Failed to delete source file after copy", 
                source: source,
                error: e.message)
      end
    end
    
    # Get file information
    def file_info(file_path)
      return nil unless File.exist?(file_path)
      
      stat = File.stat(file_path)
      
      {
        path: File.expand_path(file_path),
        name: File.basename(file_path),
        size: stat.size,
        size_human: human_readable_size(stat.size),
        modified: stat.mtime,
        permissions: sprintf("%o", stat.mode)[-3..-1],
        readable: File.readable?(file_path),
        writable: File.writable?(file_path),
        executable: File.executable?(file_path)
      }
    end
    
    # Clean up temporary files
    def cleanup_temp_files(pattern, max_age_hours = 24)
      log_info("Cleaning up temporary files", pattern: pattern, max_age_hours: max_age_hours)
      
      temp_files = find_files(pattern, '/tmp', recursive: true)
      cleanup_count = 0
      
      cutoff_time = Time.now - (max_age_hours * 3600)
      
      temp_files.each do |file|
        begin
          if File.mtime(file) < cutoff_time
            File.delete(file)
            cleanup_count += 1
            log_info("Deleted old temp file", file: File.basename(file))
          end
        rescue => e
          log_warn("Failed to delete temp file", file: file, error: e.message)
        end
      end
      
      log_info("Temp file cleanup completed", cleaned: cleanup_count)
      cleanup_count
    end
    
    # Verify file integrity (basic checks)
    def verify_file_integrity(file_path, expected_size: nil, expected_extension: nil)
      log_info("Verifying file integrity", file: File.basename(file_path))
      
      unless File.exist?(file_path)
        return { valid: false, error: "File does not exist" }
      end
      
      unless File.readable?(file_path)
        return { valid: false, error: "File is not readable" }
      end
      
      if expected_size && File.size(file_path) != expected_size
        return { 
          valid: false, 
          error: "Size mismatch: expected #{expected_size}, got #{File.size(file_path)}" 
        }
      end
      
      if expected_extension && !file_path.end_with?(expected_extension)
        return { 
          valid: false, 
          error: "Extension mismatch: expected #{expected_extension}" 
        }
      end
      
      log_success("File integrity verified", file: File.basename(file_path))
      { valid: true, error: nil }
    end
    
    private
    
    def human_readable_size(size)
      units = ['B', 'KB', 'MB', 'GB', 'TB']
      unit_index = 0
      size_float = size.to_f
      
      while size_float >= 1024 && unit_index < units.length - 1
        size_float /= 1024
        unit_index += 1
      end
      
      "#{size_float.round(1)}#{units[unit_index]}"
    end
  end
end

# Convenience methods for FastLane integration
def resolve_file_path(path, base_dir = nil)
  FastlaneFileUtils.resolve_path(path, base_dir)
end

def find_xcode_project(base_dir = Dir.pwd)
  FastlaneFileUtils.find_xcode_project(base_dir)
end

def ensure_directory_exists(path)
  FastlaneFileUtils.ensure_directory(path)
end

def copy_file_safe(source, destination)
  FastlaneFileUtils.copy_file(source, destination)
end

def get_file_info(path)
  FastlaneFileUtils.file_info(path)
end