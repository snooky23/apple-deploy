# 🔌 Dependency Injection & Interface Abstractions Plan
**iOS Publishing Automation Platform - Clean Architecture DI Strategy**

---

## 🎯 **Dependency Injection Goals**

### **Primary Objectives**
1. **Inversion of Control**: High-level modules don't depend on low-level modules
2. **Testability**: Easy to inject mock implementations for testing
3. **Flexibility**: Runtime configuration of implementations  
4. **Maintainability**: Centralized dependency configuration
5. **Single Responsibility**: Each class focuses on its core purpose, not dependency management

### **Success Criteria**
- [ ] Zero direct instantiation of dependencies within business logic
- [ ] All external dependencies injected through interfaces
- [ ] 100% of domain layer testable without real external systems
- [ ] Easy to swap implementations (e.g., API vs mock repositories)
- [ ] Clear dependency configuration in one place

---

## 🏗️ **Interface Abstraction Strategy**

### **Repository Interface Definitions**

#### **Certificate Repository Interface**
```ruby
# domain/repositories/certificate_repository.rb
module CertificateRepository
  # Query operations
  def find_by_team(team_id)
    raise NotImplementedError, "Subclass must implement find_by_team"
  end
  
  def find_development_certificates(team_id)
    raise NotImplementedError, "Subclass must implement find_development_certificates"
  end
  
  def find_distribution_certificates(team_id)
    raise NotImplementedError, "Subclass must implement find_distribution_certificates"
  end
  
  def count_by_type(team_id, certificate_type)
    raise NotImplementedError, "Subclass must implement count_by_type"
  end
  
  # Creation operations
  def create_development_certificate(team_id, name = nil)
    raise NotImplementedError, "Subclass must implement create_development_certificate"
  end
  
  def create_distribution_certificate(team_id, name = nil)
    raise NotImplementedError, "Subclass must implement create_distribution_certificate"
  end
  
  # Import operations
  def import_from_p12(file_path, password, keychain_path = nil)
    raise NotImplementedError, "Subclass must implement import_from_p12"
  end
  
  # Management operations
  def delete_certificate(certificate_id)
    raise NotImplementedError, "Subclass must implement delete_certificate"
  end
  
  def export_to_p12(certificate, password, output_path)
    raise NotImplementedError, "Subclass must implement export_to_p12"
  end
  
  # Validation operations
  def validate_certificate(certificate, team_id)
    raise NotImplementedError, "Subclass must implement validate_certificate"
  end
end
```

#### **Provisioning Profile Repository Interface**
```ruby
# domain/repositories/profile_repository.rb
module ProfileRepository
  # Query operations
  def find_by_app_identifier(app_identifier, team_id)
    raise NotImplementedError, "Subclass must implement find_by_app_identifier"
  end
  
  def find_by_type(app_identifier, profile_type, team_id)
    raise NotImplementedError, "Subclass must implement find_by_type"
  end
  
  def find_compatible_profiles(app_identifier, certificates, team_id)
    raise NotImplementedError, "Subclass must implement find_compatible_profiles"
  end
  
  # Creation operations  
  def create_development_profile(app_identifier, certificates, team_id, name = nil)
    raise NotImplementedError, "Subclass must implement create_development_profile"
  end
  
  def create_distribution_profile(app_identifier, certificates, team_id, name = nil)
    raise NotImplementedError, "Subclass must implement create_distribution_profile"
  end
  
  # Management operations
  def install_profile(profile, target_directory = nil)
    raise NotImplementedError, "Subclass must implement install_profile"
  end
  
  def delete_profile(profile_id)
    raise NotImplementedError, "Subclass must implement delete_profile"
  end
  
  # Validation operations
  def validate_profile(profile, app_identifier, certificates)
    raise NotImplementedError, "Subclass must implement validate_profile"
  end
end
```

