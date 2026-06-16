#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
VERSION_FILE="$ROOT_DIR/VERSION"
PART="${1:-}"
DRY_RUN="false"

usage() {
  cat <<USAGE
Usage: scripts/bump-version.sh <major|minor|patch> [--dry-run]

Examples:
  scripts/bump-version.sh patch
  scripts/bump-version.sh minor --dry-run
USAGE
}

if [[ -z "$PART" || "$PART" == "-h" || "$PART" == "--help" ]]; then
  usage
  exit 0
fi

shift
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)
      DRY_RUN="true"
      shift
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

CURRENT_VERSION="$(tr -d '[:space:]' < "$VERSION_FILE")"
if [[ ! "$CURRENT_VERSION" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
  echo "VERSION must be semantic version x.y.z, got: $CURRENT_VERSION" >&2
  exit 1
fi

MAJOR="${BASH_REMATCH[1]}"
MINOR="${BASH_REMATCH[2]}"
PATCH="${BASH_REMATCH[3]}"

case "$PART" in
  major)
    MAJOR=$((MAJOR + 1))
    MINOR=0
    PATCH=0
    ;;
  minor)
    MINOR=$((MINOR + 1))
    PATCH=0
    ;;
  patch)
    PATCH=$((PATCH + 1))
    ;;
  *)
    echo "Unknown version part: $PART" >&2
    usage >&2
    exit 2
    ;;
esac

NEXT_VERSION="${MAJOR}.${MINOR}.${PATCH}"

if [[ "$DRY_RUN" == "true" ]]; then
  echo "$CURRENT_VERSION -> $NEXT_VERSION"
else
  printf '%s\n' "$NEXT_VERSION" > "$VERSION_FILE"
  echo "$NEXT_VERSION"
fi
