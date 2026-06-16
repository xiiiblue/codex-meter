#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PRODUCT_NAME="CodexMeter"
VERSION="$(sed -n 's/^VERSION="\([^"]*\)"/\1/p' "$ROOT_DIR/scripts/build-app.sh" | head -n 1)"
DIST_DIR="$ROOT_DIR/dist"
DMG_PATH="$DIST_DIR/${PRODUCT_NAME}-${VERSION}.dmg"
SHA_PATH="$DMG_PATH.sha256"
NOTES_PATH="$DIST_DIR/${PRODUCT_NAME}-${VERSION}-release-notes.md"
PUBLISH="false"
REPO="xiiiblue/codex-meter"

usage() {
  cat <<USAGE
Usage: scripts/release.sh [options]

Options:
  --publish   Create or update the GitHub Release after building assets.
  -h, --help  Show this help.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --publish)
      PUBLISH="true"
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

bash "$ROOT_DIR/scripts/build-app.sh" --universal --sign-identity auto --dmg

SHA_LINE="$(cat "$SHA_PATH")"

cat > "$NOTES_PATH" <<NOTES
## ${PRODUCT_NAME} ${VERSION}

macOS菜单栏Codex额度指示器，显示日限额和周限额剩余百分比。

### 产物

- DMG：$(basename "$DMG_PATH")
- SHA256：\`$SHA_LINE\`

### 安装

1. 下载并打开\`$(basename "$DMG_PATH")\`。
2. 将\`${PRODUCT_NAME}.app\`拖到\`Applications\`。
3. 首次启动请按住Control点击或右键点击\`${PRODUCT_NAME}.app\`，选择“打开”。
4. 如果macOS提示无法验证开发者，继续选择“打开”；如果仍被阻止，到“系统设置 > 隐私与安全性”中允许打开。

### 使用前提

- macOS14或更高版本。
- 已在本机Codex中通过ChatGPT登录，并存在\`~/.codex/auth.json\`。
- 网络可访问ChatGPT后端额度接口。

### 分发说明

这是未公证版DMG，可能使用ad-hoc签名。陌生机器首次打开可能出现Gatekeeper提示。
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
