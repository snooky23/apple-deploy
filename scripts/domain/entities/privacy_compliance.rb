# frozen_string_literal: true

require_relative '../shared/validation_result'

##
# PrivacyCompliance Domain Entity
#
# Represents privacy compliance requirements for iOS applications.
# Handles validation of privacy usage descriptions (purpose strings) required by Apple
# for apps that access sensitive user data or device capabilities.
#
# This entity encapsulates the business logic for:
# - Privacy key definitions and requirements
# - Purpose string quality validation
# - Apple App Store compliance rules
# - Educational guidance for developers
#
# @example Basic usage
#   compliance = PrivacyCompliance.new(info_plist_data)
#   result = compliance.validate_privacy_usage_descriptions
#   puts result.errors if result.failure?
#
# @example With specific validation rules
#   compliance = PrivacyCompliance.new(info_plist_data, strict_mode: true)
#   result = compliance.validate_with_recommendations
#
class PrivacyCompliance
  # Comprehensive mapping of privacy usage description keys to human-readable descriptions
  # Based on Apple's Privacy and Data Use documentation
  PRIVACY_USAGE_KEYS = {
    # Camera and Media Access
    'NSCameraUsageDescription' => {
      description: 'Camera access',
      category: 'media',
      required_when: 'Using AVCaptureDevice, UIImagePickerController camera, or camera-related APIs',
      example: 'This app uses the camera to capture photos for your profile and document scanning.'
    },
    'NSMicrophoneUsageDescription' => {
      description: 'Microphone access',
      category: 'media',
      required_when: 'Recording audio, using speech recognition, or accessing microphone',
      example: 'This app uses the microphone to record voice notes and enable voice commands.'
    },
    'NSPhotoLibraryUsageDescription' => {
      description: 'Photo library access',
      category: 'media',
      required_when: 'Accessing photos, saving images, or browsing photo library',
      example: 'This app accesses your photo library to let you select and share images.'
    },
    'NSPhotoLibraryAddUsageDescription' => {
      description: 'Photo library additions',
      category: 'media',
      required_when: 'Saving photos to user\'s photo library',
      example: 'This app saves processed images to your photo library.'
    },

    # Location Services
    'NSLocationWhenInUseUsageDescription' => {
      description: 'Location when app is in use',
      category: 'location',
      required_when: 'Accessing location while app is active',
      example: 'This app uses your location to show nearby restaurants and provide directions.'
    },
    'NSLocationAlwaysAndWhenInUseUsageDescription' => {
      description: 'Location always and when in use',
      category: 'location',
      required_when: 'Accessing location in background and foreground',
      example: 'This app uses your location to track workouts and provide location-based reminders even when not actively using the app.'
    },
    'NSLocationAlwaysUsageDescription' => {
      description: 'Location always (deprecated)',
      category: 'location',
      required_when: 'Legacy location access (use NSLocationAlwaysAndWhenInUseUsageDescription instead)',
      example: 'This app uses your location for background tracking features.'
    },

    # Personal Data Access
    'NSContactsUsageDescription' => {
      description: 'Contacts access',
      category: 'personal_data',
      required_when: 'Reading or writing contact information',
      example: 'This app accesses your contacts to help you easily invite friends and family.'
    },
    'NSCalendarsUsageDescription' => {
      description: 'Calendar access',
      category: 'personal_data',
      required_when: 'Reading or writing calendar events',
      example: 'This app accesses your calendar to schedule appointments and sync events.'
    },
    'NSRemindersUsageDescription' => {
      description: 'Reminders access',
      category: 'personal_data',
      required_when: 'Creating or accessing reminders',
      example: 'This app accesses your reminders to help organize tasks and deadlines.'
    },

    # Device Capabilities
    'NSSpeechRecognitionUsageDescription' => {
      description: 'Speech recognition',
      category: 'device_capabilities',
      required_when: 'Using Speech framework or speech-to-text features',
      example: 'This app uses speech recognition to convert your voice commands into text for hands-free operation.'
    },
    'NSMotionUsageDescription' => {
      description: 'Motion and fitness data',
      category: 'device_capabilities',
      required_when: 'Accessing accelerometer, gyroscope, or motion data',
      example: 'This app uses motion data to track your steps and detect workout activities.'
    },
    'NSFaceIDUsageDescription' => {
      description: 'Face ID authentication',
      category: 'device_capabilities',
      required_when: 'Using Face ID for authentication',
      example: 'This app uses Face ID to securely authenticate your identity for account access.'
    },

    # Health and Fitness
    'NSHealthShareUsageDescription' => {
      description: 'Health data reading',
      category: 'health',
      required_when: 'Reading health data from HealthKit',
      example: 'This app reads your health data to provide personalized fitness recommendations.'
    },
    'NSHealthUpdateUsageDescription' => {
      description: 'Health data writing',
      category: 'health',
      required_when: 'Writing health data to HealthKit',
      example: 'This app writes workout data to your Health app to track your fitness progress.'
    },

    # Bluetooth and Networking
    'NSBluetoothAlwaysUsageDescription' => {
      description: 'Bluetooth access',
      category: 'connectivity',
      required_when: 'Using Bluetooth for device communication',
      example: 'This app uses Bluetooth to connect with fitness trackers and smart devices.'
    },
    'NSBluetoothPeripheralUsageDescription' => {
      description: 'Bluetooth peripheral mode',
      category: 'connectivity',
      required_when: 'Acting as Bluetooth peripheral',
      example: 'This app uses Bluetooth to share data with other nearby devices.'
    },
    'NSLocalNetworkUsageDescription' => {
      description: 'Local network access',
      category: 'connectivity',
      required_when: 'Discovering and connecting to local network devices',
      example: 'This app discovers devices on your local network to enable wireless printing and file sharing.'
    },

    # Privacy and Tracking
    'NSUserTrackingUsageDescription' => {
      description: 'App tracking transparency',
      category: 'tracking',
      required_when: 'Tracking users across apps and websites',
      example: 'This app would like to track your activity across other companies\' apps and websites to provide personalized advertisements.'
    },

    # Media Library Access
    'NSAppleMusicUsageDescription' => {
      description: 'Apple Music and media library',
      category: 'media',
      required_when: 'Accessing user\'s music library',
      example: 'This app accesses your music library to create custom playlists and analyze your listening preferences.'
    },

    # File System Access
    'NSDesktopFolderUsageDescription' => {
      description: 'Desktop folder access',
      category: 'file_system',
      required_when: 'Accessing desktop folder (macOS)',
      example: 'This app accesses your desktop folder to save and organize project files.'
    },
    'NSDocumentsFolderUsageDescription' => {
      description: 'Documents folder access',
      category: 'file_system',
      required_when: 'Accessing documents folder (macOS)',
      example: 'This app accesses your documents folder to save and manage your files.'
    },
    'NSDownloadsFolderUsageDescription' => {
      description: 'Downloads folder access',
      category: 'file_system',
      required_when: 'Accessing downloads folder (macOS)',
      example: 'This app accesses your downloads folder to import files you\'ve downloaded.'
    }
  }.freeze

  # Common placeholder patterns that indicate incomplete purpose strings
  PLACEHOLDER_PATTERNS = [
    /^TODO/i,
    /^CHANGEME/i,
    /^PLACEHOLDER/i,
    /^This app uses/i,
    /^App uses/i,
    /^Your app/i,
    /^Replace this/i,
    /^Add description/i,
    /^Purpose string/i
  ].freeze

  # Minimum character count for purpose strings (Apple recommends detailed explanations)
  MIN_PURPOSE_STRING_LENGTH = 20

  attr_reader :info_plist_data, :strict_mode, :validation_errors, :validation_warnings

  ##
  # Initialize PrivacyCompliance entity
  #
  # @param info_plist_data [Hash] Parsed Info.plist data
  # @param strict_mode [Boolean] Whether to apply strict validation rules
  def initialize(info_plist_data, strict_mode: false)
    @info_plist_data = info_plist_data || {}
    @strict_mode = strict_mode
    @validation_errors = []
    @validation_warnings = []
  end

  ##
  # Validate privacy usage descriptions in the Info.plist
  #
  # @return [ValidationResult] Result containing validation status and details
  def validate_privacy_usage_descriptions
    reset_validation_state
    
    present_keys = find_present_privacy_keys
    missing_descriptions = find_missing_descriptions(present_keys)
    problematic_descriptions = find_problematic_descriptions(present_keys)
    
    # Add errors for missing descriptions
    missing_descriptions.each do |key|
      @validation_errors << {
        key: key,
        type: 'missing_description',
        message: "#{PRIVACY_USAGE_KEYS[key][:description]} (#{key}): Missing or empty purpose string",
        category: PRIVACY_USAGE_KEYS[key][:category],
        fix_suggestion: "Add #{key} to Info.plist with description: \"#{PRIVACY_USAGE_KEYS[key][:example]}\""
      }
    end
    
    # Add warnings for problematic descriptions
    problematic_descriptions.each do |issue|
      @validation_warnings << issue
    end
    
    create_validation_result(present_keys, missing_descriptions, problematic_descriptions)
  end

  ##
  # Get comprehensive validation report with recommendations
  #
  # @return [ValidationResult] Detailed validation result with fix recommendations
  def validate_with_recommendations
    result = validate_privacy_usage_descriptions
    
    # Add recommendations based on detected issues
    recommendations = generate_recommendations
    
    ValidationResult.new(
      success: result.success?,
      errors: @validation_errors,
      warnings: @validation_warnings,
      data: result.data.merge(recommendations: recommendations)
    )
  end

  ##
  # Check if app appears to need specific privacy permissions
  #
  # @param frameworks [Array<String>] List of linked frameworks
  # @param source_files [Array<String>] List of source file paths for analysis
  # @return [Array<String>] List of potentially required privacy keys
  def detect_required_privacy_keys(frameworks: [], source_files: [])
    required_keys = []
    
    # Framework-based detection
    framework_requirements = {
      'AVFoundation' => ['NSCameraUsageDescription', 'NSMicrophoneUsageDescription'],
      'CoreLocation' => ['NSLocationWhenInUseUsageDescription'],
      'Contacts' => ['NSContactsUsageDescription'],
      'EventKit' => ['NSCalendarsUsageDescription', 'NSRemindersUsageDescription'],
      'Speech' => ['NSSpeechRecognitionUsageDescription'],
      'CoreMotion' => ['NSMotionUsageDescription'],
      'HealthKit' => ['NSHealthShareUsageDescription', 'NSHealthUpdateUsageDescription'],
      'CoreBluetooth' => ['NSBluetoothAlwaysUsageDescription'],
      'Photos' => ['NSPhotoLibraryUsageDescription'],
      'MediaPlayer' => ['NSAppleMusicUsageDescription']
    }
    
    frameworks.each do |framework|
      if framework_requirements.key?(framework)
        required_keys.concat(framework_requirements[framework])
      end
    end
    
    # TODO: Add source code analysis for API usage detection
    # This would scan source files for specific API calls that require privacy strings
    
    required_keys.uniq
  end

  ##
  # Get privacy key information
  #
  # @param key [String] Privacy usage description key
  # @return [Hash, nil] Key information or nil if not found
  def privacy_key_info(key)
    PRIVACY_USAGE_KEYS[key]
  end

  ##
  # Get all supported privacy keys by category
  #
  # @return [Hash] Privacy keys grouped by category
  def privacy_keys_by_category
    PRIVACY_USAGE_KEYS.group_by { |_, info| info[:category] }
  end

  private

  def reset_validation_state
    @validation_errors = []
    @validation_warnings = []
  end

  def find_present_privacy_keys
    PRIVACY_USAGE_KEYS.keys.select do |key|
      @info_plist_data.key?(key) && !@info_plist_data[key].nil?
    end
  end

  def find_missing_descriptions(present_keys)
    present_keys.select do |key|
      description = @info_plist_data[key]
      description.nil? || description.strip.empty?
    end
  end

  def find_problematic_descriptions(present_keys)
    problems = []
    
    present_keys.each do |key|
      description = @info_plist_data[key]
      next if description.nil? || description.strip.empty?
      
      # Check for placeholder patterns
      PLACEHOLDER_PATTERNS.each do |pattern|
        if description.match?(pattern)
          problems << {
            key: key,
            type: 'placeholder_text',
            message: "#{PRIVACY_USAGE_KEYS[key][:description]} (#{key}): Appears to contain placeholder text",
            description: description,
            fix_suggestion: "Replace with specific explanation: \"#{PRIVACY_USAGE_KEYS[key][:example]}\""
          }
          break
        end
      end
      
      # Check for insufficient length
      if description.length < MIN_PURPOSE_STRING_LENGTH
        problems << {
          key: key,
          type: 'insufficient_length',
          message: "#{PRIVACY_USAGE_KEYS[key][:description]} (#{key}): Purpose string may be too brief (#{description.length} characters)",
          description: description,
          fix_suggestion: "Provide more detailed explanation (recommended: #{MIN_PURPOSE_STRING_LENGTH}+ characters)"
        }
      end
    end
    
    problems
  end

  def generate_recommendations
    recommendations = []
    
    # Add general recommendations based on validation results
    if @validation_errors.any?
      recommendations << {
        type: 'error_fix',
        priority: 'high',
        message: 'Fix missing privacy usage descriptions to prevent TestFlight upload failures',
        action: 'Add required purpose strings to Info.plist file'
      }
    end
    
    if @validation_warnings.any?
      recommendations << {
        type: 'quality_improvement',
        priority: 'medium',
        message: 'Improve purpose string quality for better App Store review experience',
        action: 'Replace placeholder text with specific, user-friendly explanations'
      }
    end
    
    # Add educational recommendations
    recommendations << {
      type: 'education',
      priority: 'low',
      message: 'Learn more about privacy best practices',
      action: 'Visit Apple\'s Privacy and Data Use documentation'
    }
    
    recommendations
  end

  def create_validation_result(present_keys, missing_descriptions, problematic_descriptions)
    success = missing_descriptions.empty? && (@strict_mode ? problematic_descriptions.empty? : true)
    
    ValidationResult.new(
      success: success,
      errors: @validation_errors,
      warnings: @validation_warnings,
      data: {
        total_privacy_keys: present_keys.length,
        missing_descriptions_count: missing_descriptions.length,
        problematic_descriptions_count: problematic_descriptions.length,
        present_keys: present_keys,
        missing_keys: missing_descriptions,
        validation_mode: @strict_mode ? 'strict' : 'standard'
      }
    )
  end
end