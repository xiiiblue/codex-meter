# CodexMeter

CodexMeter is a native macOS menu bar utility that reads the current machine's Codex login state, fetches Codex usage for the ChatGPT account, and shows the remaining daily and weekly quota percentages directly in the menu bar.

## Features

- Shows `Dxx% Wxx%` directly in the menu bar.
- Supports menu bar display modes: standard, compact, lowest quota only, and daily quota only.
- Shows daily quota, weekly quota, reset times, subscription type, and latest refresh time in the menu.
- Supports manual refresh.
- Supports launch at login.
- Supports configurable refresh intervals: `1 minute`, `5 minutes`, `15 minutes`, `30 minutes`, and `60 minutes`.
- Supports choosing System, Simplified Chinese, English, Japanese, Korean, Spanish, French, or German in the menu.
- Supports headless verification mode: `swift run CodexMeter --once`.

## Requirements

- macOS 14 or later.
- Xcode or the Swift toolchain installed.
- Codex has already signed in with ChatGPT on this Mac, and `~/.codex/auth.json` exists by default.

## Run

```bash
swift run CodexMeter
```

The menu bar will show:

```text
D45% W35%
```

The menu includes manual refresh, launch at login, refresh interval, subscription type, refresh time, and quota reset times.

You can also run a headless one-shot verification first:

```bash
swift run CodexMeter --once
```

## Build an App

```bash
bash scripts/build-app.sh
open .build/CodexMeter.app
```

The app icon source file is `Assets/AppIcon.png`, and the packaged app uses `Assets/AppIcon.icns`.
The DMG background image is `Assets/Installer/DmgBackground.png`.

Build a distributable Universal Binary and DMG:

```bash
bash scripts/build-app.sh --universal --sign-identity auto --dmg
```

Output files:

```text
.build/CodexMeter.app
dist/CodexMeter-$(cat VERSION).dmg
dist/CodexMeter-$(cat VERSION).dmg.sha256
```

If this Mac does not have a `Developer ID Application` certificate, `--sign-identity auto` falls back to ad-hoc signing. Ad-hoc signing is not Apple notarization, so Gatekeeper may still block first launch on another Mac. For formal distribution, see [RELEASE.md](./RELEASE.md).

## Install an Unnotarized DMG

If you do not pay for the Apple Developer Program, you can distribute an unnotarized DMG. Users should install it as follows:

1. Open `CodexMeter-version.dmg`.
2. Drag `CodexMeter.app` to `Applications`.
3. On first launch, Control-click or right-click `CodexMeter.app`, then choose `Open`.
4. If macOS says the developer cannot be verified, choose `Open` again. If it is still blocked, allow it in `System Settings > Privacy & Security`.

The DMG also includes `First Open Guide.txt`.

## Options

- Launch at login: checking `Launch at Login` in the menu writes a user-level LaunchAgent at `~/Library/LaunchAgents/local.codex-meter.plist`.
- Refresh interval: the menu offers `1 minute`, `5 minutes`, `15 minutes`, `30 minutes`, and `60 minutes`. The selected value is saved to `UserDefaults` and immediately rebuilds the refresh timer.
- Display mode: the menu can switch between `D24% W32%`, `D24 W32`, `Codex 24%`, and daily quota only.
- Language: the menu offers System, Simplified Chinese, English, Japanese, Korean, Spanish, French, and German. The selected value is saved to `UserDefaults` and takes effect immediately.

## Project Structure

```text
.
├── Assets/
│   ├── AppIcon.icns
│   ├── AppIcon.png
│   └── Installer/DmgBackground.png
├── Sources/CodexMeter/
│   ├── AppDelegate.swift
│   ├── CodexUsageClient.swift
│   ├── LoginItemManager.swift
│   ├── MeterError.swift
│   ├── Models.swift
│   ├── Preferences.swift
│   ├── Localizer.swift
│   ├── Resources/
│   │   ├── de.lproj/Localizable.strings
│   │   ├── en.lproj/Localizable.strings
│   │   ├── es.lproj/Localizable.strings
│   │   ├── fr.lproj/Localizable.strings
│   │   ├── ja.lproj/Localizable.strings
│   │   ├── ko.lproj/Localizable.strings
│   │   └── zh-Hans.lproj/Localizable.strings
│   └── main.swift
├── VERSION
├── scripts/build-app.sh
├── scripts/bump-version.sh
├── scripts/release.sh
├── Package.swift
├── README.md
└── AGENTS.md
```

## Version Management

The project version is stored in `VERSION`. `build-app.sh`, `release.sh`, `Info.plist`, and DMG filenames all read from it.

Bump the version before publishing a new release:

```bash
scripts/bump-version.sh patch
```

The release script can also bump the version before building and publishing:

```bash
scripts/release.sh --publish --bump patch
```

Bump rules:

- `patch`: bug fixes, documentation changes, or packaging script changes, for example `0.1.0 -> 0.1.1`.
- `minor`: user-visible features, for example `0.1.0 -> 0.2.0`.
- `major`: stable releases or breaking changes, for example `0.9.0 -> 1.0.0`.

When publishing to GitHub, `scripts/release.sh --publish` exits if a Release with the same version already exists, so existing assets are not overwritten. To intentionally republish the same version, use:

```bash
scripts/release.sh --publish --force
```

## Data Source

- Reads `~/.codex/auth.json` by default.
- Requires `auth_mode` to be `chatgpt`, meaning Codex has signed in with a ChatGPT account.
- Requests `https://chatgpt.com/backend-api/wham/usage` with the `access_token` and `ChatGPT-Account-ID` headers.
- `primary_window.used_percent` is displayed as daily quota usage, and `secondary_window.used_percent` is displayed as weekly quota usage. Remaining percentage is `100 - used_percent`.

## Security Notes

- The app only reads `~/.codex/auth.json` locally. It never writes to this file and never writes tokens to logs, README files, or menus.
- CodexMeter does not refresh `access_token` and does not use `refresh_token`; Codex is responsible for refreshing the login state.
- When the API returns 401, the menu asks the user to sign in again or refresh the login state in Codex, then click `Refresh Now` manually.
- Launch at login only writes a LaunchAgent for the current user and does not require administrator privileges.

## Development Verification

```bash
swift build
swift run CodexMeter --once
bash scripts/build-app.sh
bash scripts/build-app.sh --universal --sign-identity auto --dmg
bash scripts/release.sh
scripts/bump-version.sh patch --dry-run
plutil -lint .build/CodexMeter.app/Contents/Info.plist
lipo -info .build/CodexMeter.app/Contents/MacOS/CodexMeter
codesign --verify --deep --strict --verbose=2 .build/CodexMeter.app
cat "dist/CodexMeter-$(cat VERSION).dmg.sha256"
```

## Note

The Codex usage endpoint is a ChatGPT backend endpoint currently used by the Codex client, not a public stable API. If backend fields change, first regenerate and inspect the app-server protocol types from the current Codex version.
