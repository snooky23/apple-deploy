default_platform(:ios)

platform :ios do
  desc "Simple certificate creation and TestFlight upload"
  lane :build_and_upload do |options|
    # Get parameters from environment variables (set by deploy.sh)
    app_identifier = ENV['FL_APP_IDENTIFIER']
    team_id = ENV['FL_TEAM_ID']
    apple_id = ENV['FL_APPLE_ID']
    api_key_path = ENV['FL_API_KEY_PATH']
    api_key_id = ENV['FL_API_KEY_ID']
    api_issuer_id = ENV['FL_API_ISSUER_ID']
    scheme = ENV['FL_SCHEME'] || "template_swiftui"
    
    UI.header("🏭 iOS Certificate Creation and TestFlight Upload")
    UI.message("📋 Parameters:")
    UI.message("   - App ID: #{app_identifier}")
    UI.message("   - Team ID: #{team_id}")
    UI.message("   - Scheme: #{scheme}")
    UI.message("   - API Key: #{File.basename(api_key_path)}")
    
    # Set up App Store Connect API authentication
    app_store_connect_api_key(
      key_id: api_key_id,
      issuer_id: api_issuer_id,
      key_filepath: api_key_path
    )
    
    begin
      # Step 1: Create certificates
      UI.message("🔐 Step 1: Creating Development Certificate...")
      cert(
        development: true,
        team_id: team_id,
        username: apple_id
      )
      UI.success("✅ Development certificate ready")
    rescue => dev_error
      UI.message("⚠️  Development certificate creation failed: #{dev_error.message}")
      UI.message("💡 Continuing without development certificate...")
    end
    
    begin
      UI.message("🏢 Step 2: Creating Distribution Certificate...")
      cert(
        development: false,
        team_id: team_id,
        username: apple_id
      )
      UI.success("✅ Distribution certificate ready")
    rescue => dist_error
      UI.error("❌ Distribution certificate creation failed: #{dist_error.message}")
      UI.message("💡 This is required for App Store builds")
      raise "Distribution certificate required for TestFlight upload"
    end
    
    begin
      # Step 2: Create provisioning profiles
      UI.message("📱 Step 3: Creating Development Provisioning Profile...")
      sigh(
        app_identifier: app_identifier,
        development: true,
        team_id: team_id,
        username: apple_id
      )
      UI.success("✅ Development provisioning profile ready")
    rescue => dev_profile_error
      UI.message("⚠️  Development profile creation failed: #{dev_profile_error.message}")
      UI.message("💡 Continuing without development profile...")
    end
    
    begin
      UI.message("🚀 Step 4: Creating Distribution Provisioning Profile...")
      sigh(
        app_identifier: app_identifier,
        development: false,
        team_id: team_id,
        username: apple_id
      )
      UI.success("✅ Distribution provisioning profile ready")
    rescue => dist_profile_error
      UI.error("❌ Distribution profile creation failed: #{dist_profile_error.message}")
      raise "Distribution provisioning profile required for TestFlight upload"
    end
    
    # Step 3: Build the app
    UI.message("🔨 Step 5: Building iOS App...")
    
    # Find the Xcode project or workspace
    if Dir.glob("*.xcworkspace").any?
      workspace_path = Dir.glob("*.xcworkspace").first
      UI.message("📱 Using workspace: #{workspace_path}")
      
      build_app(
        workspace: workspace_path,
        scheme: scheme,
        configuration: "Release",
        export_method: "app-store"
      )
    elsif Dir.glob("*.xcodeproj").any?
      project_path = Dir.glob("*.xcodeproj").first
      UI.message("📱 Using project: #{project_path}")
      
      build_app(
        project: project_path,
        scheme: scheme,
        configuration: "Release",
        export_method: "app-store"
      )
    else
      UI.user_error!("❌ No Xcode project or workspace found")
    end
    
    UI.success("✅ App built successfully!")
    
    # Step 4: Upload to TestFlight
    UI.message("☁️  Step 6: Uploading to TestFlight...")
    upload_to_testflight(
      api_key_path: api_key_path,
      skip_waiting_for_build_processing: true,
      distribute_external: false
    )
    
    UI.success("🎉 Successfully uploaded to TestFlight!")
  end
end