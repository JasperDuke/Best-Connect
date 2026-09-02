#!/usr/bin/env bash
# Copy uploaded files (CVs, learning assets, etc.) from the old VM.
# These files are NOT stored in MongoDB — only paths/metadata are in the DB.
#
# Usage:
#   export OLD_VM_USER=ubuntu
#   export OLD_VM_HOST=old-server.example.com
#   export OLD_UPLOADS_PATH=/opt/hr-connect/app/uploads
#   ./scripts/deploy/sync-uploads.sh
#
# Or with explicit rsync source:
#   ./scripts/deploy/sync-uploads.sh user@host:/path/to/uploads

set -euo pipefail

RSYNC_SOURCE="${1:-}"
OLD_VM_USER="${OLD_VM_USER:-}"
OLD_VM_HOST="${OLD_VM_HOST:-}"
OLD_UPLOADS_PATH="${OLD_UPLOADS_PATH:-/opt/hr-connect/app/uploads}"

APP_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
LOCAL_UPLOADS="${UPLOADS_ROOT:-$APP_ROOT/uploads}"

if [[ -z "$RSYNC_SOURCE" ]]; then
  if [[ -z "$OLD_VM_USER" || -z "$OLD_VM_HOST" ]]; then
    echo "Usage:" >&2
    echo "  $0 user@host:/remote/uploads/path" >&2
    echo "  or set OLD_VM_USER + OLD_VM_HOST (+ optional OLD_UPLOADS_PATH)" >&2
    exit 1
  fi
  RSYNC_SOURCE="${OLD_VM_USER}@${OLD_VM_HOST}:${OLD_UPLOADS_PATH}/"
fi

if ! command -v rsync >/dev/null 2>&1; then
  echo "Error: rsync not found." >&2
  exit 1
fi

mkdir -p "$LOCAL_UPLOADS"

echo "Syncing uploads ..."
echo "  From : $RSYNC_SOURCE"
echo "  To   : $LOCAL_UPLOADS/"
rsync -avz --progress "$RSYNC_SOURCE" "$LOCAL_UPLOADS/"

echo ""
echo "Done. Set in .env if you use a custom path:"
echo "  UPLOADS_ROOT=$LOCAL_UPLOADS"
