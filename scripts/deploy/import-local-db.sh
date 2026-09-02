#!/usr/bin/env bash
# Import a mongodump folder into LOCAL MongoDB on the VM.
#
# WARNING: --drop (default) replaces collections in the LOCAL target DB only.
#          This script never connects to Atlas — only mongodb://localhost by default.
#
# Usage (either path works — script auto-detects layout):
#   ./scripts/deploy/import-local-db.sh ./backups/atlas-20260101/brillarhrportal
#   ./scripts/deploy/import-local-db.sh ./backups/atlas-20260101
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

# mongodump layout: <dump-root>/<db-name>/<collection>.bson
# mongorestore needs different flags depending on which folder you pass:
#   - DB folder (has *.bson directly)     -> --db <name> --dir <db-folder>
#   - Parent folder (has <db-name>/ inside) -> --dir <parent> --nsInclude <db>.*
shopt -s nullglob
bson_files=("$DUMP_PATH"/*.bson)

RESTORE_ARGS=(--uri="$LOCAL_MONGODB_URI")

if [[ ${#bson_files[@]} -gt 0 ]]; then
  echo "Detected database dump folder (contains .bson files directly)."
  RESTORE_ARGS+=(--db="$LOCAL_DB" --dir="$DUMP_PATH")
else
  if [[ ! -d "$DUMP_PATH/$LOCAL_DB" ]]; then
    echo "Error: expected either:" >&2
    echo "  - a folder with .bson files, or" >&2
    echo "  - a parent folder containing '$LOCAL_DB/'" >&2
    exit 1
  fi
  echo "Detected parent dump folder (contains '$LOCAL_DB/' subfolder)."
  RESTORE_ARGS+=(--dir="$DUMP_PATH" --nsInclude="${LOCAL_DB}.*")
fi

if [[ "$DROP_EXISTING" == "true" ]]; then
  RESTORE_ARGS+=(--drop)
  echo "Restoring with --drop (replaces existing collections in '$LOCAL_DB')."
else
  echo "Restoring without --drop (merges into existing '$LOCAL_DB')."
fi

echo "Importing into local database '$LOCAL_DB' ..."
RESTORE_OUTPUT="$(mongorestore "${RESTORE_ARGS[@]}" 2>&1)"
RESTORE_EXIT=$?
echo "$RESTORE_OUTPUT"

if [[ $RESTORE_EXIT -ne 0 ]]; then
  echo "Error: mongorestore failed (exit $RESTORE_EXIT)." >&2
  exit $RESTORE_EXIT
fi

if echo "$RESTORE_OUTPUT" | grep -q "0 document(s) restored successfully"; then
  echo "" >&2
  echo "Error: import finished but 0 documents were restored." >&2
  echo "Check that the dump path is correct and contains .bson files." >&2
  exit 1
fi

DOC_COUNT="$(mongosh "$LOCAL_MONGODB_URI/$LOCAL_DB" --quiet --eval "
  let total = 0;
  db.getCollectionNames().forEach(c => { total += db.getCollection(c).countDocuments(); });
  print(total);
" 2>/dev/null || echo "unknown")"

echo ""
echo "Import complete."
echo "  Local URI    : $LOCAL_MONGODB_URI"
echo "  Database     : $LOCAL_DB"
echo "  Documents    : $DOC_COUNT"
echo ""
echo "Set these in your .env on the VM:"
echo "  MONGODB_URI=$LOCAL_MONGODB_URI"
echo "  MONGODB_DB=$LOCAL_DB"
