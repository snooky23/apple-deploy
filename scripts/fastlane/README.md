fastlane documentation
----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Available Actions

## iOS

### ios build_and_upload

```sh
[bundle exec] fastlane ios build_and_upload
```

Complete certificate creation and TestFlight upload with enhanced confirmation support

### ios upload_existing_ipa

```sh
[bundle exec] fastlane ios upload_existing_ipa
```

Upload existing IPA to TestFlight with enhanced confirmation support

### ios check_testflight_status_standalone

```sh
[bundle exec] fastlane ios check_testflight_status_standalone
```

Check TestFlight build status for the latest uploaded build

**Enhanced TestFlight Features:**
- Real-time Apple processing status monitoring
- Build history display with status indicators  
- Advanced audit logging and metrics tracking
- Upload duration and performance analysis
- Processing confirmation until "Ready to Test"

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
