# Team Onboarding Guide - iOS Publishing Automation Platform

## 🚀 **5-Minute Team Member Setup**

Welcome to the iOS Publishing Automation Platform! This guide will get you from zero to deploying in under 5 minutes.

### Prerequisites ✅

Before starting, ensure you have:
- macOS with Xcode installed
- Ruby 2.7+ with fastlane installed (`gem install fastlane`)
- Git access to your team's iOS project repository
- Your Apple Developer account email (you'll be added to the team by team lead)

---

## 🤝 **Team Member Onboarding Process**

### Step 1: Clone Team Repository (30 seconds)

```bash
# Clone your team's iOS project with certificates
git clone https://github.com/your-team/ios-project.git
cd ios-project

# Verify you have the automation platform
ls scripts/deploy.sh  # Should exist
ls certificates/      # Should contain team certificates
```

### Step 2: Import Team Certificates (2 minutes)

```bash
# Automatically import team certificates to your keychain
./scripts/deploy.sh setup_certificates app_identifier="com.yourteamapp"

# This will:
# ✅ Detect existing P12 files (team member mode)
# ✅ Import certificates to your keychain with team passwords
# ✅ Install provisioning profiles
# ✅ Validate everything works on your machine
```

**Expected Output:**
```
🤝 Team collaboration detected: Found 2 P12 files for import
🔐 Importing development_exported.p12...
✅ Successfully imported development_exported.p12 with password: team_shared_password
🔐 Importing distribution_exported.p12...
✅ Successfully imported distribution_exported.p12 with password: team_shared_password
🎉 Team certificate validation PASSED - Ready for team collaboration!
```

### Step 3: Deploy to TestFlight (2 minutes)

```bash
# Deploy your first build to TestFlight
./scripts/deploy.sh build_and_upload \
  app_identifier="com.yourteamapp" \
  apple_id="your@email.com" \
  team_id="YOUR_TEAM_ID" \
  api_key_path="AuthKey_XXXXX.p8" \
  api_key_id="YOUR_KEY_ID" \
  api_issuer_id="your-issuer-id" \
  app_name="Your Team App" \
  scheme="YourScheme"
```

**That's it!** 🎉 You can now deploy to TestFlight just like the team lead.

---

## 📋 **Team Parameters Quick Reference**

Ask your team lead for these values:

| Parameter | Example | Get From |
|-----------|---------|----------|
| `app_identifier` | `com.yourteamapp` | Team lead or existing config.env |
| `team_id` | `YOUR_TEAM_ID` | Apple Developer account |
| `api_key_id` | `YOUR_KEY_ID` | App Store Connect API key |
| `api_issuer_id` | `69a6de8f-xxxx-xxxx` | App Store Connect API |
| `scheme` | `YourApp` | Xcode project schemes |

---

## 🔧 **Troubleshooting Common Issues**

### Issue: "No P12 files found"
**Problem:** You might be in team lead mode instead of team member mode.

**Solution:**
```bash
# Check if P12 files exist
ls certificates/*_exported.p12

# If missing, ask team lead to run and commit:
./scripts/deploy.sh setup_certificates  # (Team lead only)
git add certificates/ profiles/
git commit -m "Add team certificates"
git push
```

### Issue: "Certificate import failed"
**Problem:** P12 password might have changed.

**Solution:**
```bash
# Try manual import with different passwords
security import certificates/development_exported.p12 -k ~/Library/Keychains/login.keychain-db -P "team_shared_password"
security import certificates/distribution_exported.p12 -k ~/Library/Keychains/login.keychain-db -P "team_shared_password"

# Or check TEAM_INFO.txt for current password
cat certificates/TEAM_INFO.txt
```

### Issue: "Build fails with signing errors"
**Problem:** Certificates aren't accessible to Xcode.

**Solution:**
```bash
# Run validation to diagnose and fix issues
./scripts/deploy.sh validate_machine_certificates \
  app_identifier="com.yourteamapp" \
  team_id="YOUR_TEAM_ID"

# This will attempt automatic remediation
```

### Issue: "Provisioning profile errors"
**Problem:** Profiles might be stale or incompatible.

**Solution:**
```bash
# Refresh stale certificates and profiles
./scripts/deploy.sh refresh_stale_certificates \
  app_identifier="com.yourteamapp" \
  team_id="YOUR_TEAM_ID"

# Force refresh if needed
./scripts/deploy.sh refresh_stale_certificates \
  force_refresh=true \
  app_identifier="com.yourteamapp" \
  team_id="YOUR_TEAM_ID"
```

---

## 👥 **Team Workflow Best Practices**

### For Team Members:

1. **Pull Before Deploy:** Always `git pull` before deploying to get latest certificates
2. **Don't Commit Certificates:** Team members should never commit certificate changes
3. **Use Same Parameters:** Use the same app parameters as team lead for consistency
4. **Report Issues:** If setup fails, share the error output with team lead

### For Team Leads:

1. **Initial Setup:** Run `setup_certificates` once and commit the results
2. **Certificate Refresh:** Run `refresh_stale_certificates` monthly or when certificates expire
3. **Team Coordination:** Notify team when certificates are updated (requires re-import)
4. **Parameter Documentation:** Share team parameters in README or team chat

---

## 📚 **Advanced Team Commands**

### Certificate Status Check
```bash
# Check current certificate status
./scripts/deploy.sh status app_identifier="com.yourteamapp"
```

### Force Certificate Refresh
```bash
# Team lead only: Force refresh all certificates
./scripts/deploy.sh refresh_stale_certificates \
  force_refresh=true \
  app_identifier="com.yourteamapp" \
  team_id="YOUR_TEAM_ID"
```

### Pre-build Validation
```bash
# Validate certificates before building
./scripts/deploy.sh validate_machine_certificates \
  app_identifier="com.yourteamapp" \
  team_id="YOUR_TEAM_ID"
```

### Explicit Team Setup
```bash
# Explicit team collaboration setup (alternative to setup_certificates)
./scripts/deploy.sh setup_team_certificates \
  app_identifier="com.yourteamapp" \
  team_id="YOUR_TEAM_ID"
```

---

## 🚨 **Emergency Procedures**

### Complete Certificate Reset (Team Lead Only)

If certificates are completely broken:

```bash
# 1. Backup current state
cp -r certificates/ certificates_backup_$(date +%Y%m%d)
cp -r profiles/ profiles_backup_$(date +%Y%m%d)

# 2. Clean everything
rm -rf certificates/*.{cer,p12}
rm -rf profiles/*.mobileprovision

# 3. Recreate from scratch
./scripts/deploy.sh setup_certificates \
  app_identifier="com.yourteamapp" \
  apple_id="team-lead@company.com" \
  team_id="YOUR_TEAM_ID" \
  api_key_path="AuthKey_XXXXX.p8" \
  api_key_id="YOUR_KEY_ID" \
  api_issuer_id="your-issuer-id" \
  app_name="Your Team App"

# 4. Commit new certificates
git add certificates/ profiles/
git commit -m "emergency: Reset team certificates"
git push

# 5. Notify team to re-import
```

### Individual Developer Reset

If your local certificates are corrupted:

```bash
# 1. Remove all team certificates from keychain
# (This will be done automatically by setup_certificates)

# 2. Re-import team certificates
./scripts/deploy.sh setup_certificates app_identifier="com.yourteamapp"

# 3. Validate setup
./scripts/deploy.sh validate_machine_certificates \
  app_identifier="com.yourteamapp" \
  team_id="YOUR_TEAM_ID"
```

---

## 📞 **Getting Help**

### Team Lead Checklist

When a team member has issues, check:

1. ✅ Are certificates committed in git? (`git status certificates/`)
2. ✅ Is TEAM_INFO.txt up to date? (`cat certificates/TEAM_INFO.txt`)
3. ✅ Are certificates still valid? (`./scripts/deploy.sh refresh_stale_certificates`)
4. ✅ Can team lead deploy successfully? (test build)

### Team Member Checklist

Before asking for help:

1. ✅ Latest code pulled? (`git pull`)
2. ✅ P12 files exist? (`ls certificates/*_exported.p12`)
3. ✅ Error output captured? (copy full terminal output)
4. ✅ Basic validation tried? (`./scripts/deploy.sh validate_machine_certificates`)

### Common Error Patterns

| Error Message | Solution |
|---------------|----------|
| "No P12 files found" | Ask team lead to export and commit certificates |
| "Certificate import failed" | Check password in TEAM_INFO.txt |
| "No profile for team matching" | Run validation and remediation |
| "Build already exists" | Version bumping is automatic - this shouldn't happen |
| "Code signing error" | Run machine validation to fix keychain access |

---

## 🎯 **Success Metrics**

### Team Onboarding Goals:
- ✅ **< 5 minutes**: New team member to first successful deploy
- ✅ **< 2 support requests**: Per new team member onboarded
- ✅ **95% success rate**: Team member setups work on first try
- ✅ **Zero manual Xcode config**: No manual certificate/profile setup needed

### Team Productivity Goals:
- ✅ **Any team member can deploy**: No single point of failure
- ✅ **Consistent deployments**: Same results regardless of who deploys
- ✅ **< 1 hour/month maintenance**: Certificate and setup overhead per team

---

## 🎉 **Welcome to the Team!**

You're now ready to deploy iOS apps to TestFlight with zero manual configuration. The automation platform handles all certificate management, version bumping, and TestFlight uploads automatically.

**Happy deploying!** 🚀

---

*For questions or issues not covered here, check [TEAM_COLLABORATION.md](./TEAM_COLLABORATION.md) for technical details or reach out to your team lead.*