#!/usr/bin/env bash
# Import a mongodump folder into LOCAL MongoDB on the VM.
#
# WARNING: --drop (default) replaces collections in the LOCAL target DB only.
#          This script never connects to Atlas — only mongodb://localhost by default.
# Usage:
#   ./scripts/deploy/import-local-db.sh ./backups/atlas-20260101/brillarhrportal
#   ./scripts/deploy/import-local-db.sh ./backups/atlas-20260101/brillarhrportal brillarhrportal
#
# Env overrides:
#   LOCAL_MONGODB_URI=mongodb://localhost:27017
#   LOCAL_DB=brillarhrportal
#   DROP_EXISTING=true   # drop collections before restore (default: true)

set -euo pipefail

DUMP_PATH="${1:-}"
LOCAL_DB="${2:-${LOCAL_DB:-brillarhrportal}}"
LOCAL_MONGODB_URI="${LOCAL_MONGODB_URI:-mongodb://localhost:27017}"
DROP_EXISTING="${DROP_EXISTING:-true}"

if [[ -z "$DUMP_PATH" ]]; then
  echo "Usage: $0 <path-to-dump-folder> [database-name]" >&2
  exit 1
fi

if [[ ! -d "$DUMP_PATH" ]]; then
  echo "Error: dump folder not found: $DUMP_PATH" >&2
  exit 1
fi

if ! command -v mongorestore >/dev/null 2>&1; then
  echo "Error: mongorestore not found. Install MongoDB Database Tools first." >&2
  exit 1
fi

echo "Checking local MongoDB at $LOCAL_MONGODB_URI ..."
if ! mongosh "$LOCAL_MONGODB_URI" --eval "db.adminCommand('ping')" --quiet >/dev/null 2>&1; then
  echo "Error: cannot reach local MongoDB. Start the service first:" >&2
  echo "  sudo systemctl start mongod" >&2
  exit 1
fi

RESTORE_ARGS=(
  --uri="$LOCAL_MONGODB_URI"
  --nsInclude="${LOCAL_DB}.*"
  --dir="$DUMP_PATH"
)

if [[ "$DROP_EXISTING" == "true" ]]; then
  RESTORE_ARGS+=(--drop)
  echo "Restoring with --drop (replaces existing collections in '$LOCAL_DB')."
else
  echo "Restoring without --drop (merges into existing '$LOCAL_DB')."
fi

echo "Importing into local database '$LOCAL_DB' ..."
mongorestore "${RESTORE_ARGS[@]}"

echo ""
echo "Import complete."
echo "  Local URI : $LOCAL_MONGODB_URI"
echo "  Database  : $LOCAL_DB"
echo ""
echo "Set these in your .env on the VM:"
echo "  MONGODB_URI=$LOCAL_MONGODB_URI"
echo "  MONGODB_DB=$LOCAL_DB"
