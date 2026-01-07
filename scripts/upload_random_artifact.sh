#!/usr/bin/env bash
# scripts/upload_random_artifact.sh
# Upload a tarball to an arbitrary HTTP endpoint or to a GitHub Release, with a random chance.
# Usage:
#   PROB=20 UPLOAD_URL=https://example.com/upload UPLOAD_TOKEN=... ./scripts/upload_random_artifact.sh
#   or to upload to GitHub release (requires `gh` CLI and GH_TOKEN):
#   PROB=100 RELEASE_TAG=v1.0 ./scripts/upload_random_artifact.sh

set -euo pipefail
TARBALL=${1:-"bak/20251230-030000/plm-ci-debug-20251230-030000.tar.gz"}
PROB=${PROB:-10}
DRY_RUN=${DRY_RUN:-0}
UPLOAD_URL=${UPLOAD_URL:-}
UPLOAD_TOKEN=${UPLOAD_TOKEN:-}
RELEASE_TAG=${RELEASE_TAG:-}
GH_REPO=${GH_REPO:-"${GITHUB_REPOSITORY:-}"}

rand=$((RANDOM % 100))
echo "Random value: $rand (threshold: $PROB)"
if [ "$rand" -ge "$PROB" ]; then
  echo "Skipping upload (random threshold not met)."
  exit 0
fi

if [ "$DRY_RUN" -ne 0 ]; then
  echo "DRY RUN: would upload $TARBALL"
  exit 0
fi

if [ -n "$UPLOAD_URL" ]; then
  if [ -z "$UPLOAD_TOKEN" ]; then
    if [ -t 0 ]; then
      read -r -s -p "Enter UPLOAD_TOKEN (won't echo): " UPLOAD_TOKEN
      echo
    fi
    if [ -z "$UPLOAD_TOKEN" ]; then
      echo "UPLOAD_TOKEN is required for UPLOAD_URL"
      exit 1
    fi
  fi
  echo "Uploading $TARBALL to $UPLOAD_URL"
  curl -f -X POST "$UPLOAD_URL" -H "Authorization: Bearer $UPLOAD_TOKEN" -F "file=@${TARBALL}" || { echo "Upload failed."; exit 1; }
  echo "Upload complete."
  exit 0
fi

if [ -n "$RELEASE_TAG" ]; then
  if ! command -v gh >/dev/null 2>&1; then
    echo "gh CLI required to upload to GitHub release. Install and authenticate first."; exit 1
  fi
  echo "Uploading $TARBALL to GitHub release $RELEASE_TAG"
  gh release upload "$RELEASE_TAG" "$TARBALL" --repo "$GH_REPO" || { echo "gh upload failed."; exit 1; }
  echo "Upload to release complete."
  exit 0
fi

echo "No upload configured (set UPLOAD_URL+UPLOAD_TOKEN, or RELEASE_TAG). Exiting." 
exit 2