#### **Build Repository Interface**
```ruby
# domain/repositories/build_repository.rb
module BuildRepository
  # Build operations
  def build_archive(project_path, scheme, configuration, output_path, signing_config)
    raise NotImplementedError, "Subclass must implement build_archive"
  end
  
  def export_ipa(archive_path, export_options, output_path)
    raise NotImplementedError, "Subclass must implement export_ipa"
  end
  
  # Project operations
  def update_build_number(project_path, build_number)
    raise NotImplementedError, "Subclass must implement update_build_number"
  end
  
  def update_version_number(project_path, version_number)
    raise NotImplementedError, "Subclass must implement update_version_number"
  end
  
  def get_current_version_info(project_path)
    raise NotImplementedError, "Subclass must implement get_current_version_info"
  end
  
  # Validation operations
  def validate_project_configuration(project_path, scheme, configuration)
    raise NotImplementedError, "Subclass must implement validate_project_configuration"
  end
  
  def validate_signing_configuration(project_path, signing_config)
    raise NotImplementedError, "Subclass must implement validate_signing_configuration"
  end
end
```

#### **Upload Repository Interface**
```ruby
# domain/repositories/upload_repository.rb
module UploadRepository
  # Upload operations
  def upload_to_testflight(ipa_path, api_credentials, options = {})
    raise NotImplementedError, "Subclass must implement upload_to_testflight"
  end
  
  # Status operations
  def get_upload_status(upload_id)
    raise NotImplementedError, "Subclass must implement get_upload_status"
  end
  
  def get_processing_status(app_identifier, build_number, api_credentials)
    raise NotImplementedError, "Subclass must implement get_processing_status"
  end
  
  def get_testflight_builds(app_identifier, api_credentials, limit = 10)
    raise NotImplementedError, "Subclass must implement get_testflight_builds"
  end
  
  # Validation operations
  def validate_ipa(ipa_path)
    raise NotImplementedError, "Subclass must implement validate_ipa"
  end
  
  def validate_api_credentials(api_credentials)
    raise NotImplementedError, "Subclass must implement validate_api_credentials"
  end
end
```

#### **Configuration Repository Interface**
```ruby
# domain/repositories/configuration_repository.rb
module ConfigurationRepository
  # Read operations
  def get_team_configuration(team_id)
    raise NotImplementedError, "Subclass must implement get_team_configuration"
  end
  
  def get_deployment_history(team_id, limit = 10)
    raise NotImplementedError, "Subclass must implement get_deployment_history"
  end
  
  def get_apple_info_structure(team_id)
    raise NotImplementedError, "Subclass must implement get_apple_info_structure"
  end
  
  # Write operations
  def save_team_configuration(team_id, configuration)
    raise NotImplementedError, "Subclass must implement save_team_configuration"
  end
  
  def record_deployment(team_id, deployment_record)
    raise NotImplementedError, "Subclass must implement record_deployment"
  end
  
  def update_deployment_status(team_id, deployment_id, status)
    raise NotImplementedError, "Subclass must implement update_deployment_status"
  end
end
```

---

## 🏭 **Dependency Injection Container Implementation**

### **Core DI Container**
```ruby
# shared/di_container.rb
class DIContainer
  class DependencyNotRegistered < StandardError; end
  class CircularDependencyError < StandardError; end
  
  def initialize
    @services = {}
    @instances = {}  # For singleton services
    @resolving = Set.new  # Track circular dependencies
  end
  
  # Register a transient service (new instance each time)
  def register(name, &factory)
    validate_service_name(name)
    @services[name] = { type: :transient, factory: factory }
  end
  
  # Register a singleton service (same instance each time)
  def register_singleton(name, &factory)
    validate_service_name(name)
    @services[name] = { type: :singleton, factory: factory }
  end
  
  # Register an instance directly
  def register_instance(name, instance)
    validate_service_name(name)
    @instances[name] = instance
    @services[name] = { type: :instance }
  end
  
  # Resolve a service by name
  def resolve(name)
    # Check for circular dependency
    if @resolving.include?(name)
      raise CircularDependencyError, "Circular dependency detected: #{@resolving.to_a.join(' -> ')} -> #{name}"
    end
    
    service_config = @services[name]
    raise DependencyNotRegistered, "Service '#{name}' is not registered" unless service_config
    
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
    @services.keys
  end
  
  # Clear all registrations (useful for testing)
  def clear
    @services.clear
    @instances.clear
    @resolving.clear
  end
  
  private
  
  def create_service(name, factory)
    @resolving.add(name)
    begin
      factory.call(self)  # Pass container to factory for dependency resolution
    ensure
      @resolving.delete(name)
    end
  end
  
  def validate_service_name(name)
    raise ArgumentError, "Service name cannot be nil" if name.nil?
    raise ArgumentError, "Service name must be a symbol" unless name.is_a?(Symbol)
  end
end
```

