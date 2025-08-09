# Dependency Injection Container - Clean Architecture Foundation
# Manages service registration and resolution with support for singletons and transients

require 'set'

class DIContainer
  class DependencyNotRegistered < StandardError; end
  class CircularDependencyError < StandardError; end
  class InvalidServiceName < StandardError; end
  
  def initialize
    @services = {}
    @instances = {}  # For singleton services
    @resolving = Set.new  # Track circular dependencies during resolution
  end
  
  # Register a transient service (new instance each time)
  def register(name, &factory)
    validate_service_name(name)
    @services[name] = { type: :transient, factory: factory }
    self
  end
  
  # Register a singleton service (same instance each time)
  def register_singleton(name, &factory)
    validate_service_name(name)
    @services[name] = { type: :singleton, factory: factory }
    self
  end
  
  # Register an instance directly
  def register_instance(name, instance)
    validate_service_name(name)
    raise ArgumentError, "Instance cannot be nil" if instance.nil?
    
    @instances[name] = instance
    @services[name] = { type: :instance }
    self
  end
  
  # Resolve a service by name
  def resolve(name)
    # Check for circular dependency
    if @resolving.include?(name)
      dependency_chain = @resolving.to_a.join(' → ') + " → #{name}"
      raise CircularDependencyError, "Circular dependency detected: #{dependency_chain}"
    end
    
    service_config = @services[name]
    unless service_config
      available_services = @services.keys.join(', ')
      raise DependencyNotRegistered, "Service '#{name}' is not registered. Available: #{available_services}"
    end
    
    case service_config[:type]
    when :instance
      @instances[name]
    when :singleton
      @instances[name] ||= create_service(name, service_config[:factory])
    when :transient
      create_service(name, service_config[:factory])
    end
  end
  
  # Check if a service is registered
  def registered?(name)
    @services.key?(name)
  end
  
  # Get all registered service names
  def registered_services
    @services.keys.sort
  end
  
  # Get service registration info (useful for debugging)
  def service_info(name)
    return nil unless registered?(name)
    
    config = @services[name]
    {
      name: name,
      type: config[:type],
      has_instance: @instances.key?(name),
      instance_class: @instances[name]&.class&.name
    }
  end
  
  # Clear all registrations (useful for testing)
  def clear
    @services.clear
    @instances.clear
    @resolving.clear
    self
  end
  
  # Reset singleton instances (keeps registrations, clears instances)
  def reset_singletons
    @instances.clear
    self
  end
  
  # Get container statistics (useful for monitoring)
  def stats
    {
      total_services: @services.size,
      singleton_services: @services.values.count { |s| s[:type] == :singleton },
      transient_services: @services.values.count { |s| s[:type] == :transient },
      instance_services: @services.values.count { |s| s[:type] == :instance },
      active_singletons: @instances.size,
      currently_resolving: @resolving.size
    }
  end
  
  private
  
  def create_service(name, factory)
    @resolving.add(name)
    begin
      # Pass container to factory for dependency resolution
      result = factory.call(self)
      raise "Factory for '#{name}' returned nil" if result.nil?
      result
    rescue => e
      raise "Failed to create service '#{name}': #{e.message}"
    ensure
      @resolving.delete(name)
    end
  end
  
  def validate_service_name(name)
    raise InvalidServiceName, "Service name cannot be nil" if name.nil?
    raise InvalidServiceName, "Service name must be a symbol" unless name.is_a?(Symbol)
    raise InvalidServiceName, "Service name cannot be empty" if name.to_s.strip.empty?
  end
end