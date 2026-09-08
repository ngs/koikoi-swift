fastlane documentation
----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Available Actions

### setup_app_store_connect_api_key

```sh
[bundle exec] fastlane setup_app_store_connect_api_key
```

Setup AppStore Connect API Key

----


## iOS

### ios release_match

```sh
[bundle exec] fastlane ios release_match
```

Match App Store Provisioning Profiles

### ios release_build

```sh
[bundle exec] fastlane ios release_build
```

Build app for release

### ios release_upload

```sh
[bundle exec] fastlane ios release_upload
```

Publish app to App Store

### ios check_editable_version

```sh
[bundle exec] fastlane ios check_editable_version
```

Fail unless an editable App Store version exists (used by CI to skip metadata delivery)

### ios deliver_metadata

```sh
[bundle exec] fastlane ios deliver_metadata
```

Update App Store metadata

### ios deliver_screenshots

```sh
[bundle exec] fastlane ios deliver_screenshots
```

Upload App Store screenshots from fastlane/screenshots/ios

----


## Mac

### mac create_ci_keychain

```sh
[bundle exec] fastlane mac create_ci_keychain
```

Create keychain

### mac release_match

```sh
[bundle exec] fastlane mac release_match
```

Match App Store Provisioning Profiles for macOS

### mac release_build

```sh
[bundle exec] fastlane mac release_build
```

Build app for macOS release

### mac release_upload

```sh
[bundle exec] fastlane mac release_upload
```

Publish macOS app to App Store

### mac check_editable_version

```sh
[bundle exec] fastlane mac check_editable_version
```

Fail unless an editable App Store version exists (used by CI to skip metadata delivery)

### mac deliver_metadata

```sh
[bundle exec] fastlane mac deliver_metadata
```

Update App Store metadata

### mac deliver_screenshots

```sh
[bundle exec] fastlane mac deliver_screenshots
```

Upload App Store screenshots from fastlane/screenshots/mac

----


## visionos

### visionos release_match

```sh
[bundle exec] fastlane visionos release_match
```

Match App Store Provisioning Profiles for visionOS (alias to iOS)

### visionos release_build

```sh
[bundle exec] fastlane visionos release_build
```

Build app for visionOS release

### visionos release_upload

```sh
[bundle exec] fastlane visionos release_upload
```

Publish visionOS app to App Store

### visionos check_editable_version

```sh
[bundle exec] fastlane visionos check_editable_version
```

Fail unless an editable App Store version exists (used by CI to skip metadata delivery)

### visionos deliver_metadata

```sh
[bundle exec] fastlane visionos deliver_metadata
```

Update App Store metadata

### visionos deliver_screenshots

```sh
[bundle exec] fastlane visionos deliver_screenshots
```

Upload App Store screenshots from fastlane/screenshots/visionos

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
