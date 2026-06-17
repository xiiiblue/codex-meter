#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PRODUCT_NAME="CodexMeter"
PUBLISH="false"
FORCE="false"
BUMP_PART=""
REPO="xiiiblue/codex-meter"

load_version() {
  VERSION="$(tr -d '[:space:]' < "$ROOT_DIR/VERSION")"
  DIST_DIR="$ROOT_DIR/dist"
  DMG_PATH="$DIST_DIR/${PRODUCT_NAME}-${VERSION}.dmg"
  SHA_PATH="$DMG_PATH.sha256"
  NOTES_PATH="$DIST_DIR/${PRODUCT_NAME}-${VERSION}-release-notes.md"
}

usage() {
  cat <<USAGE
Usage: scripts/release.sh [options]

Options:
  --publish   Create the GitHub Release after building assets.
  --bump <part>
              Bump VERSION before building. part must be major, minor, or patch.
  --force     Allow overwriting an existing GitHub Release asset. Only valid with --publish.
  -h, --help  Show this help.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --publish)
      PUBLISH="true"
      shift
      ;;
    --bump)
      BUMP_PART="${2:-}"
      if [[ -z "$BUMP_PART" ]]; then
        echo "--bump requires major, minor, or patch" >&2
        exit 2
      fi
      shift 2
      ;;
    --force)
      FORCE="true"
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

if [[ "$FORCE" == "true" && "$PUBLISH" != "true" ]]; then
  echo "--force only applies with --publish" >&2
  exit 2
fi

if [[ -n "$BUMP_PART" ]]; then
  case "$BUMP_PART" in
    major|minor|patch)
      "$ROOT_DIR/scripts/bump-version.sh" "$BUMP_PART" >/dev/null
      ;;
    *)
      echo "--bump must be major, minor, or patch" >&2
      exit 2
      ;;
  esac
fi

load_version

if [[ "$PUBLISH" == "true" ]]; then
  TAG="v${VERSION}"
  if gh release view "$TAG" --repo "$REPO" >/dev/null 2>&1 && [[ "$FORCE" != "true" ]]; then
    echo "Release $TAG already exists. Run scripts/bump-version.sh patch, use --bump patch, or rerun with --force to overwrite assets." >&2
    exit 1
  fi
fi

bash "$ROOT_DIR/scripts/build-app.sh" --universal --sign-identity auto --dmg

SHA_LINE="$(cat "$SHA_PATH")"

cat > "$NOTES_PATH" <<NOTES
## ${PRODUCT_NAME} ${VERSION}

Native macOS menu bar quota indicator for Codex. It shows the remaining daily and weekly quota percentages.

### Assets

- DMG: $(basename "$DMG_PATH")
- SHA256: \`$SHA_LINE\`

### Install

1. Download and open \`$(basename "$DMG_PATH")\`.
2. Drag \`${PRODUCT_NAME}.app\` to \`Applications\`.
3. On first launch, Control-click or right-click \`${PRODUCT_NAME}.app\`, then choose \`Open\`.
4. If macOS says the developer cannot be verified, choose \`Open\` again. If it is still blocked, allow it in \`System Settings > Privacy & Security\`.

### Requirements

- macOS 14 or later.
- Codex has already signed in with ChatGPT on this Mac, and \`~/.codex/auth.json\` exists.
- The network can access the ChatGPT backend usage endpoint.

### Distribution Notes

This is an unnotarized DMG and may use ad-hoc signing. Gatekeeper may show a warning on first launch on another Mac.
NOTES

if [[ "$PUBLISH" == "true" ]]; then
  TAG="v${VERSION}"
  if gh release view "$TAG" --repo "$REPO" >/dev/null 2>&1; then
    gh release upload "$TAG" "$DMG_PATH" "$SHA_PATH" --repo "$REPO" --clobber
    gh release edit "$TAG" --repo "$REPO" --notes-file "$NOTES_PATH"
  else
    gh release create "$TAG" "$DMG_PATH" "$SHA_PATH" \
      --repo "$REPO" \
      --target main \
      --title "${PRODUCT_NAME} ${VERSION}" \
      --notes-file "$NOTES_PATH"
  fi
fi

echo "$DMG_PATH"
echo "$SHA_PATH"
echo "$NOTES_PATH"
