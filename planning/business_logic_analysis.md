# 📊 Business Logic Analysis for Clean Architecture Refactoring
**iOS Publishing Automation Platform - Domain Logic Extraction Plan**

---

## 🔍 **Current State Analysis**

### **✅ Already Modular (Good Foundation)**
The codebase already has some modular structure in `scripts/fastlane/modules/`:

#### **Existing Core Infrastructure**
- **`core/logger.rb`** - ✅ World-class structured logging (317 lines)
- **`core/validator.rb`** - Basic parameter validation 
- **`core/progress.rb`** - Progress tracking utilities
- **`core/error_handler.rb`** - Error handling framework

#### **Existing Certificate Management**  
- **`certificates/manager.rb`** - Certificate orchestration
- **`certificates/detector.rb`** - Certificate detection logic
- **`certificates/importer.rb`** - P12 import operations
- **`certificates/validator.rb`** - Certificate validation

#### **Existing Authentication**
- **`auth/api_manager.rb`** - Apple API authentication
- **`auth/keychain_manager.rb`** - Keychain operations

#### **Existing Utilities**
- **`utils/file_utils.rb`** - File operations
- **`utils/shell_utils.rb`** - Shell command utilities

### **❌ Problems in Current Structure**
1. **Not True Clean Architecture**: Still has infrastructure mixed with domain logic
2. **Missing Domain Layer**: No pure business entities or use cases
3. **Direct Dependencies**: Modules directly depend on external systems (Spaceship, Security framework)
4. **No Repository Abstractions**: Tight coupling to implementation details
5. **Mixed Concerns**: Business logic mixed with infrastructure concerns

---

## 🎯 **Business Logic to Extract from Monolithic Fastfile**

### **📋 From Current 686-line Fastfile**

#### **1. Certificate Management Business Logic**
**Current Location**: `Fastfile` lines 60-180
**Business Rules**:
- Apple Developer Portal has certificate limits (2 dev, 3 dist max)
- Certificates must match team_id
- Development certificates needed for debug builds
- Distribution certificates needed for release/TestFlight
- Certificate cleanup strategy when at limits
- P12 password requirements and generation

**Domain Entities to Extract**:
```ruby
# domain/entities/certificate.rb
class Certificate
  def expired?
  def valid_for_team?(team_id)
  def matches_private_key?(private_key)
  def can_sign_for?(app_identifier)
end

# domain/entities/certificate_limits.rb  
class CertificateLimits
  DEVELOPMENT_LIMIT = 2
  DISTRIBUTION_LIMIT = 3
  
  def at_development_limit?(count)
  def at_distribution_limit?(count)
  def cleanup_strategy_for(certificate_type)
end
```

**Use Cases to Extract**:
```ruby
# domain/use_cases/ensure_valid_certificates.rb
class EnsureValidCertificates
  def execute(team_id, required_types)
    # Pure business logic:
    # 1. Check existing certificates
    # 2. Validate expiration and team match
    # 3. Determine if new certificates needed
    # 4. Apply cleanup strategy if at limits
    # 5. Return certificate requirements
  end
end
```

#### **2. Provisioning Profile Business Logic**
**Current Location**: `Fastfile` lines 220-320
**Business Rules**:
- Profiles must match app_identifier exactly
- Profile certificates must match local certificates
- Development profiles for debug builds
- Distribution profiles for release/TestFlight  
- Smart profile reuse vs creation logic
- Profile installation requirements

**Domain Entities to Extract**:
```ruby
# domain/entities/provisioning_profile.rb
class ProvisioningProfile
  def matches_app_identifier?(app_id)
  def certificates_match?(local_certificates)
  def valid_for_configuration?(configuration)
  def expired?
end

# domain/entities/profile_matching_strategy.rb
class ProfileMatchingStrategy
  def find_compatible_profile(profiles, certificates, app_id)
  def should_reuse_existing?(profile, certificates)
  def should_create_new?(existing_profiles, requirements)
end
```

**Use Cases to Extract**:
```ruby
# domain/use_cases/ensure_valid_profiles.rb  
class EnsureValidProfiles
  def execute(app_identifier, certificates, configuration)
    # Pure business logic:
    # 1. Find existing profiles matching criteria
    # 2. Validate profile-certificate compatibility
    # 3. Determine reuse vs create strategy
    # 4. Return profile requirements
  end
end
```

#### **3. Version Management Business Logic**
**Current Location**: `Fastfile` lines 350-420 + `deploy.sh` lines 600-700
**Business Rules**:
- Semantic versioning (major.minor.patch)
- Build number increments for each TestFlight upload
- TestFlight version conflict detection and resolution
- Marketing version vs build number relationship
- Version synchronization with App Store