### **Service Configuration Module**
```ruby
# shared/service_configuration.rb
module ServiceConfiguration
  class << self
    def configure_container(container, environment = :production)
      # Clear existing registrations for clean slate
      container.clear
      
      # Register core services
      configure_logging_services(container)
      configure_validation_services(container)
      configure_configuration_services(container)
      
      # Register domain services
      configure_domain_services(container)
      
      # Register repository implementations based on environment
      case environment
      when :production
        configure_production_repositories(container)
      when :test
        configure_test_repositories(container)
      when :development
        configure_development_repositories(container)
      end
      
      # Register application services
      configure_application_services(container)
      
      # Register presentation services
      configure_presentation_services(container)
    end
    
    private
    
    def configure_logging_services(container)
      container.register_singleton(:logger) do |c|
        FastlaneLogger
      end
    end
    
    def configure_validation_services(container)
      container.register(:parameter_validator) do |c|
        ParameterValidator.new(c.resolve(:logger))
      end
    end
    
    def configure_configuration_services(container)
      container.register(:configuration_repository) do |c|
        FileConfigurationRepository.new(c.resolve(:logger))
      end
    end
    
    def configure_domain_services(container)
      # Use cases
      container.register(:ensure_valid_certificates_use_case) do |c|
        EnsureValidCertificates.new(
          c.resolve(:certificate_repository),
          c.resolve(:logger)
        )
      end
      
      container.register(:ensure_valid_profiles_use_case) do |c|
        EnsureValidProfiles.new(
          c.resolve(:profile_repository),
          c.resolve(:certificate_repository),
          c.resolve(:logger)
        )
      end
      
      container.register(:manage_app_version_use_case) do |c|
        ManageAppVersion.new(
          c.resolve(:build_repository),
          c.resolve(:upload_repository),
          c.resolve(:logger)
        )
      end
      
      container.register(:upload_to_testflight_use_case) do |c|
        UploadToTestFlight.new(
          c.resolve(:upload_repository),
          c.resolve(:configuration_repository),
          c.resolve(:logger)
        )
      end
      
      container.register(:complete_deployment_workflow) do |c|
        CompleteDeploymentWorkflow.new(
          c.resolve(:ensure_valid_certificates_use_case),
          c.resolve(:ensure_valid_profiles_use_case),
          c.resolve(:manage_app_version_use_case),
          c.resolve(:upload_to_testflight_use_case),
          c.resolve(:logger)
        )
      end
    end
    
    def configure_production_repositories(container)
      # Certificate repositories
      container.register(:keychain_certificate_repository) do |c|
        KeychainCertificateRepository.new(c.resolve(:logger))
      end
      
      container.register(:api_certificate_repository) do |c|
        ApiCertificateRepository.new(
          c.resolve(:apple_api_client),
          c.resolve(:logger)
        )
      end
      
      # Composite certificate repository (tries keychain first, then API)
      container.register(:certificate_repository) do |c|
        CompositeCertificateRepository.new(
          c.resolve(:keychain_certificate_repository),
          c.resolve(:api_certificate_repository),
          c.resolve(:logger)
        )
      end
      
      # Profile repositories
      container.register(:file_profile_repository) do |c|
        FileProfileRepository.new(c.resolve(:logger))
      end
      
      container.register(:api_profile_repository) do |c|
        ApiProfileRepository.new(
          c.resolve(:apple_api_client),
          c.resolve(:logger)
        )
      end
      
      # Composite profile repository
      container.register(:profile_repository) do |c|
        CompositeProfileRepository.new(
          c.resolve(:file_profile_repository),
          c.resolve(:api_profile_repository),
          c.resolve(:logger)
        )
      end
      
      # Build repository
      container.register(:build_repository) do |c|
        XcodeBuildRepository.new(
          c.resolve(:shell_executor),
          c.resolve(:logger)
        )
      end
      
      # Upload repository
      container.register(:upload_repository) do |c|
        FastlaneUploadRepository.new(
          c.resolve(:apple_api_client),
          c.resolve(:logger)
        )
      end
      
      # Apple API client
      container.register(:apple_api_client) do |c|
        SpaceshipApiClient.new(c.resolve(:logger))
      end
      
      # Shell executor
      container.register(:shell_executor) do |c|
        ShellExecutor.new(c.resolve(:logger))
      end
    end
    
    def configure_test_repositories(container)
      # Mock repositories for testing
      container.register(:certificate_repository) do |c|
        MockCertificateRepository.new
      end
      
      container.register(:profile_repository) do |c|
        MockProfileRepository.new
      end
      
      container.register(:build_repository) do |c|
        MockBuildRepository.new
      end
      
      container.register(:upload_repository) do |c|
        MockUploadRepository.new
      end
    end
    
    def configure_development_repositories(container)
      # Development might use a mix of real and mock repositories
      configure_production_repositories(container)
      
      # Override specific repositories for development
      container.register(:upload_repository) do |c|
        DryRunUploadRepository.new(c.resolve(:logger))
      end
    end
    
    def configure_application_services(container)
      container.register(:deployment_service) do |c|
        DeploymentService.new(
          c.resolve(:complete_deployment_workflow),
          c.resolve(:configuration_repository),
          c.resolve(:logger)
        )
      end
      
      container.register(:certificate_management_service) do |c|
        CertificateManagementService.new(
          c.resolve(:ensure_valid_certificates_use_case),
          c.resolve(:configuration_repository),
          c.resolve(:logger)
        )
      end
    end
    
    def configure_presentation_services(container)
      container.register(:deploy_command) do |c|
        DeployCommand.new(
          c.resolve(:deployment_service),
          c.resolve(:parameter_validator),
          c.resolve(:logger)
        )
      end
      
      container.register(:setup_command) do |c|
        SetupCommand.new(
          c.resolve(:certificate_management_service),
          c.resolve(:parameter_validator),
          c.resolve(:logger)
        )
      end
    end
  end
end
```

