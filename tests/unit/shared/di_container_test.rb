#!/usr/bin/env ruby
# Simple test for DI Container - Verifies basic functionality

require_relative '../../../scripts/shared/container/di_container'
require_relative '../../../scripts/shared/container/service_configuration'

class DIContainerTest
  def self.run_all_tests
    puts "🧪 Testing DI Container..."
    
    test_basic_registration
    test_singleton_behavior
    test_circular_dependency_detection
    test_service_configuration
    
    puts "✅ All DI Container tests passed!"
  end
  
  def self.test_basic_registration
    puts "  → Testing basic service registration..."
    
    container = DIContainer.new
    
    # Test transient registration
    container.register(:test_service) do |c|
      "test_instance_#{rand(10000)}"
    end
    
    # Should get different instances for transient services
    instance1 = container.resolve(:test_service)
    instance2 = container.resolve(:test_service)
    
    raise "Transient services should create new instances" if instance1 == instance2
    puts "    ✓ Transient service registration works"
  end
  
  def self.test_singleton_behavior
    puts "  → Testing singleton behavior..."
    
    container = DIContainer.new
    
    # Test singleton registration
    container.register_singleton(:singleton_service) do |c|
      "singleton_instance_#{rand(10000)}"
    end
    
    # Should get same instance for singleton services
    instance1 = container.resolve(:singleton_service)
    instance2 = container.resolve(:singleton_service)
    
    raise "Singleton services should return same instance" unless instance1 == instance2
    puts "    ✓ Singleton service registration works"
  end
  
  def self.test_circular_dependency_detection
    puts "  → Testing circular dependency detection..."
    
    container = DIContainer.new
    
    container.register(:service_a) do |c|
      c.resolve(:service_b)
    end
    
    container.register(:service_b) do |c|
      c.resolve(:service_a)
    end
    
    begin
      container.resolve(:service_a)
      raise "Should have detected circular dependency"
    rescue DIContainer::CircularDependencyError, RuntimeError => e
      if e.message.include?("Circular dependency detected")
        puts "    ✓ Circular dependency detection works"
      else
        raise e
      end
    end
  end
  
  def self.test_service_configuration
    puts "  → Testing service configuration..."
    
    container = ServiceConfiguration.configure_test_container
    
    # Test that basic services are registered
    logger = container.resolve(:logger)
    raise "Logger should be available" unless logger
    
    # Test that placeholder services work
    cert_repo = container.resolve(:certificate_repository)
    result = cert_repo.find_by_team.call("TEST123")
    raise "Certificate repository should return empty array" unless result.is_a?(Array)
    
    puts "    ✓ Service configuration works"
    puts "    ✓ Registered services: #{container.registered_services.size}"
  end
end

# Run tests if this file is executed directly
if __FILE__ == $0
  DIContainerTest.run_all_tests
end