**Domain Entities to Extract**:
```ruby
# domain/entities/version_info.rb
class VersionInfo
  def increment_marketing_version(type) # major, minor, patch
  def increment_build_number
  def conflicts_with?(testflight_versions)
  def format_for_display
end

# domain/entities/version_conflict_resolution.rb
class VersionConflictResolution  
  def resolve_marketing_version_conflict(local_version, store_versions)
  def resolve_build_number_conflict(local_build, testflight_builds)
  def suggest_next_version(current_version, increment_type)
end
```

**Use Cases to Extract**:
```ruby
# domain/use_cases/manage_app_version.rb
class ManageAppVersion
  def execute(current_version, increment_type, testflight_versions)
    # Pure business logic:
    # 1. Calculate desired version increment  
    # 2. Check for conflicts with TestFlight
    # 3. Apply conflict resolution strategy
    # 4. Return final version to use
  end
end
```

#### **4. Build Configuration Business Logic**  
**Current Location**: `Fastfile` lines 430-520
**Business Rules**:
- Debug vs Release configuration requirements
- Code signing configuration validation
- Build setting consistency checks
- Archive export options
- IPA validation requirements

**Domain Entities to Extract**:
```ruby
# domain/entities/build_configuration.rb
class BuildConfiguration
  def valid_for_testflight?
  def code_signing_configured?
  def export_options_correct?
  def archive_settings_valid?
end

# domain/entities/signing_configuration.rb  
class SigningConfiguration
  def matches_profile?(profile)
  def matches_certificate?(certificate)
  def valid_for_configuration?(build_config)
end
```

#### **5. TestFlight Upload Business Logic**
**Current Location**: `Fastfile` lines 550-686
**Business Rules**:
- IPA size and format validation
- Upload retry strategy with exponential backoff
- Processing status polling and timeouts
- Success confirmation criteria
- Enhanced vs standard upload modes

**Domain Entities to Extract**:
```ruby
# domain/entities/upload_configuration.rb
class UploadConfiguration  
  def enhanced_mode?
  def retry_strategy
  def timeout_strategy
  def success_criteria
end

# domain/entities/testflight_build_status.rb
class TestFlightBuildStatus
  def processing?
  def ready_to_test?
  def failed?
  def estimated_processing_time
end
```

**Use Cases to Extract**:
```ruby
# domain/use_cases/upload_to_testflight.rb
class UploadToTestFlight
  def execute(ipa_path, upload_config, api_credentials)
    # Pure business logic:
    # 1. Validate IPA meets upload requirements
    # 2. Determine upload strategy (enhanced vs standard)
    # 3. Apply retry logic for failures
    # 4. Poll for processing completion if enhanced
    # 5. Return upload result with status
  end
end
```

---

## 🎯 **Business Logic to Extract from deploy.sh (900+ lines)**

### **📋 Shell Script Business Logic Analysis**

#### **1. Parameter Processing and Validation** 
**Current Location**: `deploy.sh` lines 100-400
**Business Rules**:
- Required vs optional parameter validation
- Parameter precedence (CLI > config.env > defaults)
- Multi-team configuration management  
- Apple info directory structure validation

**Domain Entities to Extract**:
```ruby
# domain/entities/deployment_request.rb
class DeploymentRequest
  def valid?
  def required_parameters_present?
  def apple_info_directory_valid?
  def team_configuration_complete?
end

# domain/entities/parameter_precedence.rb
class ParameterPrecedence
  def resolve_parameter(name, cli_value, config_value, default_value)
  def merge_configurations(cli_params, config_params, defaults)
end
```

#### **2. Apple Info Directory Management**
**Current Location**: `deploy.sh` lines 450-550  
**Business Rules**:
- Multi-team directory structure detection
- Automatic apple_info directory resolution
- Team isolation and configuration management
- Shared vs local apple_info patterns

**Domain Entities to Extract**:
```ruby
# domain/entities/team_configuration.rb
class TeamConfiguration
  def directory_structure_valid?
  def team_isolation_maintained?
  def shared_resource_access_allowed?
end

# domain/entities/apple_info_structure.rb
class AppleInfoStructure  
  def detect_pattern # local vs shared
  def resolve_team_directory(team_id, base_dir)
  def validate_directory_permissions
end
```

#### **3. Environment Setup and Validation**
**Current Location**: `deploy.sh` lines 600-750
**Business Rules**:
- Xcode command line tools availability
- FastLane environment configuration
- Keychain access permissions
- File system permissions and access

**Use Cases to Extract**:
```ruby
# domain/use_cases/validate_deployment_environment.rb
class ValidateDeploymentEnvironment
  def execute(deployment_request)
    # Pure business logic:
    # 1. Check all required tools available
    # 2. Validate file system permissions  
    # 3. Check network connectivity requirements
    # 4. Validate keychain access
    # 5. Return environment status
  end
end
```

---

## 🧩 **Core Business Workflows to Extract**