---

## 🧪 **Mock Implementations for Testing**

### **Mock Certificate Repository**
```ruby
# tests/mocks/mock_certificate_repository.rb
class MockCertificateRepository
  include CertificateRepository
  
  def initialize
    @certificates = {}
    @next_id = 1
  end
  
  def find_by_team(team_id)
    @certificates.values.select { |cert| cert.team_id == team_id }
  end
  
  def find_development_certificates(team_id)
    find_by_team(team_id).select { |cert| cert.type == 'development' }
  end
  
  def find_distribution_certificates(team_id)
    find_by_team(team_id).select { |cert| cert.type == 'distribution' }
  end
  
  def create_development_certificate(team_id, name = nil)
    cert = Certificate.new(
      id: @next_id.to_s,
      name: name || "Mock Development Certificate",
      type: 'development',
      team_id: team_id,
      expiration_date: Date.today + 365
    )
    @certificates[@next_id] = cert
    @next_id += 1
    cert
  end
  
  def create_distribution_certificate(team_id, name = nil)
    cert = Certificate.new(
      id: @next_id.to_s,
      name: name || "Mock Distribution Certificate", 
      type: 'distribution',
      team_id: team_id,
      expiration_date: Date.today + 365
    )
    @certificates[@next_id] = cert
    @next_id += 1
    cert
  end
  
  # Add methods to manipulate state for testing
  def add_certificate(certificate)
    @certificates[certificate.id.to_i] = certificate
  end
  
  def clear_certificates
    @certificates.clear
  end
  
  def certificate_count
    @certificates.size
  end
end
```

---

## 🔧 **Dependency Injection Usage Patterns**

