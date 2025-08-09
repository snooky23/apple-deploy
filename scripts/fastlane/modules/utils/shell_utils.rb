# Shell Utilities - Provides secure shell command execution with logging and error handling
# Handles command execution, output parsing, and security considerations

require_relative '../core/logger'
require_relative '../core/error_handler'
require 'open3'
require 'timeout'

class ShellUtils
  class ShellError < ErrorHandler::DeploymentError; end
  
  # Command execution result structure
  class CommandResult
    attr_reader :success, :exit_status, :stdout, :stderr, :duration, :command
    
    def initialize(success:, exit_status:, stdout:, stderr:, duration:, command:)
      @success = success
      @exit_status = exit_status
      @stdout = stdout
      @stderr = stderr
      @duration = duration
      @command = command
    end
    
    def failed?
      !@success
    end
    
    def output
      @stdout
    end
    
    def error_output
      @stderr
    end
  end
  
  class << self
    # Execute shell command with comprehensive logging and error handling
    def execute_command(command, operation_name: nil, timeout: 300, sensitive: false, working_dir: nil)
      operation_name ||= "shell command"
      
      log_step("Shell Execution", "Executing #{operation_name}") do
        
        log_info("Executing command",
                operation: operation_name,
                command: sensitive ? "[REDACTED]" : command,
                timeout: timeout,
                working_dir: working_dir)
        
        start_time = Time.now
        
        begin
          result = execute_with_timeout(command, timeout, working_dir)
          duration = Time.now - start_time
          
          command_result = CommandResult.new(
            success: result[:exit_status] == 0,
            exit_status: result[:exit_status],
            stdout: result[:stdout],
            stderr: result[:stderr],
            duration: duration,
            command: sensitive ? "[REDACTED]" : command
          )
          
          if command_result.success
            log_success("Command executed successfully",
                       operation: operation_name,
                       duration: "#{duration.round(2)}s",
                       exit_status: result[:exit_status])
            
            # Log stdout if present and not too long
            if !command_result.stdout.empty? && command_result.stdout.length < 1000
              log_info("Command output", output: command_result.stdout.strip)
            end
          else
            log_error("Command execution failed",
                     operation: operation_name,
                     exit_status: result[:exit_status],
                     stderr: command_result.stderr,
                     duration: "#{duration.round(2)}s")
            
            unless sensitive
              raise ShellError.new(
                "Command failed: #{command} (exit status: #{result[:exit_status]})",
                error_code: 'COMMAND_EXECUTION_FAILED',
                context: {
                  command: command,
                  exit_status: result[:exit_status],
                  stderr: command_result.stderr,
                  operation: operation_name
                }
              )
            end
          end
          
          command_result
        rescue Timeout::Error
          duration = Time.now - start_time
          log_error("Command execution timed out",
                   operation: operation_name,
                   timeout: timeout,
                   duration: "#{duration.round(2)}s")
          
          raise ShellError.new(
            "Command timed out after #{timeout}s: #{sensitive ? '[REDACTED]' : command}",
            error_code: 'COMMAND_TIMEOUT'
          )
        rescue => e
          duration = Time.now - start_time
          log_error("Command execution error",
                   operation: operation_name,
                   error: e.message,
                   duration: "#{duration.round(2)}s")
          
          raise ShellError.new(
            "Command execution error: #{e.message}",
            error_code: 'COMMAND_ERROR',
            original: e
          )
        end
      end
    end
    
    # Execute command with automatic retry on failure
    def execute_with_retry(command, operation_name: nil, max_retries: 3, retry_delay: 2, **options)
      operation_name ||= "shell command with retry"
      
      log_info("Executing command with retry",
              operation: operation_name,
              max_retries: max_retries,
              retry_delay: retry_delay)
      
      last_error = nil
      
      (0..max_retries).each do |attempt|
        begin
          if attempt > 0
            log_info("Retrying command",
                    operation: operation_name,
                    attempt: attempt + 1,
                    max_retries: max_retries + 1)
            sleep(retry_delay * attempt) # Exponential backoff
          end
          
          return execute_command(command, operation_name: operation_name, **options)
          
        rescue ShellError => e
          last_error = e
          
          if attempt < max_retries
            log_warn("Command failed, will retry",
                    operation: operation_name,
                    attempt: attempt + 1,
                    error: e.message)
          else
            log_error("Command failed after all retries",
                     operation: operation_name,
                     attempts: max_retries + 1,
                     final_error: e.message)
          end
        end
      end
      
      raise last_error
    end
    
    # Execute xcodebuild command with proper logging
    def execute_xcodebuild(arguments, operation_name: "xcodebuild", timeout: 600)
      command = "xcodebuild #{arguments}"
      
      result = execute_command(command, 
                             operation_name: operation_name,
                             timeout: timeout)
      
      # Parse xcodebuild output for warnings and errors
      parse_xcodebuild_output(result.stdout, result.stderr)
      
      result
    end
    
    # Execute security command (for keychain operations)
    def execute_security_command(arguments, operation_name: "security", sensitive: true)
      command = "security #{arguments}"
      
      execute_command(command,
                     operation_name: operation_name,
                     sensitive: sensitive,
                     timeout: 60)
    end
    
    # Execute git command
    def execute_git_command(arguments, operation_name: "git", working_dir: nil)
      command = "git #{arguments}"
      
      execute_command(command,
                     operation_name: operation_name,
                     working_dir: working_dir,
                     timeout: 120)
    end
    
    # Check if command is available in PATH
    def command_available?(command_name)
      result = execute_command("which #{command_name}", 
                             operation_name: "check command availability",
                             timeout: 10)
      result.success
    rescue
      false
    end
    
    # Get command version
    def get_command_version(command_name, version_flag: "--version")
      return nil unless command_available?(command_name)
      
      begin
        result = execute_command("#{command_name} #{version_flag}",
                                operation_name: "get #{command_name} version",
                                timeout: 10)
        
        if result.success
          # Extract version from output (first line usually contains version)
          version_line = result.stdout.lines.first&.strip
          log_info("Command version detected", 
                  command: command_name,
                  version: version_line)
          version_line
        end
      rescue
        log_warn("Failed to get command version", command: command_name)
        nil
      end
    end
    
    # Run multiple commands in sequence
    def execute_command_sequence(commands, operation_name: "command sequence", stop_on_failure: true)
      log_step("Command Sequence", "Executing #{commands.length} commands") do
        
        results = []
        
        commands.each_with_index do |cmd_config, index|
          if cmd_config.is_a?(String)
            command = cmd_config
            cmd_operation = "command #{index + 1}"
            cmd_options = {}
          else
            command = cmd_config[:command]
            cmd_operation = cmd_config[:operation_name] || "command #{index + 1}"
            cmd_options = cmd_config.except(:command, :operation_name)
          end
          
          log_info("Executing sequence step", 
                  step: index + 1,
                  total: commands.length,
                  operation: cmd_operation)
          
          begin
            result = execute_command(command, operation_name: cmd_operation, **cmd_options)
            results << result
            
            if result.failed? && stop_on_failure
              log_error("Command sequence stopped due to failure",
                       failed_step: index + 1,
                       operation: cmd_operation)
              break
            end
          rescue => e
            results << e
            if stop_on_failure
              log_error("Command sequence stopped due to error",
                       failed_step: index + 1,
                       error: e.message)
              raise
            end
          end
        end
        
        successful_count = results.count { |r| r.is_a?(CommandResult) && r.success }
        
        log_success("Command sequence completed",
                   total_commands: commands.length,
                   successful: successful_count,
                   failed: commands.length - successful_count)
        
        results
      end
    end
    
    # Capture command output with real-time streaming
    def execute_with_streaming(command, operation_name: nil, timeout: 300)
      operation_name ||= "streaming command"
      
      log_info("Starting streaming command execution",
              operation: operation_name,
              command: command)
      
      stdout_lines = []
      stderr_lines = []
      
      begin
        Timeout::timeout(timeout) do
          Open3.popen3(command) do |stdin, stdout, stderr, wait_thr|
            stdin.close
            
            # Stream output in real-time
            streams = [stdout, stderr]
            until streams.empty?
              ready = IO.select(streams, nil, nil, 1)
              next unless ready
              
              ready[0].each do |stream|
                begin
                  if stream == stdout
                    line = stream.readline_nonblock
                    FastlaneLogger.debug(line.chomp) # Stream to console via logger
                    stdout_lines << line
                  else
                    line = stream.readline_nonblock  
                    FastlaneLogger.error(line.chomp) # Stream stderr via logger
                    stderr_lines << line
                  end
                rescue IO::WaitReadable
                  # No data available, continue
                rescue EOFError
                  streams.delete(stream)
                end
              end
            end
            
            exit_status = wait_thr.value.exitstatus
            
            CommandResult.new(
              success: exit_status == 0,
              exit_status: exit_status,
              stdout: stdout_lines.join,
              stderr: stderr_lines.join,
              duration: 0, # Duration not tracked for streaming
              command: command
            )
          end
        end
      rescue Timeout::Error
        raise ShellError.new(
          "Streaming command timed out after #{timeout}s",
          error_code: 'STREAMING_TIMEOUT'
        )
      end
    end
    
    private
    
    def execute_with_timeout(command, timeout, working_dir)
      Timeout::timeout(timeout) do
        if working_dir
          Dir.chdir(working_dir) do
            execute_basic_command(command)
          end
        else
          execute_basic_command(command)
        end
      end
    end
    
    def execute_basic_command(command)
      stdout, stderr, status = Open3.capture3(command)
      
      {
        exit_status: status.exitstatus,
        stdout: stdout,
        stderr: stderr
      }
    end
    
    def parse_xcodebuild_output(stdout, stderr)
      warnings = []
      errors = []
      
      # Parse stdout for warnings and errors
      stdout.each_line do |line|
        if line.include?('warning:')
          warnings << line.strip
        elsif line.include?('error:') || line.include?('** BUILD FAILED **')
          errors << line.strip
        end
      end
      
      # Parse stderr for additional errors
      stderr.each_line do |line|
        if line.include?('error:')
          errors << line.strip
        end
      end
      
      unless warnings.empty?
        log_warn("Xcodebuild warnings detected", count: warnings.length)
        warnings.each { |warning| log_warn("Build warning", message: warning) }
      end
      
      unless errors.empty?
        log_error("Xcodebuild errors detected", count: errors.length)
        errors.each { |error| log_error("Build error", message: error) }
      end
      
      { warnings: warnings, errors: errors }
    end
  end
end

# Convenience methods for FastLane integration
def execute_shell_command(command, **options)
  ShellUtils.execute_command(command, **options)
end

def execute_xcodebuild(arguments, **options)
  ShellUtils.execute_xcodebuild(arguments, **options)
end

def execute_git(arguments, **options)
  ShellUtils.execute_git_command(arguments, **options)
end

def command_available?(command)
  ShellUtils.command_available?(command)
end

def execute_with_retry(command, **options)
  ShellUtils.execute_with_retry(command, **options)
end