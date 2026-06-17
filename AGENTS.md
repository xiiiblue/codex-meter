# CodexMeter Project Notes

## Project Goal

Build a native macOS menu bar app that directly shows the remaining Codex daily and weekly quota percentages.

## Current Implementation

- Tech stack: SwiftPM + AppKit.
- Entry point: `Sources/CodexMeter/main.swift`, which only keeps the command-line `--once` flow and app startup logic.
- Core modules: `AppDelegate.swift` handles menu bar UI, `CodexUsageClient.swift` handles read-only auth and quota requests, `LoginItemManager.swift` handles LaunchAgent integration, `Preferences.swift` handles user settings, `Models.swift` and `MeterError.swift` handle data types and error text, and `Localizer.swift` handles localization lookup.
- Auth file: reads `~/.codex/auth.json` by default.
- Usage endpoint: `https://chatgpt.com/backend-api/wham/usage`.
- Display logic: `primary_window.used_percent` is treated as daily quota usage, `secondary_window.used_percent` is treated as weekly quota usage, and the menu bar shows `100 - used_percent`.
- Refresh strategy: refresh immediately on startup; the menu provides manual refresh and refresh interval selection; the interval is saved to `UserDefaults` and defaults to 5 minutes.
- Launch at login: the menu's `Launch at Login` item creates or removes the user-level LaunchAgent at `~/Library/LaunchAgents/local.codex-meter.plist`; `ProgramArguments` points to the current app executable.
- Verification command: `swift run CodexMeter --once` fetches and prints remaining quota without the GUI; `bash scripts/build-app.sh` creates `.build/CodexMeter.app`.
- Distribution packaging: `bash scripts/build-app.sh --universal --sign-identity auto --dmg` builds a Universal Binary, automatically selects a signing identity, and generates `dist/CodexMeter-version.dmg` from `VERSION`; without a `Developer ID Application` certificate, it falls back to ad-hoc signing, which does not replace Apple notarization.
- Version management: the version is read from `VERSION`; bump it with `scripts/bump-version.sh patch|minor|major` before publishing a new release.
- Release script: `bash scripts/release.sh` chains Universal build, DMG generation, SHA256 generation, and release note generation; with `--publish`, it creates a GitHub Release; existing Releases with the same version are rejected by default, and intentional republishing requires `--force`.
- Release bumping: `bash scripts/release.sh --publish --bump patch` bumps `VERSION` before publishing; use `--force` only when republishing the same version.
- App icon: source PNG is `Assets/AppIcon.png`; the app bundle uses `Assets/AppIcon.icns`; the packaging script copies it to `Contents/Resources` and writes `CFBundleIconFile`.
- Internationalization: app UI text uses `Sources/CodexMeter/Resources/*.lproj/Localizable.strings`; current app languages are `en`, `zh-Hans`, `ja`, `ko`, `es`, `fr`, and `de`; the packaging script copies `.lproj` directories into the app resources; the menu can follow the system language or force a specific language, and the preference is saved to `UserDefaults`. When adding UI text, update every language resource to avoid raw localization keys appearing in the menu.

## Handoff Notes

- Do not write `access_token`, `refresh_token`, emails, or other sensitive values to logs, README files, commit messages, or error output.
- CodexMeter may only read `~/.codex/auth.json`; it must never write to that file. Do not refresh `access_token` in the app and do not use `refresh_token`; Codex is responsible for refreshing login state.
- If Codex backend fields change, first use `codex app-server generate-ts` to inspect `GetAccountRateLimitsResponse`, `RateLimitSnapshot`, and related usage fields from the current Codex version.
- If packaging as `.app`, keep the app startup entry in `Sources/CodexMeter/main.swift` and use the existing lightweight bundle script around the SwiftPM executable.
- Before distributing to other users, read `RELEASE.md` for the Developer ID signing, notarization, stapling, and `spctl` verification workflow.
- Future optimization plans are tracked in `ROADMAP.md`; P3 is deferred by user decision, and the current candidate priority is adding minimal tests.
