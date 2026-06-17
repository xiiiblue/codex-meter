# CodexMeter Optimization Roadmap

This document records completed capabilities and candidate future work. P3 is currently deferred by user decision and is not an active target.

## Completed

### P0 Experience Fixes

1. Preserve the previous value after refresh failures
   - The status bar keeps showing the latest successful quota snapshot.
   - Error details are shown only in the menu.

2. Signed-out startup guidance
   - When `~/.codex/auth.json` is missing or the auth mode is not ChatGPT, the menu shows `codex login` guidance.

3. Launch-at-login path self-repair
   - The app checks the LaunchAgent path at startup.
   - When the path is stale, the app prompts the user and offers `Repair Launch-at-Login Path`.

### P1 Status and Alerts

1. Improved refresh details
   - The menu shows `Last Successful Refresh` and `Next Refresh`.
   - After refresh failures, the last successful time is preserved, and the failure time and reason are shown.

2. Low-quota warnings
   - The app shows a low warning when daily or weekly quota is below `20%`.
   - The app shows a critical warning when quota is below `10%`.

3. Quota reset countdowns
   - The menu shows concrete reset times and relative countdowns.

### P2 Display and Distribution

1. Menu bar display modes
   - Supports `D24% W32%`, `D24 W32`, `Codex 24%`, and daily quota only.
   - The selection is saved to `UserDefaults`.

2. Release checksums
   - DMG releases generate SHA256 checksums.
   - Release notes include the checksum value.

3. DMG visual polish
   - Added a DMG background image.
   - Fixed the DMG window size.
   - Positioned `CodexMeter.app`, the `Applications` shortcut, and the first-open guide.

4. Release script
   - `scripts/release.sh` chains build, signing, DMG generation, checksum generation, release note generation, and upload.
   - The version is read from `VERSION`.
   - Existing Releases with the same version are not overwritten by default; explicit `--force` is required.

### Code Structure

1. Split `Sources/CodexMeter/main.swift`
   - Completed: the entry point, AppDelegate, API client, login item manager, preferences, models, and error types are split into independent files.

### Internationalization

1. Localized app UI text
   - Completed: menu text, error messages, status bar text, and `--once` output support Chinese and English.
   - Completed: the menu can select System, Simplified Chinese, or English and applies the change immediately.

2. Added major languages
   - Completed: added Japanese, Korean, Spanish, French, and German.
   - The language menu displays language names natively in the app.

## Current Wrap-up Items

1. Roadmap status update
   - Completed: this document has moved P0, P1, and P2 from todo items to completed records.

2. Automatic release version bumping
   - Completed: supports `scripts/release.sh --publish --bump patch`.
   - Existing Releases with the same version are still protected by default.

3. DMG cleanup after packaging failures
   - Completed: `build-app.sh --dmg` automatically detaches temporary mounted volumes and deletes `-rw.dmg` on abnormal exits.

## Deferred

### P3 New Features

1. Check for updates
   - Add `Check for Updates` to the menu.
   - Query the latest GitHub Release.
   - Open the Release page when a new version exists.

2. Multi-account or workspace display
   - Show the current account, plan, or workspace.
   - The goal is to avoid users misreading which quota they are viewing.

## Candidate Improvements

1. Add minimal unit tests
   - Cover display modes, refresh intervals, remaining-percentage boundaries, and reset-countdown text.

2. Auth file write protection
   - Canceled: the user explicitly required CodexMeter to never write to `~/.codex/auth.json`.
   - Ongoing constraint: Codex owns login-state refresh; CodexMeter only reads the auth file.
