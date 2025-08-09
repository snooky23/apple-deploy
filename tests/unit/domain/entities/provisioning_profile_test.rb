#!/usr/bin/env ruby
# ProvisioningProfile Domain Entity Tests - Clean Architecture Unit Tests

require_relative '../../../../scripts/domain/entities/provisioning_profile'
require 'date'

class ProvisioningProfileTest
  def self.run_all_tests
    puts "🧪 Testing ProvisioningProfile Domain Entity..."
    
    test_profile_creation
    test_expiration_logic
    test_team_validation
    test_type_checking
    test_app_identifier_coverage
    test_certificate_management
    test_configuration_matching
    test_device_support
    test_health_status
    test_equality_and_comparison
    test_business_rules
    test_serialization
    test_class_methods
    test_file_operations
    test_validation_errors
    
    puts "✅ All ProvisioningProfile entity tests passed!"
  end
  
  def self.test_profile_creation
    puts "  → Testing profile creation..."
    
    # Valid profile creation
    profile = ProvisioningProfile.new(
      uuid: "12345678-1234-1234-1234-123456789012",
      name: "Voice Forms Development",
      type: "development",
      app_identifier: "com.voiceforms",
      team_id: "NA5574MSN5",
      expiration_date: Date.today + 365,
      certificate_ids: ["CERT123", "CERT456"]
    )
    
    raise "Profile UUID should be set" unless profile.uuid == "12345678-1234-1234-1234-123456789012"
    raise "Profile name should be set" unless profile.name == "Voice Forms Development"
    raise "Profile type should be normalized" unless profile.type == "development"
    raise "Profile app_identifier should be set" unless profile.app_identifier == "com.voiceforms"
    raise "Profile team_id should be set" unless profile.team_id == "NA5574MSN5"
    raise "Profile should be valid" unless profile.valid?
    raise "Profile should have certificate IDs" unless profile.certificate_ids == ["CERT123", "CERT456"]
    
    puts "    ✓ Profile creation works"
  end
  
  def self.test_expiration_logic
    puts "  → Testing expiration logic..."
    
    # Valid profile (not expired)
    valid_profile = ProvisioningProfile.new(
      uuid: "VALID123",
      name: "Valid Profile",
      type: "development", 
      app_identifier: "com.test.app",
      team_id: "ABC1234567",
      expiration_date: Date.today + 100,
      certificate_ids: ["CERT123"]
    )
    
    # Expired profile
    expired_profile = ProvisioningProfile.new(
      uuid: "EXPIRED123",
      name: "Expired Profile",
      type: "development",
      app_identifier: "com.test.app",
      team_id: "ABC1234567", 
      expiration_date: Date.today - 10,
      certificate_ids: ["CERT123"]
    )
    
    # Expiring soon profile
    expiring_profile = ProvisioningProfile.new(
      uuid: "EXPIRING123",
      name: "Expiring Profile",
      type: "development",
      app_identifier: "com.test.app",
      team_id: "ABC1234567",
      expiration_date: Date.today + 15,
      certificate_ids: ["CERT123"]
    )
    
    raise "Valid profile should not be expired" if valid_profile.expired?
    raise "Valid profile should be valid" unless valid_profile.valid?
    raise "Valid profile should not be expiring soon (100 days)" if valid_profile.expiring_soon?
    
    raise "Expired profile should be expired" unless expired_profile.expired?
    raise "Expired profile should not be valid" if expired_profile.valid?
    raise "Expired profile should be expiring soon" unless expired_profile.expiring_soon?
    
    raise "Expiring profile should not be expired" if expiring_profile.expired?
    raise "Expiring profile should be valid" unless expiring_profile.valid?
    raise "Expiring profile should be expiring soon (15 days)" unless expiring_profile.expiring_soon?
    
    # Test days until expiration
    raise "Valid profile should have ~100 days" unless (valid_profile.days_until_expiration - 100).abs <= 1
    raise "Expired profile should have negative days" unless expired_profile.days_until_expiration < 0
    raise "Expiring profile should have ~15 days" unless (expiring_profile.days_until_expiration - 15).abs <= 1
    
    puts "    ✓ Expiration logic works correctly"
  end
  
  def self.test_team_validation
    puts "  → Testing team validation..."
    
    profile = ProvisioningProfile.new(
      uuid: "TEAM123",
      name: "Team Test Profile",
      type: "development",
      app_identifier: "com.test.app",
      team_id: "XYZ9876543",
      expiration_date: Date.today + 365,
      certificate_ids: ["CERT123"]
    )
    
    raise "Profile should be valid for its own team" unless profile.valid_for_team?("XYZ9876543")
    raise "Profile should not be valid for different team" if profile.valid_for_team?("ABC1234567")
    raise "Profile should not be valid for nil team" if profile.valid_for_team?(nil)
    raise "Profile should not be valid for empty team" if profile.valid_for_team?("")
    
    puts "    ✓ Team validation works correctly"
  end
  
  def self.test_type_checking
    puts "  → Testing type checking..."
    
    dev_profile = ProvisioningProfile.new(
      uuid: "DEV123",
      name: "Development Profile",
      type: "development",
      app_identifier: "com.test.app",
      team_id: "ABC1234567",
      expiration_date: Date.today + 365,
      certificate_ids: ["CERT123"]
    )
    
    appstore_profile = ProvisioningProfile.new(
      uuid: "APPSTORE123",
      name: "App Store Profile", 
      type: "appstore",
      app_identifier: "com.test.app",
      team_id: "ABC1234567",
      expiration_date: Date.today + 365,
      certificate_ids: ["CERT456"]
    )
    
    adhoc_profile = ProvisioningProfile.new(
      uuid: "ADHOC123",
      name: "Ad Hoc Profile",
      type: "adhoc",
      app_identifier: "com.test.app",
      team_id: "ABC1234567",
      expiration_date: Date.today + 365,
      certificate_ids: ["CERT789"]
    )
    
    raise "Development profile should be development type" unless dev_profile.development?
    raise "Development profile should not be distribution type" if dev_profile.distribution?
    raise "App Store profile should be distribution type" unless appstore_profile.distribution?
    raise "App Store profile should be appstore type" unless appstore_profile.appstore?
    raise "App Store profile should not be development type" if appstore_profile.development?
    raise "Ad Hoc profile should be distribution type" unless adhoc_profile.distribution?
    raise "Ad Hoc profile should be adhoc type" unless adhoc_profile.adhoc?
    raise "Ad Hoc profile should not be appstore type" if adhoc_profile.appstore?
    
    puts "    ✓ Type checking works correctly"
  end
  
  def self.test_app_identifier_coverage
    puts "  → Testing app identifier coverage..."
    
    exact_profile = ProvisioningProfile.new(
      uuid: "EXACT123",
      name: "Exact Match Profile",
      type: "development",
      app_identifier: "com.voiceforms",
      team_id: "ABC1234567",
      expiration_date: Date.today + 365,
      certificate_ids: ["CERT123"]
    )
    
    wildcard_profile = ProvisioningProfile.new(
      uuid: "WILD123",
      name: "Wildcard Profile",
      type: "development",
      app_identifier: "com.voiceforms.*",
      team_id: "ABC1234567",
      expiration_date: Date.today + 365,
      certificate_ids: ["CERT123"]
    )
    
    # Test exact matching
    raise "Exact profile should cover exact match" unless exact_profile.covers_app_identifier?("com.voiceforms")
    raise "Exact profile should not cover different app" if exact_profile.covers_app_identifier?("com.other.app")
    
    # Test wildcard matching
    raise "Wildcard profile should cover base app" unless wildcard_profile.covers_app_identifier?("com.voiceforms")
    raise "Wildcard profile should cover child app" unless wildcard_profile.covers_app_identifier?("com.voiceforms.extension")
    raise "Wildcard profile should not cover different base" if wildcard_profile.covers_app_identifier?("com.other.app")
    
    # Test edge cases
    raise "Profile should not cover nil identifier" if exact_profile.covers_app_identifier?(nil)
    raise "Profile should not cover empty identifier" if exact_profile.covers_app_identifier?("")
    
    puts "    ✓ App identifier coverage works correctly"
  end
  
  def self.test_certificate_management
    puts "  → Testing certificate management..."
    
    profile = ProvisioningProfile.new(
      uuid: "CERT123",
      name: "Certificate Test Profile",
      type: "development",
      app_identifier: "com.test.app",
      team_id: "ABC1234567",
      expiration_date: Date.today + 365,
      certificate_ids: ["CERT123", "CERT456", "CERT789"]
    )
    
    # Test individual certificate checking
    raise "Profile should contain CERT123" unless profile.contains_certificate?("CERT123")
    raise "Profile should contain CERT456" unless profile.contains_certificate?("CERT456")
    raise "Profile should not contain CERT999" if profile.contains_certificate?("CERT999")
    raise "Profile should not contain nil certificate" if profile.contains_certificate?(nil)
    
    # Test any certificate checking
    raise "Profile should contain any of [CERT123, CERT999]" unless profile.contains_any_certificate?(["CERT123", "CERT999"])
    raise "Profile should not contain any of [CERT888, CERT999]" if profile.contains_any_certificate?(["CERT888", "CERT999"])
    
    # Test all certificates checking
    raise "Profile should contain all of [CERT123, CERT456]" unless profile.contains_all_certificates?(["CERT123", "CERT456"])
    raise "Profile should not contain all of [CERT123, CERT999]" if profile.contains_all_certificates?(["CERT123", "CERT999"])
    raise "Profile should contain all of empty array" unless profile.contains_all_certificates?([])
    
    puts "    ✓ Certificate management works correctly"
  end
  
  def self.test_configuration_matching
    puts "  → Testing configuration matching..."
    
    dev_profile = ProvisioningProfile.new(
      uuid: "DEV123",
      name: "Development Profile",
      type: "development",
      app_identifier: "com.test.app",
      team_id: "ABC1234567",
      expiration_date: Date.today + 365,
      certificate_ids: ["CERT123"]
    )
    
    appstore_profile = ProvisioningProfile.new(
      uuid: "APPSTORE123",
      name: "App Store Profile", 
      type: "appstore",
      app_identifier: "com.test.app",
      team_id: "ABC1234567",
      expiration_date: Date.today + 365,
      certificate_ids: ["CERT456"]
    )
    
    adhoc_profile = ProvisioningProfile.new(
      uuid: "ADHOC123",
      name: "Ad Hoc Profile",
      type: "adhoc",
      app_identifier: "com.test.app",
      team_id: "ABC1234567",
      expiration_date: Date.today + 365,
      certificate_ids: ["CERT789"]
    )
    
    # Development profile matching
    raise "Dev profile should match Debug config" unless dev_profile.matches_configuration?("Debug")
    raise "Dev profile should match Development config" unless dev_profile.matches_configuration?("Development")
    raise "Dev profile should not match Release config" if dev_profile.matches_configuration?("Release")
    
    # App Store profile matching
    raise "App Store profile should match Release config" unless appstore_profile.matches_configuration?("Release")
    raise "App Store profile should match Production config" unless appstore_profile.matches_configuration?("Production")
    raise "App Store profile should not match Debug config" if appstore_profile.matches_configuration?("Debug")
    
    # Ad Hoc profile matching
    raise "Ad Hoc profile should match AdHoc config" unless adhoc_profile.matches_configuration?("AdHoc")
    raise "Ad Hoc profile should not match Release config" if adhoc_profile.matches_configuration?("Release")
    
    puts "    ✓ Configuration matching works correctly"
  end
  
  def self.test_device_support
    puts "  → Testing device support..."
    
    dev_profile = ProvisioningProfile.new(
      uuid: "DEV123",
      name: "Development Profile",
      type: "development",
      app_identifier: "com.test.app",
      team_id: "ABC1234567",
      expiration_date: Date.today + 365,
      certificate_ids: ["CERT123"],
      device_ids: ["DEVICE123", "DEVICE456"]
    )
    
    appstore_profile = ProvisioningProfile.new(
      uuid: "APPSTORE123",
      name: "App Store Profile",
      type: "appstore",
      app_identifier: "com.test.app",
      team_id: "ABC1234567",
      expiration_date: Date.today + 365,
      certificate_ids: ["CERT456"]
    )
    
    # Development profile device checking
    raise "Dev profile should support registered device" unless dev_profile.supports_device?("DEVICE123")
    raise "Dev profile should not support unregistered device" if dev_profile.supports_device?("DEVICE999")
    raise "Dev profile should not support nil device" if dev_profile.supports_device?(nil)
    
    # App Store profile supports all devices
    raise "App Store profile should support any device" unless appstore_profile.supports_device?("ANY_DEVICE")
    raise "App Store profile should support nil device" unless appstore_profile.supports_device?(nil)
    
    puts "    ✓ Device support works correctly"
  end
  
  def self.test_health_status
    puts "  → Testing health status..."
    
    healthy_profile = ProvisioningProfile.new(
      uuid: "HEALTHY123",
      name: "Healthy Profile",
      type: "development",
      app_identifier: "com.test.app",
      team_id: "ABC1234567",
      expiration_date: Date.today + 100,
      certificate_ids: ["CERT123"]
    )
    
    expiring_profile = ProvisioningProfile.new(
      uuid: "EXPIRING123",
      name: "Expiring Profile",
      type: "development", 
      app_identifier: "com.test.app",
      team_id: "ABC1234567",
      expiration_date: Date.today + 15,
      certificate_ids: ["CERT123"]
    )
    
    expired_profile = ProvisioningProfile.new(
      uuid: "EXPIRED123",
      name: "Expired Profile",
      type: "development",
      app_identifier: "com.test.app",
      team_id: "ABC1234567",
      expiration_date: Date.today - 10,
      certificate_ids: ["CERT123"]
    )
    
    missing_file_profile = ProvisioningProfile.new(
      uuid: "MISSING123",
      name: "Missing File Profile",
      type: "development",
      app_identifier: "com.test.app",
      team_id: "ABC1234567",
      expiration_date: Date.today + 100,
      certificate_ids: ["CERT123"],
      file_path: "/nonexistent/path.mobileprovision"
    )
    
    raise "Healthy profile should have healthy status" unless healthy_profile.health_status == :healthy
    raise "Expiring profile should have expiring_soon status" unless expiring_profile.health_status == :expiring_soon
    raise "Expired profile should have expired status" unless expired_profile.health_status == :expired
    raise "Missing file profile should have missing_file status" unless missing_file_profile.health_status == :missing_file
    
    # Test status descriptions
    raise "Healthy profile should have positive description" unless healthy_profile.status_description.include?("Valid")
    raise "Expiring profile should mention expiring" unless expiring_profile.status_description.include?("Expiring")
    raise "Expired profile should mention expired" unless expired_profile.status_description.include?("Expired")
    raise "Missing file profile should mention missing" unless missing_file_profile.status_description.include?("Missing")
    
    puts "    ✓ Health status works correctly"
  end
  
  def self.test_equality_and_comparison
    puts "  → Testing equality and comparison..."
    
    profile1 = ProvisioningProfile.new(
      uuid: "SAME123",
      name: "Profile A",
      type: "development",
      app_identifier: "com.test.app",
      team_id: "ABC1234567",
      expiration_date: Date.today + 100,
      certificate_ids: ["CERT123"]
    )
    
    profile2 = ProvisioningProfile.new(
      uuid: "SAME123", 
      name: "Profile A",
      type: "development",
      app_identifier: "com.test.app",
      team_id: "ABC1234567",
      expiration_date: Date.today + 100,
      certificate_ids: ["CERT123"]
    )
    
    profile3 = ProvisioningProfile.new(
      uuid: "DIFFERENT123",
      name: "Profile B",
      type: "development",
      app_identifier: "com.test.app",
      team_id: "ABC1234567",
      expiration_date: Date.today + 50,
      certificate_ids: ["CERT456"]
    )
    
    raise "Profiles with same UUID and team should be equal" unless profile1 == profile2
    raise "Profiles with different UUID should not be equal" if profile1 == profile3
    raise "Profile should equal itself" unless profile1 == profile1
    
    # Test hash consistency
    raise "Equal profiles should have same hash" unless profile1.hash == profile2.hash
    
    puts "    ✓ Equality and comparison work correctly"
  end
  
  def self.test_business_rules
    puts "  → Testing business rules and utilities..."
    
    # Test wildcard detection
    raise "Should detect wildcard in com.test.*" unless ProvisioningProfile.wildcard_app_identifier?("com.test.*")
    raise "Should not detect wildcard in com.test.app" if ProvisioningProfile.wildcard_app_identifier?("com.test.app")
    
    # Test base identifier extraction
    base = ProvisioningProfile.base_identifier_from_wildcard("com.voiceforms.*")
    raise "Should extract base from wildcard" unless base == "com.voiceforms"
    
    non_wildcard = ProvisioningProfile.base_identifier_from_wildcard("com.voiceforms.app")
    raise "Should return same for non-wildcard" unless non_wildcard == "com.voiceforms.app"
    
    # Test identifier compatibility
    raise "Should match exact identifiers" unless ProvisioningProfile.identifiers_compatible?("com.test.app", "com.test.app")
    raise "Should match wildcard to child" unless ProvisioningProfile.identifiers_compatible?("com.test.*", "com.test.app")
    raise "Should not match different bases" if ProvisioningProfile.identifiers_compatible?("com.test.*", "com.other.app")
    
    # Test configuration requirements
    dev_type = ProvisioningProfile.required_type_for_configuration("Debug")
    raise "Debug should require development type" unless dev_type == "development"
    
    release_type = ProvisioningProfile.required_type_for_configuration("Release")
    raise "Release should require appstore type" unless release_type == "appstore"
    
    puts "    ✓ Business rules work correctly"
  end
  
  def self.test_serialization
    puts "  → Testing serialization..."
    
    profile = ProvisioningProfile.new(
      uuid: "SERIAL123",
      name: "Serialization Test",
      type: "development",
      app_identifier: "com.test.app",
      team_id: "ABC1234567",
      expiration_date: Date.today + 365,
      certificate_ids: ["CERT123", "CERT456"],
      device_ids: ["DEVICE123"],
      platform: "ios"
    )
    
    # Test to_hash
    hash = profile.to_hash
    raise "Hash should include uuid" unless hash[:uuid] == "SERIAL123"
    raise "Hash should include name" unless hash[:name] == "Serialization Test"
    raise "Hash should include type" unless hash[:type] == "development"
    raise "Hash should include validity" unless hash[:valid] == true
    raise "Hash should include certificate_count" unless hash[:certificate_count] == 2
    raise "Hash should include device_count" unless hash[:device_count] == 1
    
    # Test to_s
    string_rep = profile.to_s
    raise "String should include name" unless string_rep.include?("Serialization Test")
    raise "String should include app identifier" unless string_rep.include?("com.test.app")
    raise "String should include icon" unless string_rep.include?("🔧")
    
    # Test inspect
    inspect_rep = profile.inspect
    raise "Inspect should include class name" unless inspect_rep.include?("ProvisioningProfile")
    raise "Inspect should include uuid" unless inspect_rep.include?("SERIAL123")
    
    # Test expected filename
    filename = profile.expected_filename
    raise "Filename should be safe" unless filename == "Serialization_Test.mobileprovision"
    
    puts "    ✓ Serialization works correctly"
  end
  
  def self.test_class_methods
    puts "  → Testing class methods..."
    
    # Test type validation
    raise "development should be valid type" unless ProvisioningProfile.valid_type?("development")
    raise "appstore should be valid type" unless ProvisioningProfile.valid_type?("appstore")
    raise "invalid should not be valid type" if ProvisioningProfile.valid_type?("invalid")
    
    # Test type normalization
    raise "Development should normalize to development" unless ProvisioningProfile.normalize_type("Development") == "development"
    raise "APPSTORE should normalize to appstore" unless ProvisioningProfile.normalize_type("APPSTORE") == "appstore"
    raise "distribution should normalize to appstore" unless ProvisioningProfile.normalize_type("distribution") == "appstore"
    raise "Ad-Hoc should normalize to adhoc" unless ProvisioningProfile.normalize_type("Ad-Hoc") == "adhoc"
    
    # Test from_portal_data
    portal_data = {
      uuid: "PORTAL123",
      name: "Portal Profile", 
      type: "iOS Development",
      app_identifier: "com.test.app",
      team_id: "ABC1234567",
      expiration_date: (Date.today + 365).to_s,
      certificate_ids: ["CERT123"]
    }
    
    profile = ProvisioningProfile.from_portal_data(portal_data)
    raise "Portal profile should have correct UUID" unless profile.uuid == "PORTAL123"
    raise "Portal profile should have normalized type" unless profile.type == "development"
    
    puts "    ✓ Class methods work correctly"
  end
  
  def self.test_file_operations
    puts "  → Testing file operations..."
    
    # Test filename generation
    profile = ProvisioningProfile.new(
      uuid: "FILE123",
      name: "Test Profile (Special)",
      type: "development",
      app_identifier: "com.test.app",
      team_id: "ABC1234567",
      expiration_date: Date.today + 365,
      certificate_ids: ["CERT123"]
    )
    
    filename = profile.expected_filename
    raise "Should generate safe filename" unless filename == "Test_Profile__Special_.mobileprovision"
    
    # Test file checking (no file)
    raise "Profile without file_path should not have file" if profile.has_file?
    
    # Test file checking (with nonexistent file)
    profile_with_missing_file = ProvisioningProfile.new(
      uuid: "MISSING123",
      name: "Missing File Profile",
      type: "development",
      app_identifier: "com.test.app",
      team_id: "ABC1234567",
      expiration_date: Date.today + 365,
      certificate_ids: ["CERT123"],
      file_path: "/nonexistent/file.mobileprovision"
    )
    
    raise "Profile with nonexistent file should not have file" if profile_with_missing_file.has_file?
    
    puts "    ✓ File operations work correctly"
  end
  
  def self.test_validation_errors
    puts "  → Testing validation errors..."
    
    # Test nil/empty UUID
    begin
      ProvisioningProfile.new(
        uuid: nil,
        name: "Test",
        type: "development",
        app_identifier: "com.test.app",
        team_id: "ABC1234567",
        expiration_date: Date.today,
        certificate_ids: ["CERT123"]
      )
      raise "Should have raised error for nil UUID"
    rescue ArgumentError => e
      raise "Wrong error message for nil UUID" unless e.message.include?("UUID cannot be nil")
    end
    
    # Test invalid team ID
    begin
      ProvisioningProfile.new(
        uuid: "TEST123",
        name: "Test",
        type: "development",
        app_identifier: "com.test.app",
        team_id: "INVALID",
        expiration_date: Date.today,
        certificate_ids: ["CERT123"]
      )
      raise "Should have raised error for invalid team ID"
    rescue ArgumentError => e
      raise "Wrong error message for invalid team ID" unless e.message.include?("10 alphanumeric")
    end
    
    # Test invalid type
    begin
      ProvisioningProfile.new(
        uuid: "TEST123",
        name: "Test",
        type: "invalid",
        app_identifier: "com.test.app",
        team_id: "ABC1234567",
        expiration_date: Date.today,
        certificate_ids: ["CERT123"]
      )
      raise "Should have raised error for invalid type"
    rescue ArgumentError => e
      raise "Wrong error message for invalid type" unless e.message.include?("Invalid profile type")
    end
    
    # Test nil app identifier
    begin
      ProvisioningProfile.new(
        uuid: "TEST123",
        name: "Test",
        type: "development",
        app_identifier: nil,
        team_id: "ABC1234567",
        expiration_date: Date.today,
        certificate_ids: ["CERT123"]
      )
      raise "Should have raised error for nil app identifier"
    rescue ArgumentError => e
      raise "Wrong error message for nil app identifier" unless e.message.include?("App identifier cannot be nil")
    end
    
    # Test nil certificate IDs
    begin
      ProvisioningProfile.new(
        uuid: "TEST123",
        name: "Test",
        type: "development",
        app_identifier: "com.test.app",
        team_id: "ABC1234567",
        expiration_date: Date.today,
        certificate_ids: nil
      )
      raise "Should have raised error for nil certificate IDs"
    rescue ArgumentError => e
      raise "Wrong error message for nil certificate IDs" unless e.message.include?("Certificate IDs cannot be nil")
    end
    
    puts "    ✓ Validation errors work correctly"
  end
end

# Run tests if this file is executed directly
if __FILE__ == $0
  ProvisioningProfileTest.run_all_tests
end