# Comprehensive Error Handling and Recovery System
# Provides intelligent error handling with automatic recovery strategies

require_relative 'logger'

class ErrorHandler
  # Base class for all FastLane deployment errors
  class DeploymentError < StandardError
    attr_reader :error_code, :recovery_suggestions, :context, :original_error
    
    def initialize(message, error_code: nil, recovery_suggestions: [], context: {}, original: nil)
      super(message)
      @error_code = error_code
      @recovery_suggestions = recovery_suggestions
      @context = context
      @original_error = original
    end
    
    def recoverable?
      !@recovery_suggestions.empty?
    end
  end
  
  # Specific error types for different failure scenarios
  class CertificateError < DeploymentError; end
  class ProfileError < DeploymentError; end
  class BuildError < DeploymentError; end
  class UploadError < DeploymentError; end
  class APIError < DeploymentError; end
  class ValidationError < DeploymentError; end
  class KeychainError < DeploymentError; end
  
  # Recovery strategies for different error types
  RECOVERY_STRATEGIES = {
    certificate_import_failed: [
      "Unlock keychain and retry",
      "Reset keychain partition list",
      "Import certificate manually"
    ],
    certificate_not_found: [
      "Create new certificate via API",
      "Check apple_info directory for P12 files",
      "Verify team ID matches certificate"
    ],
    profile_expired: [
      "Create new provisioning profile",
      "Update existing profile with latest certificate",
      "Download profile from developer portal"
    ],
    api_rate_limit: [
      "Wait and retry with exponential backoff",
      "Use cached data if available",
      "Reduce API call frequency"
    ],
    build_failed: [
      "Clean build folder and retry",
      "Check code signing settings",
      "Verify scheme and configuration"
    ],
    upload_timeout: [
      "Retry upload with exponential backoff",
      "Check network connectivity",
      "Verify IPA file integrity"
    ]
  }.freeze
  
  class << self
    # Wrap operations with comprehensive error handling
    def with_error_handling(operation_name, context = {}, &block)
      begin
        result = yield
        FastlaneLogger.success("#{operation_name} completed successfully", context)
        result
      rescue => e
        handle_error(e, operation_name, context)
      end
    end
    
    # Main error handling entry point
    def handle_error(error, operation_name, context = {})
      classified_error = classify_error(error, operation_name, context)
      
      log_error_details(classified_error, operation_name, context)
      
      # Attempt automatic recovery if possible
      if classified_error.recoverable? && should_attempt_recovery?(classified_error)
        FastlaneLogger.info("Attempting automatic recovery for #{operation_name}...")
        
        recovery_result = attempt_recovery(classified_error, operation_name, context)
        
        if recovery_result[:success]
          FastlaneLogger.success("Recovery successful for #{operation_name}", 
                                recovery_strategy: recovery_result[:strategy])
          return recovery_result[:result]
        else
          FastlaneLogger.error("Recovery failed for #{operation_name}",
                              recovery_strategy: recovery_result[:strategy],
                              recovery_error: recovery_result[:error])
        end
      end
      
      # If recovery failed or not attempted, provide helpful guidance
      provide_user_guidance(classified_error, operation_name)
      
      # Re-raise the classified error
      raise classified_error
    end
    
    # Classify generic errors into specific deployment error types
    def classify_error(error, operation_name, context = {})
      case error
      when DeploymentError
        # Already classified
        return error
      when StandardError
        classify_standard_error(error, operation_name, context)
      else
        # Unknown error type
        DeploymentError.new(
          "Unknown error during #{operation_name}: #{error.message}",
          error_code: 'UNKNOWN_ERROR',
          context: context.merge(error_class: error.class.name),
          original: error
        )
      end
    end
    
    private
    
    def classify_standard_error(error, operation_name, context)
      message = error.message.downcase
      
      # Certificate-related errors
      if message.include?('shell command exited with exit status 1') && 
         (operation_name.include?('certificate') || message.include?('p12'))
        CertificateError.new(
          "Certificate import failed: #{error.message}",
          error_code: 'CERTIFICATE_IMPORT_FAILED',
          recovery_suggestions: RECOVERY_STRATEGIES[:certificate_import_failed],
          context: context,
          original: error
        )
      elsif message.include?('certificate') && message.include?('not found')
        CertificateError.new(
          "Certificate not found: #{error.message}",
          error_code: 'CERTIFICATE_NOT_FOUND',
          recovery_suggestions: RECOVERY_STRATEGIES[:certificate_not_found],
          context: context,
          original: error
        )
      
      # Profile-related errors
      elsif message.include?('provisioning profile') && message.include?('expired')
        ProfileError.new(
          "Provisioning profile expired: #{error.message}",
          error_code: 'PROFILE_EXPIRED',
          recovery_suggestions: RECOVERY_STRATEGIES[:profile_expired],
          context: context,
          original: error
        )
      
      # API-related errors
      elsif message.include?('rate limit') || message.include?('too many requests')
        APIError.new(
          "API rate limit exceeded: #{error.message}",
          error_code: 'API_RATE_LIMIT',
          recovery_suggestions: RECOVERY_STRATEGIES[:api_rate_limit],
          context: context,
          original: error
        )
      
      # Build-related errors
      elsif message.include?('build failed') || message.include?('archive failed')
        BuildError.new(
          "Build failed: #{error.message}",
          error_code: 'BUILD_FAILED',
          recovery_suggestions: RECOVERY_STRATEGIES[:build_failed],
          context: context,
          original: error
        )
      
      # Upload-related errors
      elsif message.include?('upload') && (message.include?('timeout') || message.include?('failed'))
        UploadError.new(
          "Upload failed: #{error.message}",
          error_code: 'UPLOAD_TIMEOUT',
          recovery_suggestions: RECOVERY_STRATEGIES[:upload_timeout],
          context: context,
          original: error
        )
      
      else
        # Generic deployment error
        DeploymentError.new(
          "Deployment error during #{operation_name}: #{error.message}",
          error_code: 'DEPLOYMENT_ERROR',
          context: context,
          original: error
        )
      end
    end
    
    def log_error_details(error, operation_name, context)
      FastlaneLogger.error("Error in #{operation_name}: #{error.message}",
                          error_code: error.error_code,
                          error_class: error.class.name,
                          context: context)
      
      if error.original_error
        FastlaneLogger.error("Original error details",
                            original_message: error.original_error.message,
                            original_class: error.original_error.class.name,
                            backtrace: error.original_error.backtrace&.first(5))
      end
      
      if error.recoverable?
        FastlaneLogger.info("Recovery options available",
                           recovery_strategies: error.recovery_suggestions)
      end
    end
    
    def should_attempt_recovery?(error)
      # Only attempt recovery for specific error types that are safe to retry
      recovery_safe_errors = [
        'CERTIFICATE_IMPORT_FAILED',
        'API_RATE_LIMIT',
        'UPLOAD_TIMEOUT'
      ]
      
      recovery_safe_errors.include?(error.error_code)
    end
    
    def attempt_recovery(error, operation_name, context)
      case error.error_code
      when 'CERTIFICATE_IMPORT_FAILED'
        attempt_certificate_import_recovery(error, context)
      when 'API_RATE_LIMIT'
        attempt_api_rate_limit_recovery(error, context)
      when 'UPLOAD_TIMEOUT'
        attempt_upload_timeout_recovery(error, context)
      else
        { success: false, strategy: 'none', error: 'No recovery strategy available' }
      end
    end
    
    def attempt_certificate_import_recovery(error, context)
      begin
        FastlaneLogger.info("Attempting certificate import recovery")
        
        # Strategy 1: Unlock keychain and retry
        FastlaneLogger.info("Unlocking keychain...")
        `security unlock-keychain`
        
        # Strategy 2: Reset partition list
        FastlaneLogger.info("Resetting keychain partition list...")
        `security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k '' login.keychain`
        
        { success: true, strategy: 'keychain_unlock_and_reset', result: nil }
      rescue => recovery_error
        { success: false, strategy: 'keychain_unlock_and_reset', error: recovery_error.message }
      end
    end
    
    def attempt_api_rate_limit_recovery(error, context)
      begin
        # Exponential backoff strategy
        wait_time = calculate_backoff_time(context[:retry_count] || 0)
        
        FastlaneLogger.info("API rate limit hit, waiting #{wait_time}s before retry...")
        sleep(wait_time)
        
        { success: true, strategy: 'exponential_backoff', result: nil }
      rescue => recovery_error
        { success: false, strategy: 'exponential_backoff', error: recovery_error.message }
      end
    end
    
    def attempt_upload_timeout_recovery(error, context)
      begin
        # Check network connectivity first
        if test_network_connectivity
          retry_count = context[:retry_count] || 0
          
          if retry_count < 3
            wait_time = calculate_backoff_time(retry_count)
            FastlaneLogger.info("Upload timeout, retrying in #{wait_time}s (attempt #{retry_count + 1}/3)...")
            sleep(wait_time)
            
            { success: true, strategy: 'retry_with_backoff', result: nil }
          else
            { success: false, strategy: 'retry_with_backoff', error: 'Maximum retry attempts exceeded' }
          end
        else
          { success: false, strategy: 'network_check', error: 'Network connectivity issues detected' }
        end
      rescue => recovery_error
        { success: false, strategy: 'upload_retry', error: recovery_error.message }
      end
    end
    
    def calculate_backoff_time(retry_count)
      # Exponential backoff: 2^retry_count seconds, max 60 seconds
      [2 ** retry_count, 60].min
    end
    
    def test_network_connectivity
      begin
        require 'net/http'
        uri = URI('https://api.appstoreconnect.apple.com')
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        http.open_timeout = 10
        http.read_timeout = 10
        
        response = http.head('/')
        response.code.to_i < 500
      rescue
        false
      end
    end
    
    def provide_user_guidance(error, operation_name)
      FastlaneLogger.subheader("🔧 Troubleshooting Guidance")
      
      FastlaneLogger.error("Operation Failed: #{operation_name}")
      FastlaneLogger.error("Error Code: #{error.error_code}")
      
      if error.recoverable?
        FastlaneLogger.warn("📋 Recovery Suggestions:")
        error.recovery_suggestions.each_with_index do |suggestion, index|
          FastlaneLogger.info("   #{index + 1}. #{suggestion}")
        end
      end
      
      # Provide context-specific guidance
      case error.error_code
      when 'CERTIFICATE_IMPORT_FAILED'
        FastlaneLogger.info("💡 Common Solutions:")
        FastlaneLogger.info("   • Ensure the P12 password is correct")
        FastlaneLogger.info("   • Check that the P12 file is not corrupted")
        FastlaneLogger.info("   • Verify the certificate matches your team ID")
      when 'PROFILE_EXPIRED'
        FastlaneLogger.info("💡 Next Steps:")
        FastlaneLogger.info("   • Log into Apple Developer Portal")
        FastlaneLogger.info("   • Create a new provisioning profile")
        FastlaneLogger.info("   • Download and install the new profile")
      when 'BUILD_FAILED'
        FastlaneLogger.info("💡 Build Troubleshooting:")
        FastlaneLogger.info("   • Check Xcode project settings")
        FastlaneLogger.info("   • Verify code signing configuration")
        FastlaneLogger.info("   • Clean build folder and retry")
      end
      
      FastlaneLogger.info("For more help, check TESTS.md or run: ./scripts/deploy.sh help")
    end
  end
end

# Convenience methods for FastLane integration
def with_error_handling(operation_name, context = {}, &block)
  ErrorHandler.with_error_handling(operation_name, context, &block)
end

def handle_deployment_error(error, operation_name, context = {})
  ErrorHandler.handle_error(error, operation_name, context)
end