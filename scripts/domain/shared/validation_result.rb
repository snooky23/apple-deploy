# frozen_string_literal: true

##
# ValidationResult
#
# A standardized result object for validation operations across the domain layer.
# Provides consistent interface for success/failure states, error handling, and data payload.
#
# @example Success case
#   result = ValidationResult.new(success: true, data: { count: 5 })
#   puts result.data[:count] if result.success?
#
# @example Failure case
#   result = ValidationResult.new(
#     success: false,
#     errors: [{ message: "Invalid input", code: "VALIDATION_001" }]
#   )
#   puts result.errors.first[:message] if result.failure?
#
class ValidationResult
  attr_reader :errors, :warnings, :data

  ##
  # Initialize ValidationResult
  #
  # @param success [Boolean] Whether the validation succeeded
  # @param errors [Array<Hash>] Array of error objects with details
  # @param warnings [Array<Hash>] Array of warning objects with details
  # @param data [Hash] Additional data payload from validation
  def initialize(success:, errors: [], warnings: [], data: {})
    @success = success
    @errors = errors || []
    @warnings = warnings || []
    @data = data || {}
  end

  ##
  # Check if validation was successful
  #
  # @return [Boolean] True if validation passed
  def success?
    @success
  end

  ##
  # Check if validation failed
  #
  # @return [Boolean] True if validation failed
  def failure?
    !@success
  end

  ##
  # Check if there are any errors
  #
  # @return [Boolean] True if errors are present
  def has_errors?
    @errors.any?
  end

  ##
  # Check if there are any warnings
  #
  # @return [Boolean] True if warnings are present
  def has_warnings?
    @warnings.any?
  end

  ##
  # Get count of errors
  #
  # @return [Integer] Number of errors
  def error_count
    @errors.length
  end

  ##
  # Get count of warnings
  #
  # @return [Integer] Number of warnings
  def warning_count
    @warnings.length
  end

  ##
  # Get formatted error messages
  #
  # @return [Array<String>] Array of error message strings
  def error_messages
    @errors.map { |error| error[:message] || error['message'] }.compact
  end

  ##
  # Get formatted warning messages
  #
  # @return [Array<String>] Array of warning message strings
  def warning_messages
    @warnings.map { |warning| warning[:message] || warning['message'] }.compact
  end

  ##
  # Get summary of validation result
  #
  # @return [Hash] Summary with counts and status
  def summary
    {
      success: success?,
      error_count: error_count,
      warning_count: warning_count,
      has_data: !@data.empty?
    }
  end

  ##
  # Convert to hash representation
  #
  # @return [Hash] Complete result as hash
  def to_h
    {
      success: @success,
      errors: @errors,
      warnings: @warnings,
      data: @data
    }
  end

  ##
  # Convert to JSON string
  #
  # @return [String] JSON representation of result
  def to_json(*args)
    require 'json'
    to_h.to_json(*args)
  end
end