### **1. Complete Deployment Workflow**
**Current Location**: Orchestrated across Fastfile and deploy.sh
**Business Logic**:
```ruby
# domain/use_cases/complete_deployment_workflow.rb
class CompleteDeploymentWorkflow
  def execute(deployment_request)
    # Pure business orchestration:
    # 1. Validate deployment requirements
    # 2. Ensure certificates available  
    # 3. Ensure profiles available
    # 4. Manage version increments
    # 5. Build and archive application
    # 6. Upload to TestFlight
    # 7. Confirm upload success
    # 8. Log deployment history
  end
end
```

### **2. Team Onboarding Workflow**
**Current Location**: Multiple lanes in Fastfile
**Business Logic**:
```ruby
# domain/use_cases/team_onboarding_workflow.rb  
class TeamOnboardingWorkflow
  def execute(team_configuration)
    # Pure business orchestration:
    # 1. Detect member type (lead vs member)
    # 2. Import shared team certificates
    # 3. Validate team resource access
    # 4. Configure local development environment
    # 5. Verify deployment capability
  end
end
```

### **3. Certificate Lifecycle Management**
**Current Location**: Multiple certificate-related lanes
**Business Logic**:
```ruby
# domain/use_cases/certificate_lifecycle_management.rb
class CertificateLifecycleManagement  
  def execute(team_id, requirements)
    # Pure business orchestration:
    # 1. Audit existing certificates
    # 2. Identify expiring certificates
    # 3. Plan certificate renewal strategy
    # 4. Execute certificate operations
    # 5. Validate new certificate installation
    # 6. Export for team sharing
  end
end
```

---

## 📊 **Business Rules Documentation**

### **Critical Business Rules to Preserve**

#### **Certificate Management Rules**
1. **Apple Limits**: Max 2 development, 3 distribution certificates per team
2. **Team Matching**: Certificates must match exact team_id
3. **Cleanup Strategy**: Remove oldest when at limits
4. **Expiration Handling**: Certificates valid for 1 year, warn at 30 days
5. **Private Key Matching**: Certificate must have matching private key

#### **Provisioning Profile Rules**  
1. **Exact App ID Match**: Profile app identifier must match exactly
2. **Certificate Compatibility**: All profile certificates must be locally available
3. **Configuration Specific**: Development profiles for debug, distribution for release
4. **Reuse Strategy**: Prefer existing valid profiles over creating new ones
5. **Installation Requirements**: Profiles must be installed in ~/Library/MobileDevice/Provisioning Profiles/

#### **Version Management Rules**
1. **Semantic Versioning**: Use major.minor.patch format
2. **Build Number Uniqueness**: Each TestFlight upload needs unique build number  
3. **Conflict Resolution**: Auto-increment when conflicts detected
4. **TestFlight Sync**: Query TestFlight for latest versions before incrementing
5. **Marketing vs Build**: Marketing version can stay same, build number must increment

#### **Upload and Processing Rules**
1. **IPA Validation**: Must be valid iOS application archive
2. **Size Limits**: TestFlight has IPA size limits
3. **Retry Strategy**: Exponential backoff for upload failures
4. **Processing Timeout**: Wait max 10 minutes for Apple processing
5. **Success Confirmation**: Verify "Ready to Test" status for enhanced mode

---

## 🎯 **Extraction Priority Matrix**

### **High Priority (Week 2)**
1. **Certificate Management Logic** - Complex business rules, critical path
2. **Version Management Logic** - Complex conflict resolution algorithms  
3. **Deployment Workflow** - Core business process orchestration

### **Medium Priority (Week 3)**
1. **Provisioning Profile Logic** - Important but well-contained
2. **Upload Configuration Logic** - Less complex business rules
3. **Team Configuration Logic** - Structural but not algorithmic

### **Lower Priority (Week 4)**  
1. **Parameter Processing Logic** - Mostly validation, less business logic
2. **Environment Validation Logic** - Infrastructure-heavy
3. **File System Logic** - Utility functions, not core business

---

## 📋 **Business Logic Extraction Checklist**

### **For Each Business Logic Component:**
- [ ] **Identify pure business rules** (no external dependencies)
- [ ] **Extract domain entities** with business methods only
- [ ] **Create use cases** that orchestrate entities using repositories
- [ ] **Define repository interfaces** for external operations
- [ ] **Write comprehensive unit tests** for extracted business logic
- [ ] **Verify zero external dependencies** in domain layer
- [ ] **Document business rules** and edge cases
- [ ] **Create integration tests** for use case workflows

### **Validation Criteria:**
- [ ] Domain entities have no external dependencies (pure objects)
- [ ] Use cases only depend on repository interfaces, not implementations  
- [ ] All business logic is testable without mocking external systems
- [ ] Complex business rules are documented with examples
- [ ] Edge cases and error conditions are handled in domain layer

This analysis provides a comprehensive roadmap for extracting business logic from the current monolithic structure into a clean, testable domain layer that follows clean architecture principles while preserving all critical business rules and workflows.