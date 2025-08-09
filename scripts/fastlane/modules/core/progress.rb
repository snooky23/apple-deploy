# Advanced Progress Tracking System
# Provides visual progress feedback and timing information for deployment operations

require_relative 'logger'

class ProgressTracker
  class Step
    attr_reader :name, :description, :start_time, :end_time, :status, :message
    
    def initialize(name, description = nil)
      @name = name
      @description = description
      @status = :pending
      @start_time = nil
      @end_time = nil
      @message = nil
    end
    
    def start
      @start_time = Time.now
      @status = :running
    end
    
    def complete(success = true, message = nil)
      @end_time = Time.now
      @status = success ? :completed : :failed
      @message = message
    end
    
    def duration
      return 0 unless @start_time
      end_time = @end_time || Time.now
      ((end_time - @start_time) * 1000).round(1)
    end
    
    def running?
      @status == :running
    end
    
    def completed?
      @status == :completed
    end
    
    def failed?
      @status == :failed
    end
    
    def pending?
      @status == :pending
    end
  end
  
  attr_reader :steps, :current_step_index, :start_time
  
  def initialize(step_definitions = [])
    @steps = []
    @current_step_index = -1
    @start_time = Time.now
    @total_duration = nil
    
    # Initialize steps
    step_definitions.each do |step_def|
      if step_def.is_a?(Hash)
        add_step(step_def[:name], step_def[:description])
      else
        add_step(step_def)
      end
    end
  end
  
  # Add a new step to the tracker
  def add_step(name, description = nil)
    @steps << Step.new(name, description)
  end
  
  # Start the next step
  def start_step(name = nil, description = nil)
    # If name provided, find or create the step
    if name
      step_index = @steps.find_index { |s| s.name == name }
      if step_index.nil?
        add_step(name, description)
        step_index = @steps.length - 1
      end
      @current_step_index = step_index
    else
      @current_step_index += 1
    end
    
    return nil if @current_step_index >= @steps.length
    
    current_step = @steps[@current_step_index]
    current_step.start
    
    # Update description if provided
    current_step.instance_variable_set(:@description, description) if description
    
    log_step_start(current_step)
    display_progress
    
    current_step
  end
  
  # Complete the current step
  def complete_step(success = true, message = nil)
    return nil if @current_step_index < 0 || @current_step_index >= @steps.length
    
    current_step = @steps[@current_step_index]
    current_step.complete(success, message)
    
    log_step_completion(current_step)
    display_progress
    
    # If this was the last step, log completion
    if @current_step_index == @steps.length - 1
      complete_all_steps
    end
    
    current_step
  end
  
  # Mark all remaining steps as completed
  def complete_all_steps
    @total_duration = ((Time.now - @start_time) * 1000).round(1)
    
    FastlaneLogger.header("DEPLOYMENT COMPLETED", 
                         "Total duration: #{format_duration(@total_duration)}")
    
    display_final_summary
  end
  
  # Get current progress percentage
  def progress_percentage
    return 0 if @steps.empty?
    
    completed_steps = @steps.count { |s| s.completed? || s.failed? }
    (completed_steps.to_f / @steps.length * 100).round(1)
  end
  
  # Get current step information
  def current_step
    return nil if @current_step_index < 0 || @current_step_index >= @steps.length
    @steps[@current_step_index]
  end
  
  # Display current progress
  def display_progress
    return if @steps.empty?
    
    FastlaneLogger.header("iOS FastLane Deployment Pipeline", "Progress tracking")
    
    @steps.each_with_index do |step, index|
      display_step_progress(step, index)
    end
    
    # Show current operation if step is running
    if current_step&.running?
      FastlaneLogger.info("Current: #{current_step.description || current_step.name}")
      FastlaneLogger.info("Status: Processing...")
    end
  end
  
  # Display summary of all steps
  def display_final_summary
    FastlaneLogger.subheader("📊 Deployment Summary")
    
    total_time = 0
    failed_steps = []
    
    @steps.each do |step|
      status_icon = case step.status
                   when :completed then "✅"
                   when :failed then "❌"
                   when :running then "🔄"
                   else "⏳"
                   end
      
      duration_text = step.duration > 0 ? format_duration(step.duration) : ""
      
      FastlaneLogger.info("#{status_icon} #{step.name.ljust(25)} #{duration_text}")
      
      total_time += step.duration if step.completed?
      failed_steps << step if step.failed?
    end
    
    FastlaneLogger.info("Total Time: #{format_duration(total_time)}")
    
    if failed_steps.any?
      FastlaneLogger.error("❌ Failed Steps:")
      failed_steps.each do |step|
        FastlaneLogger.error("   • #{step.name}: #{step.message}")
      end
    else
      FastlaneLogger.success("🎉 All steps completed successfully!")
    end
  end
  
  # Update step description while running
  def update_step_status(message)
    return unless current_step&.running?
    
    FastlaneLogger.info("Status: #{message}")
  end
  
  private
  
  def display_step_progress(step, index)
    # Step number and status
    step_num = "[#{(index + 1).to_s.rjust(2)}]"
    
    status_icon = case step.status
                 when :completed then "✅"
                 when :failed then "❌" 
                 when :running then "🔄"
                 else "⏳"
                 end
    
    # Progress bar for current/completed steps
    if step.completed? || step.failed?
      progress_bar = create_progress_bar(100)
      percentage = "100%"
    elsif step.running?
      # Animated progress for running step
      progress_percentage = ((Time.now.to_f * 2) % 1 * 100).to_i
      progress_bar = create_progress_bar(progress_percentage)
      percentage = "#{progress_percentage}%"
    else
      progress_bar = create_progress_bar(0)
      percentage = "  0%"
    end
    
    # Duration
    duration_text = step.duration > 0 ? " (#{format_duration(step.duration)})" : ""
    
    # Color based on status
    color = case step.status
           when :completed then FastlaneLogger::COLORS[:INFO]
           when :failed then FastlaneLogger::COLORS[:ERROR]
           when :running then FastlaneLogger::COLORS[:WARN]
           else FastlaneLogger::COLORS[:DIM]
           end
    
    step_name = step.name.ljust(20)
    
    FastlaneLogger.info("#{step_num} #{status_icon} #{step_name} #{progress_bar} #{percentage}#{duration_text}")
  end
  
  def create_progress_bar(percentage, width = 20)
    filled = (width * percentage / 100).to_i
    empty = width - filled
    
    filled_char = "█"
    empty_char = "▒"
    
    bar = "#{FastlaneLogger::COLORS[:INFO]}#{filled_char * filled}#{FastlaneLogger::COLORS[:DIM]}#{empty_char * empty}#{FastlaneLogger::COLORS[:RESET]}"
    "[#{bar}]"
  end
  
  def format_duration(duration_ms)
    if duration_ms < 1000
      "#{duration_ms.to_i}ms"
    elsif duration_ms < 60000
      "#{(duration_ms / 1000).round(1)}s"
    else
      minutes = (duration_ms / 60000).to_i
      seconds = ((duration_ms % 60000) / 1000).round(1)
      "#{minutes}m #{seconds}s"
    end
  end
  
  def log_step_start(step)
    FastlaneLogger.info("Starting: #{step.name}", 
                       step: step.name,
                       description: step.description,
                       step_index: @current_step_index + 1,
                       total_steps: @steps.length)
  end
  
  def log_step_completion(step)
    if step.completed?
      FastlaneLogger.success("Completed: #{step.name}",
                           step: step.name,
                           duration_ms: step.duration,
                           message: step.message)
    else
      FastlaneLogger.error("Failed: #{step.name}",
                         step: step.name,
                         duration_ms: step.duration,
                         error: step.message)
    end
  end
end

# Convenience method for FastLane integration
def create_progress_tracker(steps)
  ProgressTracker.new(steps)
end