### **1. Use Case with Injected Dependencies**
```ruby
# domain/use_cases/ensure_valid_certificates.rb
class EnsureValidCertificates
  def initialize(certificate_repository, logger)
    @certificate_repository = certificate_repository
    @logger = logger
  end
  
  def execute(team_id, required_types = ['development', 'distribution'])
    @logger.info("Ensuring certificates available", team_id: team_id, types: required_types)
    
    result = CertificateEnsureResult.new(team_id)
    
    required_types.each do |cert_type|
      certificates = find_certificates_by_type(team_id, cert_type)
      valid_certificates = certificates.select(&:valid?)
      
      if valid_certificates.empty?
        @logger.info("Creating new certificate", type: cert_type, team_id: team_id)
        new_cert = create_certificate_by_type(team_id, cert_type)
        result.add_created_certificate(new_cert)
      else
        @logger.info("Using existing certificates", type: cert_type, count: valid_certificates.size)
        result.add_existing_certificates(valid_certificates)
      end
    end
    
    result
  end
  
  private
  
  def find_certificates_by_type(team_id, cert_type)
    case cert_type
    when 'development'
      @certificate_repository.find_development_certificates(team_id)
    when 'distribution'
      @certificate_repository.find_distribution_certificates(team_id)
    else
      raise ArgumentError, "Unknown certificate type: #{cert_type}"
    end
  end
  
  def create_certificate_by_type(team_id, cert_type)
    case cert_type
    when 'development'
      @certificate_repository.create_development_certificate(team_id)
    when 'distribution'  
      @certificate_repository.create_distribution_certificate(team_id)
    else
      raise ArgumentError, "Unknown certificate type: #{cert_type}"
    end
  end
end
```

### **2. Application Service with Injected Use Cases**
```ruby
# application/services/deployment_service.rb
class DeploymentService
  def initialize(deployment_workflow, configuration_repository, logger)
    @deployment_workflow = deployment_workflow
    @configuration_repository = configuration_repository
    @logger = logger
  end
  
  def deploy(deployment_command)
    @logger.header("Deployment Service", "Starting deployment for #{deployment_command.app_identifier}")
    
    begin
      # Record deployment start
      deployment_record = create_deployment_record(deployment_command)
      @configuration_repository.record_deployment(deployment_command.team_id, deployment_record)
      
      # Execute deployment workflow
      result = @deployment_workflow.execute(deployment_command)
      
      # Update deployment record with results
      deployment_record.complete_successfully(result)
      @configuration_repository.update_deployment_status(
        deployment_command.team_id,
        deployment_record.id,
        deployment_record
      )
      
      @logger.success("Deployment completed successfully")
      result
      
    rescue => error
      @logger.error("Deployment failed", error: error.message)
      
      # Update deployment record with failure
      deployment_record&.complete_with_error(error)
      @configuration_repository.update_deployment_status(
        deployment_command.team_id,
        deployment_record.id,
        deployment_record
      ) if deployment_record
      
      raise
    end
  end
  
  private
  
  def create_deployment_record(deployment_command)
    DeploymentRecord.new(
      id: SecureRandom.uuid,
      team_id: deployment_command.team_id,
      app_identifier: deployment_command.app_identifier,
      started_at: Time.now,
      parameters: deployment_command.to_hash
    )
  end
end
```

### **3. CLI Command with Injected Services**
```ruby
# presentation/cli/deploy_command.rb
class DeployCommand
  def initialize(deployment_service, parameter_validator, logger)
    @deployment_service = deployment_service
    @parameter_validator = parameter_validator
    @logger = logger
  end
  
  def execute(args)
    @logger.header("iOS Publishing Automation", "Clean Architecture Deployment Pipeline")
    
    begin
      # Parse and validate parameters
      params = parse_command_line_args(args)
      @parameter_validator.validate_deployment_parameters(params)
      
      # Create deployment command
      deployment_command = DeploymentCommand.new(params)
      
      # Execute deployment
      result = @deployment_service.deploy(deployment_command)
      
      # Format and display results
      formatter = DeploymentResultFormatter.new(result)
      puts formatter.format_success
      
      exit(0)
      
    rescue ValidationError => e
      puts ErrorFormatter.new(e).format_validation_error
      exit(1)
    rescue DeploymentError => e
      puts ErrorFormatter.new(e).format_deployment_error  
      exit(1)
    rescue => e
      puts ErrorFormatter.new(e).format_unexpected_error
      exit(1)
    end
  end
  
  private
  
  def parse_command_line_args(args)
    # Implementation details...
  end
end
```

