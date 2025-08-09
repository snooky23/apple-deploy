# World-Class Structured Logging System for iOS FastLane
# Provides consistent, contextual, and actionable logging throughout the deployment pipeline

require 'json'
require 'time'

class FastlaneLogger
  # Log levels with numeric values for filtering
  LEVELS = {
    DEBUG: 0,
    INFO: 1,
    WARN: 2,
    ERROR: 3,
    FATAL: 4
  }.freeze

  # ANSI color codes for terminal output
  COLORS = {
    DEBUG: "\e[36m",   # Cyan
    INFO: "\e[32m",    # Green  
    WARN: "\e[33m",    # Yellow
    ERROR: "\e[31m",   # Red
    FATAL: "\e[35m",   # Magenta
    RESET: "\e[0m",    # Reset
    BOLD: "\e[1m",     # Bold
    DIM: "\e[2m"       # Dim
  }.freeze

  # Emoji indicators for different log types
  EMOJI = {
    DEBUG: "🔍",
    INFO: "ℹ️ ",
    WARN: "⚠️ ",
    ERROR: "❌",
    FATAL: "💥",
    SUCCESS: "✅",
    PROGRESS: "🔄",
    STEP: "📋",
    TIME: "⏱️ "
  }.freeze

  class << self
    attr_accessor :log_level, :log_file, :structured_output, :context_stack
    
    def initialize_logger
      @log_level = :INFO
      @log_file = nil
      @structured_output = false
      @context_stack = []
      @step_start_times = {}
    end
    
    # Main logging methods
    def debug(message, context = {})
      log(:DEBUG, message, context)
    end
    
    def info(message, context = {})
      log(:INFO, message, context)
    end
    
    def warn(message, context = {})
      log(:WARN, message, context)
    end
    
    def error(message, context = {})
      log(:ERROR, message, context)
    end
    
    def fatal(message, context = {})
      log(:FATAL, message, context)
    end
    
    def success(message, context = {})
      log(:INFO, message, context.merge(type: 'success'), emoji: EMOJI[:SUCCESS])
    end
    
    # Step-based logging with timing
    def step(step_name, description = nil, &block)
      step_id = SecureRandom.hex(4)
      
      header(step_name, description)
      start_time = Time.now
      @step_start_times[step_id] = start_time
      
      begin
        if block_given?
          result = yield
          duration = ((Time.now - start_time) * 1000).round(1)
          success("Step completed: #{step_name}", duration_ms: duration)
          result
        else
          step_id
        end
      rescue => e
        duration = ((Time.now - start_time) * 1000).round(1)
        error("Step failed: #{step_name}", error: e.message, duration_ms: duration)
        raise
      end
    end
    
    # Complete a step started without block
    def complete_step(step_id, success = true, message = nil)
      start_time = @step_start_times.delete(step_id)
      return unless start_time
      
      duration = ((Time.now - start_time) * 1000).round(1)
      
      if success
        success(message || "Step completed", duration_ms: duration)
      else
        error(message || "Step failed", duration_ms: duration)
      end
    end
    
    # Progress reporting
    def progress(current, total, message, context = {})
      percentage = (current.to_f / total * 100).round(1)
      progress_bar = create_progress_bar(percentage)
      
      log(:INFO, "#{message} [#{current}/#{total}] #{progress_bar} #{percentage}%", 
          context.merge(current: current, total: total, percentage: percentage),
          emoji: EMOJI[:PROGRESS])
    end
    
    # Section headers
    def header(title, subtitle = nil)
      separator = "═" * 60
      puts ""
      puts "#{COLORS[:BOLD]}#{COLORS[:INFO]}#{separator}#{COLORS[:RESET]}"
      puts "#{COLORS[:BOLD]}#{COLORS[:INFO]} #{title.upcase}#{COLORS[:RESET]}"
      puts "#{COLORS[:INFO]} #{subtitle}#{COLORS[:RESET]}" if subtitle
      puts "#{COLORS[:BOLD]}#{COLORS[:INFO]}#{separator}#{COLORS[:RESET]}"
      puts ""
    end
    
    # Subheader for major operations
    def subheader(title)
      puts ""
      puts "#{COLORS[:BOLD]}#{COLORS[:INFO]}🚀 #{title}#{COLORS[:RESET]}"
      puts "#{COLORS[:DIM]}#{'-' * (title.length + 4)}#{COLORS[:RESET]}"
    end
    
    # Context management for nested operations
    def with_context(context_data, &block)
      @context_stack << context_data
      begin
        yield
      ensure
        @context_stack.pop
      end
    end
    
    # Timer utilities
    def time_operation(operation_name, &block)
      start_time = Time.now
      info("Starting #{operation_name}...", operation: operation_name)
      
      begin
        result = yield
        duration = ((Time.now - start_time) * 1000).round(1)
        success("Completed #{operation_name}", operation: operation_name, duration_ms: duration)
        result
      rescue => e
        duration = ((Time.now - start_time) * 1000).round(1)
        error("Failed #{operation_name}", operation: operation_name, duration_ms: duration, error: e.message)
        raise
      end
    end
    
    # Configuration methods
    def set_log_level(level)
      @log_level = level.to_sym.upcase
    end
    
    def set_log_file(file_path)
      @log_file = file_path
    end
    
    def enable_structured_output
      @structured_output = true
    end
    
    private
    
    # Core logging implementation  
    def log(level, message, context = {}, **kwargs)
      return if LEVELS[level] < LEVELS[@log_level]
      
      # Merge context with kwargs
      full_context = context.merge(kwargs)
      emoji = kwargs[:emoji]
      
      # Create log entry
      log_entry = {
        timestamp: Time.now.utc.iso8601,
        level: level.to_s,
        message: message,
        context: build_context(full_context)
      }
      
      # Output to console
      output_to_console(level, message, full_context, emoji)
      
      # Output to file if configured
      output_to_file(log_entry) if @log_file
      
      # Output structured format if enabled
      output_structured(log_entry) if @structured_output
    end
    
    def build_context(additional_context)
      base_context = {}
      
      # Add stack context
      @context_stack.each_with_index do |ctx, index|
        base_context.merge!(ctx) if ctx.is_a?(Hash)
      end
      
      # Add additional context (ensure it's a hash)
      if additional_context.is_a?(Hash)
        base_context.merge!(additional_context)
      end
      
      # Add system context
      base_context[:pid] = Process.pid
      base_context[:thread] = Thread.current.object_id
      
      base_context
    end
    
    def output_to_console(level, message, context, emoji)
      color = COLORS[level] || COLORS[:INFO]
      emoji_symbol = emoji || EMOJI[level] || ""
      
      # Format timestamp
      timestamp = Time.now.strftime("%H:%M:%S")
      
      # Build console message
      console_message = "#{COLORS[:DIM]}[#{timestamp}]#{COLORS[:RESET]} "
      console_message += "#{color}#{emoji_symbol}#{COLORS[:RESET]} "
      console_message += message
      
      # Add important context to console output
      if context[:duration_ms]
        console_message += " #{COLORS[:DIM]}(#{context[:duration_ms]}ms)#{COLORS[:RESET]}"
      end
      
      if context[:file]
        console_message += " #{COLORS[:DIM]}[#{File.basename(context[:file])}]#{COLORS[:RESET]}"
      end
      
      puts console_message
      
      # Add context details for errors and warnings
      if [:ERROR, :WARN].include?(level) && context.any?
        context.each do |key, value|
          next if [:duration_ms, :file].include?(key)
          puts "#{COLORS[:DIM]}   #{key}: #{value}#{COLORS[:RESET]}"
        end
      end
    end
    
    def output_to_file(log_entry)
      File.open(@log_file, 'a') do |f|
        f.puts JSON.generate(log_entry)
      end
    rescue => e
      # Fallback: output to stderr if file logging fails
      $stderr.puts "Failed to write to log file: #{e.message}"
    end
    
    def output_structured(log_entry)
      puts JSON.generate(log_entry)
    end
    
    def create_progress_bar(percentage, width = 20)
      filled = (width * percentage / 100).to_i
      empty = width - filled
      
      bar = "#{COLORS[:INFO]}#{'█' * filled}#{COLORS[:DIM]}#{'▒' * empty}#{COLORS[:RESET]}"
      "[#{bar}]"
    end
  end
  
  # Initialize on load
  initialize_logger
end

# Convenience methods for FastLane integration
def log_info(message, context = {})
  FastlaneLogger.info(message, context)
end

def log_warn(message, context = {})
  FastlaneLogger.warn(message, context)
end

def log_error(message, context = {})
  FastlaneLogger.error(message, context)
end

def log_success(message, context = {})
  FastlaneLogger.success(message, context)
end

def log_step(step_name, description = nil, &block)
  FastlaneLogger.step(step_name, description, &block)
end

def log_header(title, subtitle = nil)
  FastlaneLogger.header(title, subtitle)
end

def log_progress(current, total, message, context = {})
  FastlaneLogger.progress(current, total, message, context)
end