# Base Repository Interface - Clean Architecture Domain Layer
# Provides common repository functionality and patterns

module BaseRepository
  # Common Repository Operations
  
  # Repository identification
  # @return [String] Unique identifier for this repository instance
  def repository_id
    "#{repository_type}_#{object_id}"
  end
  
  # Repository type - must be implemented by subclasses
  # @return [String] Repository type identifier
  def repository_type
    raise NotImplementedError, "Subclass must implement repository_type"
  end
  
  # Availability check - must be implemented by subclasses
  # @return [Boolean] True if repository is available
  def available?
    raise NotImplementedError, "Subclass must implement available?"
  end
  
  # Health check with detailed information
  # @return [RepositoryHealth] Health status with diagnostics
  def health_check
    RepositoryHealth.new(
      repository_id: repository_id,
      repository_type: repository_type,
      available: available?,
      checked_at: Time.now,
      details: perform_health_check
    )
  end
  
  # Connection test
  # @return [Boolean] True if connection is working
  def test_connection
    begin
      available? && perform_connection_test
    rescue => e
      false
    end
  end
  
  # Common Error Handling
  
  # Handle repository errors with consistent behavior
  # @param error [Exception] Original error
  # @param operation [String] Operation that failed
  # @param context [Hash] Additional context information
  # @return [RepositoryError] Standardized repository error
  def handle_repository_error(error, operation, context = {})
    RepositoryError.new(
      message: "Repository operation failed: #{operation}",
      original_error: error,
      repository_type: repository_type,
      repository_id: repository_id,
      operation: operation,
      context: context,
      timestamp: Time.now
    )
  end
  
  # Wrap operation with error handling
  # @param operation_name [String] Name of operation for error reporting
  # @param context [Hash] Additional context for error reporting
  # @yield Block to execute with error handling
  # @return [Object] Result of the block execution
  def with_error_handling(operation_name, context = {})
    begin
      yield
    rescue => error
      raise handle_repository_error(error, operation_name, context)
    end
  end
  
  # Validation Helpers
  
  # Validate required parameters
  # @param params [Hash] Parameters to validate
  # @param required_keys [Array<Symbol>] Required parameter keys
  # @raises [ArgumentError] If required parameters are missing
  def validate_required_params(params, required_keys)
    missing_keys = required_keys - params.keys
    unless missing_keys.empty?
      raise ArgumentError, "Missing required parameters: #{missing_keys.join(', ')}"
    end
    
    # Check for nil values
    nil_keys = required_keys.select { |key| params[key].nil? }
    unless nil_keys.empty?
      raise ArgumentError, "Required parameters cannot be nil: #{nil_keys.join(', ')}"
    end
  end
  
  # Validate team ID format
  # @param team_id [String] Team ID to validate
  # @raises [ArgumentError] If team ID is invalid
  def validate_team_id(team_id)
    unless team_id.is_a?(String) && team_id.match?(/^[A-Z0-9]{10}$/)
      raise ArgumentError, "Invalid team ID format: #{team_id}. Expected 10 alphanumeric characters."
    end
  end
  
  # Validate app identifier format
  # @param app_identifier [String] App identifier to validate
  # @raises [ArgumentError] If app identifier is invalid
  def validate_app_identifier(app_identifier)
    unless app_identifier.is_a?(String) && app_identifier.include?('.')
      raise ArgumentError, "Invalid app identifier format: #{app_identifier}"
    end
  end
  
  # Validate file path existence
  # @param file_path [String] File path to validate
  # @raises [ArgumentError] If file doesn't exist
  def validate_file_exists(file_path)
    unless File.exist?(file_path)
      raise ArgumentError, "File not found: #{file_path}"
    end
  end
  
  # Caching Support
  
  # Simple in-memory cache for repository operations
  # @return [Hash] Cache storage
  def cache
    @cache ||= {}
  end
  
  # Get value from cache
  # @param key [String] Cache key
  # @return [Object, nil] Cached value or nil
  def get_cached(key)
    cache_entry = cache[key]
    return nil unless cache_entry
    
    # Check expiration
    if cache_entry[:expires_at] && Time.now > cache_entry[:expires_at]
      cache.delete(key)
      return nil
    end
    
    cache_entry[:value]
  end
  
  # Set value in cache
  # @param key [String] Cache key
  # @param value [Object] Value to cache
  # @param ttl [Integer, nil] Time to live in seconds
  def set_cached(key, value, ttl = nil)
    cache_entry = { value: value }
    cache_entry[:expires_at] = Time.now + ttl if ttl
    cache[key] = cache_entry
    value
  end
  
  # Clear cache
  # @param pattern [String, nil] Optional pattern to match keys
  def clear_cache(pattern = nil)
    if pattern
      matching_keys = cache.keys.select { |key| key.match?(pattern) }
      matching_keys.each { |key| cache.delete(key) }
    else
      cache.clear
    end
  end
  
  # Logging Support
  
  # Log repository operation
  # @param level [Symbol] Log level (:info, :warn, :error)
  # @param message [String] Log message
  # @param context [Hash] Additional context
  def log_operation(level, message, context = {})
    # Use logger if available (will be injected via DI)
    if respond_to?(:logger) && logger
      logger.send(level, message, context.merge(
        repository_type: repository_type,
        repository_id: repository_id
      ))
    end
  end
  
  private
  
  # Perform detailed health check - override in subclasses
  # @return [Hash] Health check details
  def perform_health_check
    {
      basic_connectivity: test_connection,
      last_check: Time.now
    }
  end
  
  # Perform connection test - override in subclasses
  # @return [Boolean] True if connection successful
  def perform_connection_test
    true
  end
end

# Repository Health Status
class RepositoryHealth
  attr_reader :repository_id, :repository_type, :available, :checked_at, :details
  
  def initialize(repository_id:, repository_type:, available:, checked_at:, details:)
    @repository_id = repository_id
    @repository_type = repository_type
    @available = available
    @checked_at = checked_at
    @details = details
  end
  
  def healthy?
    @available
  end
  
  def to_hash
    {
      repository_id: repository_id,
      repository_type: repository_type,
      available: available,
      healthy: healthy?,
      checked_at: checked_at,
      details: details
    }
  end
end

# Repository Error
class RepositoryError < StandardError
  attr_reader :original_error, :repository_type, :repository_id, :operation, :context, :timestamp
  
  def initialize(message:, original_error:, repository_type:, repository_id:, operation:, context:, timestamp:)
    super(message)
    @original_error = original_error
    @repository_type = repository_type
    @repository_id = repository_id
    @operation = operation
    @context = context
    @timestamp = timestamp
  end
  
  def to_hash
    {
      message: message,
      original_error: original_error&.message,
      repository_type: repository_type,
      repository_id: repository_id,
      operation: operation,
      context: context,
      timestamp: timestamp
    }
  end
end