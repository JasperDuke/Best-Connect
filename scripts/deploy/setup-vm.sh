#!/usr/bin/env bash
# One-time VM setup for HR Connect (Ubuntu/Debian).
# Run as a user with sudo access.
#
# Usage:
#   ./scripts/deploy/setup-vm.sh
#
# What it installs:
#   - Node.js LTS
#   - PM2 (global)
#   - MongoDB Database Tools (mongodump/mongorestore)
#   - Creates logs/ and uploads/ directories

set -euo pipefail

APP_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

echo "==> Installing system packages ..."
sudo apt update
sudo apt install -y curl ca-certificates gnupg rsync

if ! command -v node >/dev/null 2>&1; then
  echo "==> Installing Node.js LTS ..."
  curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
  sudo apt install -y nodejs
fi

echo "Node: $(node -v)"
echo "npm : $(npm -v)"

if ! command -v pm2 >/dev/null 2>&1; then
  echo "==> Installing PM2 globally ..."
  sudo npm install -g pm2
fi

if ! command -v mongodump >/dev/null 2>&1; then
  echo "==> Installing MongoDB Database Tools ..."
  if ! grep -q mongodb-org /etc/apt/sources.list.d/*.list 2>/dev/null; then
    curl -fsSL https://www.mongodb.org/static/pgp/server-7.0.asc \
      | sudo gpg -o /usr/share/keyrings/mongodb-server-7.0.gpg --dearmor
    echo "deb [ signed-by=/usr/share/keyrings/mongodb-server-7.0.gpg ] https://repo.mongodb.org/apt/ubuntu jammy/mongodb-org/7.0 multiverse" \
      | sudo tee /etc/apt/sources.list.d/mongodb-org-7.0.list
    sudo apt update
  fi
  sudo apt install -y mongodb-database-tools
fi

echo "==> Installing app dependencies ..."
cd "$APP_ROOT"
npm ci --omit=dev

mkdir -p "$APP_ROOT/logs" "$APP_ROOT/uploads"
chmod 700 "$APP_ROOT/uploads" 2>/dev/null || true

if [[ ! -f "$APP_ROOT/.env" ]]; then
  cp "$APP_ROOT/.env.example" "$APP_ROOT/.env"
  echo ""
  echo "Created .env from .env.example — edit it before starting:"
  echo "  nano $APP_ROOT/.env"
fi

echo ""
echo "==> VM setup complete."
echo ""
echo "Next steps:"
echo "  1. Install & start local MongoDB (if not already):"
echo "       sudo apt install -y mongodb-org"
echo "       sudo systemctl enable --now mongod"
echo "  2. Import DB from Atlas:"
echo "       ./scripts/deploy/import-local-db.sh <dump-folder>"
echo "  3. Copy uploads from old VM:"
echo "       ./scripts/deploy/sync-uploads.sh user@old-host:/path/to/uploads"
echo "  4. Edit .env (MONGODB_URI, secrets, CORS, MS_REDIRECT_URI)"
echo "  5. Start with PM2:"
echo "       npm run pm2:start"
echo "  6. (Optional) PM2 boot on reboot:"
echo "       pm2 startup && pm2 save"
