#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_DIR="$ROOT_DIR/.build/CodexMeter.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
PRODUCT_NAME="CodexMeter"
BUNDLE_ID="local.codex-meter"
VERSION="$(tr -d '[:space:]' < "$ROOT_DIR/VERSION")"
BUILD_MODE="native"
SIGN_IDENTITY=""
CREATE_DMG="false"
DIST_DIR="$ROOT_DIR/dist"
DMG_STAGING_DIR="$ROOT_DIR/.build/dmg-root"
DMG_BACKGROUND_SOURCE="$ROOT_DIR/Assets/Installer/DmgBackground.png"
DMG_WINDOW_BOUNDS="{120, 120, 960, 640}"
DMG_APP_POSITION="{220, 300}"
DMG_APPLICATIONS_POSITION="{560, 300}"
DMG_GUIDE_POSITION="{390, 470}"

usage() {
  cat <<USAGE
Usage: scripts/build-app.sh [options]

Options:
  --native                    Build for the current Mac architecture. Default.
  --universal                 Build a Universal Binary for arm64 and x86_64.
  --sign-identity <identity>  Sign the app with a codesigning identity. Use "-" for ad-hoc.
  --sign-identity auto        Use Developer ID Application when available, otherwise ad-hoc.
  --dmg                       Create dist/CodexMeter-${VERSION}.dmg after building the app.
  -h, --help                  Show this help.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --native)
      BUILD_MODE="native"
      shift
      ;;
    --universal)
      BUILD_MODE="universal"
      shift
      ;;
    --sign-identity)
      SIGN_IDENTITY="${2:-}"
      if [[ -z "$SIGN_IDENTITY" ]]; then
        echo "--sign-identity requires a value" >&2
        exit 2
      fi
      shift 2
      ;;
    --dmg)
      CREATE_DMG="true"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

resolve_sign_identity() {
  if [[ "$SIGN_IDENTITY" != "auto" ]]; then
    return
  fi

  local developer_id
  developer_id="$(security find-identity -v -p codesigning 2>/dev/null | sed -n 's/.*"\(Developer ID Application: .*\)"/\1/p' | head -n 1)"
  if [[ -n "$developer_id" ]]; then
    SIGN_IDENTITY="$developer_id"
  else
    SIGN_IDENTITY="-"
  fi
}

if [[ "$BUILD_MODE" == "universal" ]]; then
  swift build -c release --arch arm64 --arch x86_64 --package-path "$ROOT_DIR"
  BUILT_EXECUTABLE="$ROOT_DIR/.build/apple/Products/Release/$PRODUCT_NAME"
else
  swift build -c release --package-path "$ROOT_DIR"
  BUILT_EXECUTABLE="$ROOT_DIR/.build/release/$PRODUCT_NAME"
fi

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"
cp "$BUILT_EXECUTABLE" "$MACOS_DIR/$PRODUCT_NAME"
cp "$ROOT_DIR/Assets/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"

cat > "$CONTENTS_DIR/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>${PRODUCT_NAME}</string>
  <key>CFBundleIdentifier</key>
  <string>${BUNDLE_ID}</string>
  <key>CFBundleName</key>
  <string>${PRODUCT_NAME}</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>${VERSION}</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
  <key>LSUIElement</key>
  <true/>
</dict>
</plist>
PLIST

resolve_sign_identity

if [[ -n "$SIGN_IDENTITY" ]]; then
  if [[ "$SIGN_IDENTITY" == "-" ]]; then
    codesign --force --deep --options runtime --sign - "$APP_DIR"
  else
    codesign --force --deep --options runtime --timestamp --sign "$SIGN_IDENTITY" "$APP_DIR"
  fi
  codesign --verify --deep --strict --verbose=2 "$APP_DIR"
fi

if [[ "$CREATE_DMG" == "true" ]]; then
  mkdir -p "$DIST_DIR"
  DMG_PATH="$DIST_DIR/${PRODUCT_NAME}-${VERSION}.dmg"
  DMG_SHA_PATH="$DMG_PATH.sha256"
  RW_DMG_PATH="$DIST_DIR/${PRODUCT_NAME}-${VERSION}-rw.dmg"
  rm -f "$DMG_PATH"
  rm -f "$DMG_SHA_PATH"
  rm -f "$RW_DMG_PATH"
  rm -rf "$DMG_STAGING_DIR"
  mkdir -p "$DMG_STAGING_DIR"
  mkdir -p "$DMG_STAGING_DIR/.background"
  cp -R "$APP_DIR" "$DMG_STAGING_DIR/$PRODUCT_NAME.app"
  ln -s /Applications "$DMG_STAGING_DIR/Applications"
  cp "$DMG_BACKGROUND_SOURCE" "$DMG_STAGING_DIR/.background/background.png"
  cat > "$DMG_STAGING_DIR/首次打开说明.txt" <<'NOTE'
CodexMeter未公证版首次打开说明

1. 将CodexMeter.app拖到Applications。
2. 第一次不要直接双击，按住Control点击或右键点击CodexMeter.app，选择“打开”。
3. 如果macOS提示无法验证开发者，继续选择“打开”。
4. 如果仍被阻止，打开“系统设置 > 隐私与安全性”，在安全提示中允许打开。

使用前请确认本机已经登录Codex，并存在~/.codex/auth.json。
NOTE
  hdiutil create \
    -volname "$PRODUCT_NAME" \
    -srcfolder "$DMG_STAGING_DIR" \
    -ov \
    -format UDRW \
    "$RW_DMG_PATH"

  ATTACH_PLIST="$(hdiutil attach -readwrite -noverify -noautoopen -plist "$RW_DMG_PATH")"
  MOUNT_POINT="$(
    printf '%s\n' "$ATTACH_PLIST" \
      | plutil -p - \
      | sed -n 's/.*"mount-point" => "\(.*\)"/\1/p' \
      | head -n 1
  )"

  if [[ -n "$MOUNT_POINT" ]]; then
    osascript <<APPLESCRIPT || true
tell application "Finder"
  tell disk "${PRODUCT_NAME}"
    open
    tell container window
      set current view to icon view
      set toolbar visible to false
      set statusbar visible to false
      set bounds to ${DMG_WINDOW_BOUNDS}
    end tell
    set theViewOptions to the icon view options of container window
    set arrangement of theViewOptions to not arranged
    set icon size of theViewOptions to 112
    set text size of theViewOptions to 14
    set background picture of theViewOptions to file ".background:background.png"
    set position of item "${PRODUCT_NAME}.app" of container window to ${DMG_APP_POSITION}
    set position of item "Applications" of container window to ${DMG_APPLICATIONS_POSITION}
    set position of item "首次打开说明.txt" of container window to ${DMG_GUIDE_POSITION}
    close
    open
    update without registering applications
    delay 2
  end tell
end tell
APPLESCRIPT

    sync
    hdiutil detach "$MOUNT_POINT"
  fi

  hdiutil convert "$RW_DMG_PATH" \
    -ov \
    -format UDZO \
    -o "$DMG_PATH"
  if [[ -n "$SIGN_IDENTITY" && "$SIGN_IDENTITY" != "-" ]]; then
    codesign --force --timestamp --sign "$SIGN_IDENTITY" "$DMG_PATH"
  fi
  SHA_VALUE="$(shasum -a 256 "$DMG_PATH" | awk '{print $1}')"
  printf '%s  %s\n' "$SHA_VALUE" "$(basename "$DMG_PATH")" > "$DMG_SHA_PATH"
  rm -f "$RW_DMG_PATH"
  echo "$DMG_SHA_PATH"
  echo "$DMG_PATH"
fi

echo "$APP_DIR"
