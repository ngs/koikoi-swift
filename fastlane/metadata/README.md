# App Store metadata

Each platform's `deliver_metadata` lane reads its own folder:

| Folder | Lane | deliver platform |
|---|---|---|
| `ios/` | `fastlane ios deliver_metadata` | `ios` |
| `mac/` | `fastlane mac deliver_metadata` | `osx` |
| `visionos/` | `fastlane visionos deliver_metadata` | `xros` |

## What can differ per platform

App Store Connect keeps some fields per platform version and shares others across the whole app.

- Per platform version (can differ): `<locale>/description.txt`, `keywords.txt`, `promotional_text.txt`, `release_notes.txt`, `support_url.txt`, `marketing_url.txt`, `copyright.txt`, and `review_information/`.
- App-level (shared by every platform): `<locale>/name.txt`, `subtitle.txt`, `privacy_url.txt`, the `primary_*category.txt` files, and the age rating (`app_store_rating_config.json`).

App-level files live only in `ios/`. Putting them in `mac/` or `visionos/` would make each platform's upload overwrite the others, so a change to the name or subtitle there would also change the iOS listing.