---

## 🧪 **Testing with Dependency Injection**

### **Unit Test Example**
```ruby
# tests/unit/domain/use_cases/ensure_valid_certificates_spec.rb
require 'spec_helper'

describe EnsureValidCertificates do
  let(:mock_certificate_repository) { MockCertificateRepository.new }
  let(:mock_logger) { MockLogger.new }
  let(:use_case) { EnsureValidCertificates.new(mock_certificate_repository, mock_logger) }
  let(:team_id) { "TEST123456" }
  
  describe "#execute" do
    context "when no valid certificates exist" do
      it "creates new development and distribution certificates" do
        result = use_case.execute(team_id, ['development', 'distribution'])
        
        expect(result.created_certificates.size).to eq(2)
        expect(result.created_certificates.map(&:type)).to contain_exactly('development', 'distribution')
        expect(mock_certificate_repository.certificate_count).to eq(2)
      end
    end
    
    context "when valid certificates already exist" do
      before do
        dev_cert = Certificate.new(
          id: "1",
          name: "Existing Dev Cert",
          type: 'development',
          team_id: team_id,
          expiration_date: Date.today + 100
        )
        mock_certificate_repository.add_certificate(dev_cert)
      end
      
      it "reuses existing valid certificates" do
        result = use_case.execute(team_id, ['development'])
        
        expect(result.existing_certificates.size).to eq(1)
        expect(result.created_certificates.size).to eq(0)
        expect(mock_certificate_repository.certificate_count).to eq(1)
      end
    end
    
    context "when certificates exist but are expired" do
      before do
        expired_cert = Certificate.new(
          id: "1",
          name: "Expired Cert",
          type: 'development', 
          team_id: team_id,
          expiration_date: Date.today - 10
        )
        mock_certificate_repository.add_certificate(expired_cert)
      end
      
      it "creates new certificates to replace expired ones" do
        result = use_case.execute(team_id, ['development'])
        
        expect(result.created_certificates.size).to eq(1)
        expect(result.existing_certificates.size).to eq(0)
      end
    end
  end
end
```

### **Integration Test Example**
```ruby
# tests/integration/workflows/complete_deployment_workflow_spec.rb
require 'spec_helper'

describe CompleteDeploymentWorkflow do
  let(:container) { DIContainer.new }
  let(:workflow) { container.resolve(:complete_deployment_workflow) }
  
  before do
    ServiceConfiguration.configure_container(container, :test)
  end
  
  describe "#execute" do
    let(:deployment_command) do
      DeploymentCommand.new(
        team_id: "TEST123456",
        app_identifier: "com.test.app",
        scheme: "TestApp",
        configuration: "Release"
      )
    end
    
    it "completes full deployment workflow" do
      result = workflow.execute(deployment_command)
      
      expect(result).to be_success
      expect(result.certificates_ensured).to be_truthy
      expect(result.profiles_ensured).to be_truthy
      expect(result.version_managed).to be_truthy
      expect(result.build_completed).to be_truthy
      expect(result.upload_completed).to be_truthy
    end
  end
end
```

---

## 📊 **Dependency Injection Benefits**

### **Testability Benefits**
1. **Unit Testing**: Test business logic in isolation with mock dependencies
2. **Integration Testing**: Test workflows with real repository implementations
3. **Performance Testing**: Inject performance monitoring decorators
4. **Error Testing**: Inject repositories that simulate various error conditions

### **Flexibility Benefits**
1. **Environment-Specific Implementations**: Production vs development vs test repositories
2. **Feature Toggles**: Enable/disable features by injecting different implementations
3. **A/B Testing**: Inject different algorithms for comparison
4. **Gradual Rollout**: Switch implementations at runtime

### **Maintainability Benefits**
1. **Single Responsibility**: Classes focus on their core purpose
2. **Open/Closed Principle**: Add new implementations without changing existing code
3. **Dependency Inversion**: High-level modules don't depend on low-level details
4. **Configuration Centralization**: All dependency wiring in one place

This comprehensive dependency injection strategy provides a solid foundation for clean architecture implementation while maintaining flexibility, testability, and maintainability throughout the iOS Publishing Automation Platform.