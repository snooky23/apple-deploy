#!/usr/bin/env ruby
# Certificate Domain Entity Tests - Clean Architecture Unit Tests

require_relative '../../../../scripts/domain/entities/certificate'
require 'date'

class CertificateTest
  def self.run_all_tests
    puts "🧪 Testing Certificate Domain Entity..."
    
    test_certificate_creation
    test_expiration_logic
    test_team_validation
    test_type_checking
    test_configuration_matching
    test_health_status
    test_equality_and_comparison
    test_business_rules
    test_serialization
    test_class_methods
    test_validation_errors
    
    puts "✅ All Certificate entity tests passed!"
  end
  
  def self.test_certificate_creation
    puts "  → Testing certificate creation..."
    
    # Valid certificate creation
    cert = Certificate.new(
      id: "CERT123456",
      name: "Apple Development: Test User",
      type: "development",
      team_id: "ABC1234567",
      expiration_date: Date.today + 365
    )
    
    raise "Certificate ID should be set" unless cert.id == "CERT123456"
    raise "Certificate name should be set" unless cert.name == "Apple Development: Test User"
    raise "Certificate type should be normalized" unless cert.type == "development"
    raise "Certificate team_id should be set" unless cert.team_id == "ABC1234567"
    raise "Certificate should be valid" unless cert.valid?
    
    puts "    ✓ Certificate creation works"
  end
  
  def self.test_expiration_logic
    puts "  → Testing expiration logic..."
    
    # Valid certificate (not expired)
    valid_cert = Certificate.new(
      id: "VALID123",
      name: "Valid Cert",
      type: "development", 
      team_id: "ABC1234567",
      expiration_date: Date.today + 100
    )
    
    # Expired certificate
    expired_cert = Certificate.new(
      id: "EXPIRED123",
      name: "Expired Cert",
      type: "development",
      team_id: "ABC1234567", 
      expiration_date: Date.today - 10
    )
    
    # Expiring soon certificate
    expiring_cert = Certificate.new(
      id: "EXPIRING123",
      name: "Expiring Cert",
      type: "development",
      team_id: "ABC1234567",
      expiration_date: Date.today + 15
    )
    
    raise "Valid certificate should not be expired" if valid_cert.expired?
    raise "Valid certificate should be valid" unless valid_cert.valid?
    raise "Valid certificate should not be expiring soon (100 days)" if valid_cert.expiring_soon?
    
    raise "Expired certificate should be expired" unless expired_cert.expired?
    raise "Expired certificate should not be valid" if expired_cert.valid?
    raise "Expired certificate should be expiring soon" unless expired_cert.expiring_soon?
    
    raise "Expiring certificate should not be expired" if expiring_cert.expired?
    raise "Expiring certificate should be valid" unless expiring_cert.valid?
    raise "Expiring certificate should be expiring soon (15 days)" unless expiring_cert.expiring_soon?
    
    # Test days until expiration
    raise "Valid cert should have ~100 days" unless (valid_cert.days_until_expiration - 100).abs <= 1
    raise "Expired cert should have negative days" unless expired_cert.days_until_expiration < 0
    raise "Expiring cert should have ~15 days" unless (expiring_cert.days_until_expiration - 15).abs <= 1
    
    puts "    ✓ Expiration logic works correctly"
  end
  
  def self.test_team_validation
    puts "  → Testing team validation..."
    
    cert = Certificate.new(
      id: "TEAM123",
      name: "Team Test Cert",
      type: "development",
      team_id: "XYZ9876543",
      expiration_date: Date.today + 365
    )
    
    raise "Certificate should be valid for its own team" unless cert.valid_for_team?("XYZ9876543")
    raise "Certificate should not be valid for different team" if cert.valid_for_team?("ABC1234567")
    raise "Certificate should not be valid for nil team" if cert.valid_for_team?(nil)
    raise "Certificate should not be valid for empty team" if cert.valid_for_team?("")
    
    puts "    ✓ Team validation works correctly"
  end
  
  def self.test_type_checking
    puts "  → Testing type checking..."
    
    dev_cert = Certificate.new(
      id: "DEV123",
      name: "Development Cert",
      type: "development",
      team_id: "ABC1234567",
      expiration_date: Date.today + 365
    )
    
    dist_cert = Certificate.new(
      id: "DIST123",
      name: "Distribution Cert", 
      type: "distribution",
      team_id: "ABC1234567",
      expiration_date: Date.today + 365
    )
    
    raise "Development cert should be development type" unless dev_cert.development?
    raise "Development cert should not be distribution type" if dev_cert.distribution?
    raise "Distribution cert should be distribution type" unless dist_cert.distribution?
    raise "Distribution cert should not be development type" if dist_cert.development?
    
    puts "    ✓ Type checking works correctly"
  end
  
  def self.test_configuration_matching
    puts "  → Testing configuration matching..."
    
    dev_cert = Certificate.new(
      id: "DEV123",
      name: "Development Cert",
      type: "development",
      team_id: "ABC1234567",
      expiration_date: Date.today + 365
    )
    
    dist_cert = Certificate.new(
      id: "DIST123", 
      name: "Distribution Cert",
      type: "distribution",
      team_id: "ABC1234567",
      expiration_date: Date.today + 365
    )
    
    # Development certificate matching
    raise "Dev cert should match Debug config" unless dev_cert.matches_configuration?("Debug")
    raise "Dev cert should match Development config" unless dev_cert.matches_configuration?("Development")
    raise "Dev cert should not match Release config" if dev_cert.matches_configuration?("Release")
    
    # Distribution certificate matching
    raise "Dist cert should match Release config" unless dist_cert.matches_configuration?("Release")
    raise "Dist cert should match Production config" unless dist_cert.matches_configuration?("Production")
    raise "Dist cert should not match Debug config" if dist_cert.matches_configuration?("Debug")
    
    puts "    ✓ Configuration matching works correctly"
  end
  
  def self.test_health_status
    puts "  → Testing health status..."
    
    healthy_cert = Certificate.new(
      id: "HEALTHY123",
      name: "Healthy Cert",
      type: "development",
      team_id: "ABC1234567",
      expiration_date: Date.today + 100
    )
    
    expiring_cert = Certificate.new(
      id: "EXPIRING123",
      name: "Expiring Cert",
      type: "development", 
      team_id: "ABC1234567",
      expiration_date: Date.today + 15
    )
    
    expired_cert = Certificate.new(
      id: "EXPIRED123",
      name: "Expired Cert",
      type: "development",
      team_id: "ABC1234567",
      expiration_date: Date.today - 10
    )
    
    raise "Healthy cert should have healthy status" unless healthy_cert.health_status == :healthy
    raise "Expiring cert should have expiring_soon status" unless expiring_cert.health_status == :expiring_soon
    raise "Expired cert should have expired status" unless expired_cert.health_status == :expired
    
    # Test status descriptions
    raise "Healthy cert should have positive description" unless healthy_cert.status_description.include?("Valid")
    raise "Expiring cert should mention expiring" unless expiring_cert.status_description.include?("Expiring")
    raise "Expired cert should mention expired" unless expired_cert.status_description.include?("Expired")
    
    puts "    ✓ Health status works correctly"
  end
  
  def self.test_equality_and_comparison
    puts "  → Testing equality and comparison..."
    
    cert1 = Certificate.new(
      id: "SAME123",
      name: "Certificate A",
      type: "development",
      team_id: "ABC1234567",
      expiration_date: Date.today + 100
    )
    
    cert2 = Certificate.new(
      id: "SAME123", 
      name: "Certificate A",
      type: "development",
      team_id: "ABC1234567",
      expiration_date: Date.today + 100
    )
    
    cert3 = Certificate.new(
      id: "DIFFERENT123",
      name: "Certificate B",
      type: "development",
      team_id: "ABC1234567",
      expiration_date: Date.today + 50
    )
    
    raise "Certificates with same ID and team should be equal" unless cert1 == cert2
    raise "Certificates with different ID should not be equal" if cert1 == cert3
    raise "Certificate should equal itself" unless cert1 == cert1
    
    # Test hash consistency
    raise "Equal certificates should have same hash" unless cert1.hash == cert2.hash
    
    puts "    ✓ Equality and comparison work correctly"
  end
  
  def self.test_business_rules
    puts "  → Testing business rules and limits..."
    
    # Test certificate limits
    raise "Should be at dev limit with 2 certs" unless Certificate.at_development_limit?(2)
    raise "Should not be at dev limit with 1 cert" if Certificate.at_development_limit?(1)
    raise "Should be at dist limit with 3 certs" unless Certificate.at_distribution_limit?(3)
    raise "Should not be at dist limit with 2 certs" if Certificate.at_distribution_limit?(2)
    
    # Test limit retrieval
    raise "Dev limit should be 2" unless Certificate.limit_for_type("development") == 2
    raise "Dist limit should be 3" unless Certificate.limit_for_type("distribution") == 3
    
    # Test cleanup strategy
    expired_cert = Certificate.new(
      id: "EXPIRED123",
      name: "Expired",
      type: "development",
      team_id: "ABC1234567",
      expiration_date: Date.today - 10
    )
    
    valid_cert = Certificate.new(
      id: "VALID123",
      name: "Valid",
      type: "development", 
      team_id: "ABC1234567",
      expiration_date: Date.today + 100
    )
    
    certs_with_expired = [expired_cert, valid_cert]
    certs_all_valid = [valid_cert]
    
    strategy1 = Certificate.cleanup_strategy("development", certs_with_expired)
    strategy2 = Certificate.cleanup_strategy("development", certs_all_valid)
    
    raise "Should remove expired when expired certs exist" unless strategy1 == :remove_expired
    raise "Should remove oldest when only valid certs exist" unless strategy2 == :remove_oldest
    
    puts "    ✓ Business rules work correctly"
  end
  
  def self.test_serialization
    puts "  → Testing serialization..."
    
    cert = Certificate.new(
      id: "SERIAL123",
      name: "Serialization Test",
      type: "development",
      team_id: "ABC1234567",
      expiration_date: Date.today + 365,
      serial_number: "12345678",
      thumbprint: "abcdef123456"
    )
    
    # Test to_hash
    hash = cert.to_hash
    raise "Hash should include id" unless hash[:id] == "SERIAL123"
    raise "Hash should include name" unless hash[:name] == "Serialization Test"
    raise "Hash should include type" unless hash[:type] == "development"
    raise "Hash should include validity" unless hash[:valid] == true
    
    # Test to_s
    string_rep = cert.to_s
    raise "String should include name" unless string_rep.include?("Serialization Test")
    raise "String should include type" unless string_rep.include?("development")
    
    # Test inspect
    inspect_rep = cert.inspect
    raise "Inspect should include class name" unless inspect_rep.include?("Certificate")
    raise "Inspect should include id" unless inspect_rep.include?("SERIAL123")
    
    puts "    ✓ Serialization works correctly"
  end
  
  def self.test_class_methods
    puts "  → Testing class methods..."
    
    # Test type validation
    raise "development should be valid type" unless Certificate.valid_type?("development")
    raise "distribution should be valid type" unless Certificate.valid_type?("distribution")
    raise "invalid should not be valid type" if Certificate.valid_type?("invalid")
    
    # Test type normalization
    raise "Development should normalize to development" unless Certificate.normalize_type("Development") == "development"
    raise "DISTRIBUTION should normalize to distribution" unless Certificate.normalize_type("DISTRIBUTION") == "distribution"
    raise "iOS Development should normalize to development" unless Certificate.normalize_type("iOS Development") == "development"
    
    # Test from_portal_data
    portal_data = {
      id: "PORTAL123",
      name: "Portal Certificate", 
      certificate_type: "iOS Development",
      team_id: "ABC1234567",
      expiration_date: (Date.today + 365).to_s
    }
    
    cert = Certificate.from_portal_data(portal_data)
    raise "Portal cert should have correct ID" unless cert.id == "PORTAL123"
    raise "Portal cert should have normalized type" unless cert.type == "development"
    
    puts "    ✓ Class methods work correctly"
  end
  
  def self.test_validation_errors
    puts "  → Testing validation errors..."
    
    # Test nil/empty ID
    begin
      Certificate.new(id: nil, name: "Test", type: "development", team_id: "ABC1234567", expiration_date: Date.today)
      raise "Should have raised error for nil ID"
    rescue ArgumentError => e
      raise "Wrong error message for nil ID" unless e.message.include?("ID cannot be nil")
    end
    
    # Test invalid team ID
    begin
      Certificate.new(id: "TEST123", name: "Test", type: "development", team_id: "INVALID", expiration_date: Date.today)
      raise "Should have raised error for invalid team ID"
    rescue ArgumentError => e
      raise "Wrong error message for invalid team ID" unless e.message.include?("10 alphanumeric")
    end
    
    # Test invalid type
    begin
      Certificate.new(id: "TEST123", name: "Test", type: "invalid", team_id: "ABC1234567", expiration_date: Date.today)
      raise "Should have raised error for invalid type"
    rescue ArgumentError => e
      raise "Wrong error message for invalid type" unless e.message.include?("Invalid certificate type")
    end
    
    # Test nil expiration date
    begin
      Certificate.new(id: "TEST123", name: "Test", type: "development", team_id: "ABC1234567", expiration_date: nil)
      raise "Should have raised error for nil expiration date"
    rescue ArgumentError => e
      raise "Wrong error message for nil expiration" unless e.message.include?("cannot be nil")
    end
    
    puts "    ✓ Validation errors work correctly"
  end
end

# Run tests if this file is executed directly
if __FILE__ == $0
  CertificateTest.run_all_tests
end