#!/usr/bin/env bash
# Export MongoDB data from Atlas (or any remote MongoDB) to a local dump folder.
#
# SAFE: uses mongodump only — READ-ONLY on the source database.
#       Nothing is deleted, modified, or dropped on Atlas.
#
# Run this on a machine that can reach Atlas (old VM, your laptop, etc.).
#
# Usage:
#   export ATLAS_URI='mongodb+srv://user:pass@cluster.mongodb.net/?retryWrites=true&w=majority'
#   export ATLAS_DB='brillarhrportal'
#   ./scripts/deploy/export-atlas-db.sh
#
# Or pass URI as first argument:
#   ./scripts/deploy/export-atlas-db.sh 'mongodb+srv://...' brillarhrportal

set -euo pipefail

ATLAS_URI="${1:-${ATLAS_URI:-}}"
ATLAS_DB="${2:-${ATLAS_DB:-brillarhrportal}}"
DUMP_DIR="${DUMP_DIR:-./backups/atlas-$(date +%Y%m%d-%H%M%S)}"

if [[ -z "$ATLAS_URI" ]]; then
  echo "Error: provide Atlas URI via argument or ATLAS_URI env var." >&2
  exit 1
fi

if ! command -v mongodump >/dev/null 2>&1; then
  echo "Error: mongodump not found. Install MongoDB Database Tools first." >&2
  echo "  https://www.mongodb.com/docs/database-tools/installation/" >&2
  exit 1
fi

mkdir -p "$DUMP_DIR"

echo "Exporting database '$ATLAS_DB' to $DUMP_DIR ..."
echo "(read-only — Atlas data is not modified)"
mongodump \
  --uri="$ATLAS_URI" \
  --db="$ATLAS_DB" \
  --out="$DUMP_DIR"

echo ""
echo "Export complete."
echo "  Dump path : $DUMP_DIR/$ATLAS_DB"
echo ""
echo "Next step — copy dump to your VM, then run:"
echo "  ./scripts/deploy/import-local-db.sh $DUMP_DIR/$ATLAS_DB $ATLAS_DB"
