# CodexMeter Release Notes

This document records the steps required to package CodexMeter for other Mac users.

## 1. Build a Universal Binary

```bash
bash scripts/build-app.sh --universal
lipo -info .build/CodexMeter.app/Contents/MacOS/CodexMeter
```

Expected output includes:

```text
x86_64 arm64
```

## 2. Sign

Automatically select a signing identity:

```bash
bash scripts/build-app.sh --universal --sign-identity auto
```

Behavior:

- If the keychain contains a `Developer ID Application` certificate, the script signs with it and enables the hardened runtime.
- If no `Developer ID Application` certificate exists, the script falls back to ad-hoc signing with `-`.

Check available signing certificates:

```bash
security find-identity -v -p codesigning
```

If this machine only has an `Apple Development` certificate, it can be used for local development signing, but it is not suitable for external distribution. External distribution requires a `Developer ID Application` certificate from an Apple Developer account.

## 3. Generate the DMG

```bash
bash scripts/build-app.sh --universal --sign-identity auto --dmg
```

Output:

```text
dist/CodexMeter-$(cat VERSION).dmg
dist/CodexMeter-$(cat VERSION).dmg.sha256
```

For unnotarized distribution, the DMG contains:

- `CodexMeter.app`
- `Applications` shortcut
- `First Open Guide.txt`
- Custom background image and fixed icon layout

Users need to drag the app to Applications and use right-click `Open` to bypass the first Gatekeeper prompt.

## 4. Notarize

Notarization requires:

- A `Developer ID Application` certificate.
- An Apple Developer account.
- An App Store Connect API key, or a notarytool profile already saved in Keychain.

Save notarization credentials:

```bash
xcrun notarytool store-credentials codex-meter-notary
```

Submit the DMG:

```bash
xcrun notarytool submit "dist/CodexMeter-$(cat VERSION).dmg" \
  --keychain-profile codex-meter-notary \
  --wait
```

After notarization succeeds, staple and validate:

```bash
xcrun stapler staple "dist/CodexMeter-$(cat VERSION).dmg"
xcrun stapler validate "dist/CodexMeter-$(cat VERSION).dmg"
```

## 5. Pre-distribution Verification

```bash
spctl --assess --type execute --verbose .build/CodexMeter.app
spctl --assess --type open --context context:primary-signature --verbose "dist/CodexMeter-$(cat VERSION).dmg"
cat "dist/CodexMeter-$(cat VERSION).dmg.sha256"
```

If the output contains `override=security disabled`, Gatekeeper is disabled or overridden on this Mac. That result does not prove another Mac will allow the app. A formal distribution check should use Developer ID signing, notarization, stapling, and a clean Mac with Gatekeeper enabled.

## 6. User Machine Requirements

- macOS 14 or later.
- Codex is installed and signed in, and `~/.codex/auth.json` exists.
- The network can access `chatgpt.com/backend-api/wham/usage`.
- If the app is moved after first launch, re-enable `Launch at Login` so the LaunchAgent points to the new executable path.

## 7. Release Script

The version is read from `VERSION`. Bump the version before publishing a new release:

```bash
scripts/bump-version.sh patch
```

The release script can also bump the version before publishing:

```bash
bash scripts/release.sh --publish --bump patch
```

Generate artifacts and release notes:

```bash
bash scripts/release.sh
```

Create a GitHub Release:

```bash
bash scripts/release.sh --publish
```

If a Release with the same version already exists, the script exits by default to avoid overwriting published DMG and SHA256 assets. Use this only when intentionally republishing the same version:

```bash
bash scripts/release.sh --publish --force
```
