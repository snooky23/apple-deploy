#!/usr/bin/env ruby
# Application Domain Entity Tests - Clean Architecture Unit Tests

require_relative '../../../../scripts/domain/entities/application'
require 'date'

class ApplicationTest
  def self.run_all_tests
    puts "🧪 Testing Application Domain Entity..."
    
    test_application_creation
    test_bundle_identifier_validation
    test_version_management
    test_version_increment
    test_build_number_management
    test_app_store_validation
    test_platform_support
    test_team_ownership
    test_display_name_validation
    test_metadata_management
    test_version_comparison
    test_immutability_patterns
    test_equality_and_comparison
    test_serialization
    test_class_methods
    test_validation_errors
    
    puts "✅ All Application entity tests passed!"
  end
  
  def self.test_application_creation
    puts "  → Testing application creation..."
    
    # Valid application creation
    app = Application.new(
      bundle_identifier: "com.yourcompany.yourapp.app",
      name: "Voice Forms",
      display_name: "Voice Forms Pro",
      scheme: "VoiceFormsScheme",
      team_id: "YOUR_TEAM_ID",
      marketing_version: "1.2.3",
      build_number: "42"
    )
    
    raise "Bundle identifier should be set" unless app.bundle_identifier == "com.yourcompany.yourapp.app"
    raise "App name should be set" unless app.name == "Voice Forms"
    raise "Display name should be set" unless app.display_name == "Voice Forms Pro"
    raise "Scheme should be set" unless app.scheme == "VoiceFormsScheme"
    raise "Team ID should be set" unless app.team_id == "YOUR_TEAM_ID"
    raise "Marketing version should be set" unless app.marketing_version == "1.2.3"
    raise "Build number should be set" unless app.build_number == "42"
    raise "Platform should default to ios" unless app.platform == "ios"
    
    puts "    ✓ Application creation works"
  end
  
  def self.test_bundle_identifier_validation
    puts "  → Testing bundle identifier validation..."
    
    # Valid bundle identifiers
    valid_ids = [
      "com.company.app",
      "org.example.myapp",
      "net.domain.sub.application",
      "io.github.user.project"
    ]
    
    valid_ids.each do |bundle_id|
      app = Application.new(
        bundle_identifier: bundle_id,
        name: "Test App",
        display_name: "Test App",
        scheme: "TestScheme",
        team_id: "ABC1234567",
        marketing_version: "1.0.0",
        build_number: "1"
      )
      raise "Should accept valid bundle ID: #{bundle_id}" unless app.valid_bundle_identifier?
    end
    
    # Test domain extraction
    app = Application.new(
      bundle_identifier: "com.yourcompany.yourapp.myapp.extension",
      name: "Test App",
      display_name: "Test App", 
      scheme: "TestScheme",
      team_id: "ABC1234567",
      marketing_version: "1.0.0",
      build_number: "1"
    )
    
    raise "Should extract correct domain" unless app.bundle_domain == "com.yourcompany.yourapp.myapp"
    raise "Should extract correct app name" unless app.bundle_app_name == "extension"
    raise "Should recognize domain ownership" unless app.belongs_to_domain?("com.yourcompany.yourapp")
    raise "Should reject wrong domain" if app.belongs_to_domain?("com.other")
    
    puts "    ✓ Bundle identifier validation works"
  end
  
  def self.test_version_management
    puts "  → Testing version management..."
    
    app = Application.new(
      bundle_identifier: "com.test.app",
      name: "Test App",
      display_name: "Test App",
      scheme: "TestScheme", 
      team_id: "ABC1234567",
      marketing_version: "2.1.5",
      build_number: "100"
    )
    
    # Test version parsing
    version_info = app.parse_marketing_version
    raise "Should parse major version" unless version_info[:major] == 2
    raise "Should parse minor version" unless version_info[:minor] == 1
    raise "Should parse patch version" unless version_info[:patch] == 5
    raise "Should be valid version" unless app.valid_marketing_version?
    
    # Test prerelease version
    prerelease_app = Application.new(
      bundle_identifier: "com.test.app",
      name: "Test App",
      display_name: "Test App",
      scheme: "TestScheme",
      team_id: "ABC1234567", 
      marketing_version: "1.0.0-beta.1",
      build_number: "1"
    )
    
    raise "Should detect prerelease version" unless prerelease_app.marketing_version_preview?
    raise "Should not be ready for app store" if prerelease_app.ready_for_app_store?
    
    puts "    ✓ Version management works correctly"
  end
  
  def self.test_version_increment
    puts "  → Testing version increment..."
    
    app = Application.new(
      bundle_identifier: "com.test.app",
      name: "Test App",
      display_name: "Test App",
      scheme: "TestScheme",
      team_id: "ABC1234567",
      marketing_version: "1.2.3",
      build_number: "10"
    )
    
    # Test major increment
    major_version = app.increment_marketing_version("major")
    raise "Major increment should be 2.0.0" unless major_version == "2.0.0"
    
    # Test minor increment  
    minor_version = app.increment_marketing_version("minor")
    raise "Minor increment should be 1.3.0" unless minor_version == "1.3.0"
    
    # Test patch increment
    patch_version = app.increment_marketing_version("patch")
    raise "Patch increment should be 1.2.4" unless patch_version == "1.2.4"
    
    # Test next version
    next_patch = app.next_version("patch")
    raise "Next patch should be 1.2.4" unless next_patch == "1.2.4"
    
    # Test with_incremented_version (immutability)
    new_app = app.with_incremented_version("minor")
    raise "Original app version should be unchanged" unless app.marketing_version == "1.2.3"
    raise "New app version should be incremented" unless new_app.marketing_version == "1.3.0"
    
    puts "    ✓ Version increment works correctly"
  end
  
  def self.test_build_number_management
    puts "  → Testing build number management..."
    
    app = Application.new(
      bundle_identifier: "com.test.app",
      name: "Test App",
      display_name: "Test App",
      scheme: "TestScheme",
      team_id: "ABC1234567",
      marketing_version: "1.0.0",
      build_number: "42"
    )
    
    raise "Should validate build number" unless app.valid_build_number?
    
    # Test build increment
    next_build = app.increment_build_number
    raise "Next build should be 43" unless next_build == "43"
    
    next_build_by_5 = app.increment_build_number(5)
    raise "Build + 5 should be 47" unless next_build_by_5 == "47"
    
    # Test with_build_number (immutability)
    new_app = app.with_build_number(100)
    raise "Original build should be unchanged" unless app.build_number == "42"
    raise "New app build should be 100" unless new_app.build_number == "100"
    
    # Test invalid build numbers
    invalid_app = Application.new(
      bundle_identifier: "com.test.app",
      name: "Test App", 
      display_name: "Test App",
      scheme: "TestScheme",
      team_id: "ABC1234567",
      marketing_version: "1.0.0",
      build_number: "0"
    )
    
    raise "Should reject build number 0" if invalid_app.valid_build_number?
    
    puts "    ✓ Build number management works correctly"
  end
  
  def self.test_app_store_validation
    puts "  → Testing App Store validation..."
    
    # Valid app
    valid_app = Application.new(
      bundle_identifier: "com.company.validapp",
      name: "Valid App",
      display_name: "Valid App Name",
      scheme: "ValidScheme",
      team_id: "ABC1234567",
      marketing_version: "1.0.0",
      build_number: "1"
    )
    
    raise "Valid app should be ready for App Store" unless valid_app.ready_for_app_store?
    raise "Valid app should have no validation errors" unless valid_app.app_store_validation_errors.empty?
    
    # Create a valid app first, then test validation methods
    base_app = Application.new(
      bundle_identifier: "com.valid.app",
      name: "Test App",
      display_name: "Valid Name",
      scheme: "TestScheme", 
      team_id: "ABC1234567",
      marketing_version: "1.0.0",
      build_number: "1"
    )
    
    # Test specific validation methods directly  
    raise "Should detect invalid bundle format (no dots)" if Application.valid_bundle_identifier?("invalid")
    raise "Should detect invalid bundle format (starts with dot)" if Application.valid_bundle_identifier?(".com.app")
    raise "Should detect invalid bundle format (ends with dot)" if Application.valid_bundle_identifier?("com.app.")
    raise "Should accept valid bundle format" unless Application.valid_bundle_identifier?("com.company.app")
    
    # Test display name validation by creating an app with too long name manually
    # (bypassing constructor validation for testing purposes)
    long_name_app = Application.new(
      bundle_identifier: "com.test.app",
      name: "Test",
      display_name: "Valid Name",  # Create with valid name first
      scheme: "TestScheme",
      team_id: "ABC1234567", 
      marketing_version: "1.0.0",
      build_number: "1"
    )
    
    # Test that a very long name would be invalid via class method
    long_name = "A" * 60
    test_app = long_name_app.instance_eval do
      @display_name = long_name  # Override for testing
      self
    end
    raise "Should detect long display name" if test_app.valid_display_name?
    
    # Test preview version detection
    preview_app = Application.new(
      bundle_identifier: "com.test.app",
      name: "Test App",
      display_name: "Test App",
      scheme: "TestScheme",
      team_id: "ABC1234567",
      marketing_version: "1.0.0-beta",
      build_number: "1"
    )
    
    raise "Preview app should not be ready for App Store" if preview_app.ready_for_app_store?
    raise "Preview app should detect preview version" unless preview_app.marketing_version_preview?
    
    puts "    ✓ App Store validation works correctly"
  end
  
  def self.test_platform_support
    puts "  → Testing platform support..."
    
    # iOS app
    ios_app = Application.new(
      bundle_identifier: "com.test.iosapp",
      name: "iOS App",
      display_name: "iOS App",
      scheme: "iOSScheme",
      team_id: "ABC1234567",
      marketing_version: "1.0.0",
      build_number: "1",
      platform: "ios"
    )
    
    raise "Should be iOS app" unless ios_app.ios_app?
    raise "Should not be tvOS app" if ios_app.tvos_app?
    raise "Should support platform" unless ios_app.supported_platform?
    raise "Should have iOS icon" unless ios_app.platform_icon == "📱"
    
    # tvOS app
    tvos_app = Application.new(
      bundle_identifier: "com.test.tvapp",
      name: "TV App",
      display_name: "TV App",
      scheme: "TVScheme",
      team_id: "ABC1234567", 
      marketing_version: "1.0.0",
      build_number: "1",
      platform: "tvos"
    )
    
    raise "Should be tvOS app" unless tvos_app.tvos_app?
    raise "Should not be iOS app" if tvos_app.ios_app?
    raise "Should have TV icon" unless tvos_app.platform_icon == "📺"
    
    puts "    ✓ Platform support works correctly"
  end
  
  def self.test_team_ownership
    puts "  → Testing team ownership..."
    
    app = Application.new(
      bundle_identifier: "com.team.app",
      name: "Team App",
      display_name: "Team App",
      scheme: "TeamScheme",
      team_id: "XYZ9876543",
      marketing_version: "1.0.0", 
      build_number: "1"
    )
    
    raise "Should belong to correct team" unless app.belongs_to_team?("XYZ9876543")
    raise "Should not belong to different team" if app.belongs_to_team?("ABC1234567")
    raise "Should not belong to nil team" if app.belongs_to_team?(nil)
    raise "Should not belong to empty team" if app.belongs_to_team?("")
    
    puts "    ✓ Team ownership works correctly"
  end
  
  def self.test_display_name_validation
    puts "  → Testing display name validation..."
    
    # Valid display name
    valid_app = Application.new(
      bundle_identifier: "com.test.app",
      name: "Test App",
      display_name: "My Great App",
      scheme: "TestScheme",
      team_id: "ABC1234567",
      marketing_version: "1.0.0",
      build_number: "1"
    )
    
    raise "Should validate good display name" unless valid_app.valid_display_name?
    
    # Test safe filename generation
    special_chars_app = Application.new(
      bundle_identifier: "com.test.app",
      name: "Test App",
      display_name: "My-App (Special) & More!",
      scheme: "TestScheme", 
      team_id: "ABC1234567",
      marketing_version: "1.0.0",
      build_number: "1"
    )
    
    safe_name = special_chars_app.safe_filename
    raise "Should generate safe filename" unless safe_name.match?(/\A[A-Za-z0-9_-]+\z/)
    
    puts "    ✓ Display name validation works correctly"
  end
  
  def self.test_metadata_management
    puts "  → Testing metadata management..."
    
    app = Application.new(
      bundle_identifier: "com.test.app",
      name: "Test App",
      display_name: "Test App",
      scheme: "TestScheme",
      team_id: "ABC1234567",
      marketing_version: "1.0.0",
      build_number: "1",
      metadata: { "deployment_env" => "staging", "last_deploy" => "2024-01-01" }
    )
    
    # Test metadata access
    raise "Should get metadata value" unless app.get_metadata("deployment_env") == "staging"
    raise "Should get metadata with symbol key" unless app.get_metadata(:deployment_env) == "staging"
    raise "Should return nil for missing key" unless app.get_metadata("missing").nil?
    
    # Test metadata update (immutability)
    updated_app = app.with_metadata("deployment_env", "production")
    raise "Original metadata should be unchanged" unless app.get_metadata("deployment_env") == "staging"
    raise "New app should have updated metadata" unless updated_app.get_metadata("deployment_env") == "production"
    
    puts "    ✓ Metadata management works correctly"
  end
  
  def self.test_version_comparison
    puts "  → Testing version comparison..."
    
    app_v1 = Application.new(
      bundle_identifier: "com.test.app",
      name: "Test App",
      display_name: "Test App",
      scheme: "TestScheme",
      team_id: "ABC1234567",
      marketing_version: "1.2.3",
      build_number: "1"
    )
    
    # Test version comparison
    raise "Should be equal to same version" unless app_v1.compare_version("1.2.3") == 0
    raise "Should be greater than older version" unless app_v1.compare_version("1.2.2") > 0
    raise "Should be less than newer version" unless app_v1.compare_version("1.2.4") < 0
    raise "Should be greater than much older version" unless app_v1.compare_version("1.1.0") > 0
    
    # Test convenience method
    raise "Should be greater than older version" unless app_v1.version_greater_than?("1.2.2")
    raise "Should not be greater than newer version" if app_v1.version_greater_than?("1.2.4")
    
    # Test class method
    raise "Class method should compare correctly" unless Application.compare_versions("2.0.0", "1.9.9") > 0
    
    puts "    ✓ Version comparison works correctly"
  end
  
  def self.test_immutability_patterns
    puts "  → Testing immutability patterns..."
    
    original_app = Application.new(
      bundle_identifier: "com.test.immutable",
      name: "Immutable App",
      display_name: "Immutable App",
      scheme: "ImmutableScheme",
      team_id: "ABC1234567",
      marketing_version: "1.0.0",
      build_number: "10"
    )
    
    # Test with_marketing_version
    sleep(0.01)  # Small delay to ensure different timestamps
    new_version_app = original_app.with_marketing_version("2.0.0")
    raise "Original version should be unchanged" unless original_app.marketing_version == "1.0.0"
    raise "New app should have new version" unless new_version_app.marketing_version == "2.0.0"
    raise "New app should have updated timestamp" unless new_version_app.updated_at >= original_app.updated_at
    
    # Test with_build_number
    new_build_app = original_app.with_build_number("20")
    raise "Original build should be unchanged" unless original_app.build_number == "10"
    raise "New app should have new build" unless new_build_app.build_number == "20"
    
    # Test with_incremented_version
    incremented_app = original_app.with_incremented_version("minor")
    raise "Original should be unchanged" unless original_app.marketing_version == "1.0.0"
    raise "Incremented should be 1.1.0" unless incremented_app.marketing_version == "1.1.0"
    
    puts "    ✓ Immutability patterns work correctly"
  end
  
  def self.test_equality_and_comparison
    puts "  → Testing equality and comparison..."
    
    app1 = Application.new(
      bundle_identifier: "com.test.same",
      name: "App One",
      display_name: "App One",
      scheme: "SchemeOne", 
      team_id: "ABC1234567",
      marketing_version: "1.0.0",
      build_number: "1"
    )
    
    app2 = Application.new(
      bundle_identifier: "com.test.same",  # Same bundle ID and team
      name: "App Two",
      display_name: "App Two",
      scheme: "SchemeTwo",
      team_id: "ABC1234567", 
      marketing_version: "2.0.0",
      build_number: "10"
    )
    
    app3 = Application.new(
      bundle_identifier: "com.test.different",
      name: "App Three", 
      display_name: "App Three",
      scheme: "SchemeThree",
      team_id: "ABC1234567",
      marketing_version: "1.0.0",
      build_number: "1"
    )
    
    # Test equality (based on bundle_identifier + team_id)
    raise "Apps with same bundle ID and team should be equal" unless app1 == app2
    raise "Apps with different bundle ID should not be equal" if app1 == app3
    raise "App should equal itself" unless app1 == app1
    
    # Test hash consistency
    raise "Equal apps should have same hash" unless app1.hash == app2.hash
    
    # Test comparison (for sorting)
    apps = [app2, app3, app1]  # Mixed order
    sorted_apps = apps.sort
    # "com.test.different" should come before "com.test.same" alphabetically
    raise "Should sort different before same" unless sorted_apps[0].bundle_identifier == "com.test.different"
    raise "Should sort same after different" unless sorted_apps[1].bundle_identifier == "com.test.same"
    
    puts "    ✓ Equality and comparison work correctly"
  end
  
  def self.test_serialization
    puts "  → Testing serialization..."
    
    app = Application.new(
      bundle_identifier: "com.test.serialize",
      name: "Serialize App",
      display_name: "Serialization Test App",
      scheme: "SerializeScheme",
      team_id: "ABC1234567", 
      marketing_version: "1.2.3",
      build_number: "42",
      platform: "tvos",
      metadata: { "test_key" => "test_value", "env" => "staging" }
    )
    
    # Test to_hash
    hash = app.to_hash
    raise "Hash should include bundle_identifier" unless hash[:bundle_identifier] == "com.test.serialize"
    raise "Hash should include display_name" unless hash[:display_name] == "Serialization Test App"
    raise "Hash should include version info" unless hash[:version_info][:major] == 1
    raise "Hash should include validation info" unless hash[:validation][:ready_for_app_store]
    raise "Hash should include metadata" unless hash[:metadata]["test_key"] == "test_value"
    
    # Test to_s
    string_rep = app.to_s
    raise "String should include display name" unless string_rep.include?("Serialization Test App")
    raise "String should include bundle ID" unless string_rep.include?("com.test.serialize")
    raise "String should include version" unless string_rep.include?("v1.2.3")
    raise "String should include build" unless string_rep.include?("(42)")
    raise "String should include platform icon" unless string_rep.include?("📺")
    
    # Test inspect
    inspect_rep = app.inspect
    raise "Inspect should include class name" unless inspect_rep.include?("Application")
    raise "Inspect should include bundle ID" unless inspect_rep.include?("com.test.serialize")
    raise "Inspect should include version and build" unless inspect_rep.include?("version=1.2.3") && inspect_rep.include?("build=42")
    
    puts "    ✓ Serialization works correctly"
  end
  
  def self.test_class_methods
    puts "  → Testing class methods..."
    
    # Test bundle identifier validation
    raise "Should validate good bundle ID" unless Application.valid_bundle_identifier?("com.company.app")
    raise "Should reject empty bundle ID" if Application.valid_bundle_identifier?("")
    raise "Should reject invalid format" if Application.valid_bundle_identifier?("invalid")
    raise "Should reject starting with dot" if Application.valid_bundle_identifier?(".com.app")
    
    # Test version parsing
    version_info = Application.parse_version("2.1.5-beta.1+build.123")
    raise "Should parse major" unless version_info[:major] == 2
    raise "Should parse minor" unless version_info[:minor] == 1
    raise "Should parse patch" unless version_info[:patch] == 5
    raise "Should parse prerelease" unless version_info[:prerelease] == "beta.1"
    raise "Should parse build metadata" unless version_info[:build_metadata] == "build.123"
    
    # Test version validation
    raise "Should validate semantic version" unless Application.valid_version?("1.2.3")
    raise "Should validate prerelease version" unless Application.valid_version?("1.0.0-alpha.1")
    raise "Should reject invalid version" if Application.valid_version?("not.a.version")
    
    # Test version comparison
    raise "Should compare versions correctly" unless Application.compare_versions("2.0.0", "1.9.9") > 0
    raise "Should handle equal versions" unless Application.compare_versions("1.0.0", "1.0.0") == 0
    
    # Test platform suggestion
    raise "Should suggest iOS for normal bundle" unless Application.suggest_platform_from_bundle_id("com.company.app") == "ios"
    raise "Should suggest tvOS for .tv. bundle" unless Application.suggest_platform_from_bundle_id("com.company.tv.app") == "tvos"
    raise "Should suggest tvOS for tvos bundle" unless Application.suggest_platform_from_bundle_id("com.company.tvos.app") == "tvos"
    raise "Should suggest watchOS for .watch. bundle" unless Application.suggest_platform_from_bundle_id("com.company.watch.app") == "watchos"
    raise "Should suggest watchOS for watchos bundle" unless Application.suggest_platform_from_bundle_id("com.company.watchos.app") == "watchos"
    
    # Test from_config
    config = {
      app_identifier: "com.config.app",
      app_name: "Config App",
      scheme: "ConfigScheme",
      team_id: "ABC1234567",
      marketing_version: "1.0.0",
      build_number: "1"
    }
    
    app = Application.from_config(config)
    raise "Should create from config" unless app.bundle_identifier == "com.config.app"
    raise "Should use display name from app name" unless app.display_name == "Config App"
    
    puts "    ✓ Class methods work correctly"
  end
  
  def self.test_validation_errors
    puts "  → Testing validation errors..."
    
    # Test nil bundle identifier
    begin
      Application.new(
        bundle_identifier: nil,
        name: "Test",
        display_name: "Test",
        scheme: "Test",
        team_id: "ABC1234567",
        marketing_version: "1.0.0",
        build_number: "1"
      )
      raise "Should have raised error for nil bundle identifier"
    rescue ArgumentError => e
      raise "Wrong error message" unless e.message.include?("Bundle identifier cannot be nil")
    end
    
    # Test invalid team ID
    begin
      Application.new(
        bundle_identifier: "com.test.app",
        name: "Test",
        display_name: "Test",
        scheme: "Test", 
        team_id: "INVALID",
        marketing_version: "1.0.0",
        build_number: "1"
      )
      raise "Should have raised error for invalid team ID"
    rescue ArgumentError => e
      raise "Wrong error message" unless e.message.include?("10 alphanumeric")
    end
    
    # Test invalid platform
    begin
      Application.new(
        bundle_identifier: "com.test.app", 
        name: "Test",
        display_name: "Test",
        scheme: "Test",
        team_id: "ABC1234567",
        marketing_version: "1.0.0",
        build_number: "1",
        platform: "invalid"
      )
      raise "Should have raised error for invalid platform"
    rescue ArgumentError => e
      raise "Wrong error message" unless e.message.include?("Unsupported platform")
    end
    
    # Test invalid bundle identifier format
    begin
      Application.new(
        bundle_identifier: "invalid-format",
        name: "Test",
        display_name: "Test", 
        scheme: "Test",
        team_id: "ABC1234567",
        marketing_version: "1.0.0",
        build_number: "1"
      )
      raise "Should have raised error for invalid bundle ID format"
    rescue ArgumentError => e
      raise "Wrong error message" unless e.message.include?("Invalid bundle identifier format")
    end
    
    # Test display name too long
    begin
      Application.new(
        bundle_identifier: "com.test.app",
        name: "Test",
        display_name: "A" * 60,  # Longer than MAX_APP_NAME_LENGTH (50)
        scheme: "Test",
        team_id: "ABC1234567", 
        marketing_version: "1.0.0",
        build_number: "1"
      )
      raise "Should have raised error for display name too long"
    rescue ArgumentError => e
      raise "Wrong error message" unless e.message.include?("Display name too long")
    end
    
    puts "    ✓ Validation errors work correctly"
  end
end

# Run tests if this file is executed directly
if __FILE__ == $0
  ApplicationTest.run_all_tests
end