# App Store screenshots

Screenshots uploaded by the `deliver_screenshots` lanes in `fastlane/Fastfile`. Each
platform lane reads its own directory, and every locale gets the same set of shots:

| Lane | Directory | Devices and pixel sizes |
|---|---|---|
| `fastlane ios deliver_screenshots` | `ios/<locale>/` | iPhone 6.9" 1320×2868 (landscape 2868×1320), iPad 13" 2064×2752 (landscape 2752×2064) |
| `fastlane mac deliver_screenshots` | `mac/<locale>/` | Mac 2880×1800 |
| `fastlane visionos deliver_screenshots` | `visionos/<locale>/` | Apple Vision Pro 3840×2160 |

Locales: `en-US` and `ja`. `deliver` infers the device from the pixel size, so the file
name only has to sort the shots: `<index>_<device>_<subject>.png`.

The set is, in order: the setup screen with the Felt theme selected, a mid-game board,
the "Yaku!" decision dialog, the same board in the Night theme, and a fifth shot that is
platform specific (landscape three-column layout on iPhone and iPad, the translucent
window over the desktop with the round-end dialog on Mac, the spatial board seen from
the room on Apple Vision Pro).

## Deterministic game states

Playing a game by hand on every device is not repeatable, so the shots are taken from
recorded games in `fixtures/`. They are ordinary `GameRecord` files — the same format
`GameStore` writes to `current.koikoi` — and the app replays them at launch.

| Fixture | State it replays to |
|---|---|
| `midgame.koikoi` | Round 4, score 8–0, three brights, three "One Away" reaches, 10 captured cards to 8 |
| `yaku-dialog.koikoi` | Round 2, the "Yaku!" prompt for Blue Ribbons (Koi-Koi! / Stop) |
| `round-end.koikoi` | Round 3, the "You win the round!" dialog worth 6 points |

They were produced by replaying seeded games with the heuristic opponent on both sides
and keeping the move prefix that reached a state matching the criteria above. Any legal
move sequence works: `GameRecord` stores the seed plus every move, so a replay is exact.

## Launch arguments (DEBUG builds only)

`KoikoiDebugLaunch` in `Sources/UI/DebugLaunchOptions.swift` reads three keys from the
argument domain. They never touch the user's settings or the saved game, and they are
compiled out of Release builds.

| Argument | Effect |
|---|---|
| `-KoikoiDebugFixture <path>` | Restore that record instead of the saved game, and do not write moves back to the store |
| `-KoikoiDebugTheme <felt\|tatami\|night\|system>` | Override the board palette for this launch only |
| `-KoikoiDebugRounds <n>` | Override the number of rounds a new game starts with |

Two ordinary preference keys are useful too, and unlike `-KoikoiDebugTheme` they also
move the picker on the setup screen, which is why the capture scripts use them:
`-koikoi.theme <name>` and `-koikoi.translucentWindow YES`.

## Reproducing the shots

Build once per platform, then launch with the fixture and read the screen back.

```sh
tuist generate --no-open
xcodebuild -workspace Koikoi.xcworkspace -scheme Koikoi -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' -derivedDataPath dd build
```

**iPhone and iPad.** Install on the simulator, copy the fixtures into the app's data
container (a sandboxed app cannot read them from anywhere else), pin the status bar, and
launch:

```sh
xcrun simctl install "$UDID" dd/Build/Products/Debug-iphonesimulator/Koikoi.app
CONTAINER=$(xcrun simctl get_app_container "$UDID" io.ngs.Koikoi data)
mkdir -p "$CONTAINER/tmp/fixtures" && cp fastlane/screenshots/fixtures/*.koikoi "$CONTAINER/tmp/fixtures/"
xcrun simctl status_bar "$UDID" override --time 9:41 --batteryState charged \
  --batteryLevel 100 --wifiBars 3 --cellularBars 4
xcrun simctl launch "$UDID" io.ngs.Koikoi -AppleLanguages "(ja)" -AppleLocale ja_JP \
  -koikoi.theme felt -KoikoiDebugFixture "$CONTAINER/tmp/fixtures/midgame.koikoi"
xcrun simctl io "$UDID" screenshot 2_iphone69_game.png
```

Delete `$CONTAINER/Library/Application Support/Koikoi/current.koikoi` before the setup
shot, otherwise the app restores the saved game instead of showing the setup screen. Run
`xcrun simctl status_bar "$UDID" clear` when finished.

Landscape needs the Simulator window: `open -a Simulator`, then click Device ▸
Orientation ▸ Landscape Left with AppleScript. The simulator framebuffer stays portrait,
so rotate the capture afterwards with `sips -r 270 <file>` to get 2868×1320.

**Mac.** The Debug app refuses to launch from a temporary directory, so copy the bundle
somewhere normal first (`~/Applications/…`). The fixtures go in the sandbox container at
`~/Library/Containers/io.ngs.Koikoi/Data/tmp/fixtures/`. Launch with `open -na <app>
--args …`, size the window with System Events, capture the window rectangle with
`screencapture -x -R`, and scale to 2880×1800 with `sips -z 1800 2880`. On a display
whose usable height is under 900pt, use a 16:10 window (these shots were taken at
1388×868pt on a 2× display and scaled up).

Back up `~/Library/Containers/io.ngs.Koikoi/Data/Library/Application
Support/Koikoi/current.koikoi` and `defaults read io.ngs.Koikoi` first: the app is the
same bundle identifier as the installed one, so it shares the container and the window
frame preference.

**Apple Vision Pro.** Same simulator flow as iOS. The simulator camera cannot be moved
from a script, so the board sits small inside the simulated room. Shots 1 to 4 are a
2400×1350 crop centred on the board, scaled back to 3840×2160; shot 5 is the untouched
frame that shows the whole room.
