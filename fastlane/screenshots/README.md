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

App Store Connect rejects screenshots that carry an alpha channel, and both simulator and
window captures produce RGBA files. Convert every finished PNG to RGB before committing
it.

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
--args …` and size the window to 1440×900pt, which is exactly 2880×1800px on a 2×
display, so nothing has to be scaled.

Four details make the difference between a usable shot and a broken one:

- Capture the window, not a screen rectangle: `screencapture -x -o -w <file>` followed by
  a click in the middle of the window (`cliclick c:<x>,<y>`). A region capture picks up
  whatever floats above the window, and a notification banner in the corner will end up
  in the screenshot. Window captures come back with transparent rounded corners, so
  flatten them onto black before uploading.
- Quit any previous copy first. Two instances mean two windows, and the resize then
  lands on the wrong one. Kill by path (`pgrep -f ~/Applications/…`), never `pkill -x
  Koikoi`, which would also kill an app of the same name running in a simulator.
- Address the app by process id (`first process whose unix id is …`) and the window by
  `first window whose subrole is "AXStandardWindow"`. A simulator can host a process with
  the same name, and the app can briefly keep a leftover ghost window.
- The usable screen height is not always 900pt. Read the window size back after resizing
  and, if it came out smaller, crop the capture to 16:10 and scale it up rather than
  stretching it.

Back up `~/Library/Containers/io.ngs.Koikoi/Data/Library/Application
Support/Koikoi/current.koikoi` and `defaults read io.ngs.Koikoi` first: the app is the
same bundle identifier as the installed one, so it shares the container and the window
frame preference.

**Apple Vision Pro.** Same simulator flow as iOS. The simulator camera cannot be moved
from a script, so the board sits small inside the simulated room. Shots 1 to 4 are a
2000×1125 crop centred on the board, scaled back to 3840×2160; the setup shot takes its
crop 177px higher because the glass panel floats above the table. Shot 5 is the untouched
frame that shows the whole room.

The Night shot passes `-koikoi.translucentWindow NO`. visionOS shows the felt translucent
by default, which leaves the palettes nearly indistinguishable; with translucency off the
table reads as a solid indigo surface in the room.
