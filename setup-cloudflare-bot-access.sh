#!/usr/bin/env bash
set -euo pipefail

############################################
# CONFIG — CHANGE ONLY IF YOUR DOMAIN CHANGES
############################################
APP_NAME="PupCulture Bot API"
APP_URL="https://api.pupculture.site/bot/*"
ENV_FILE="../.env"

############################################
# DEPENDENCY CHECKS
############################################
command -v curl >/dev/null || { echo "❌ Missing curl"; exit 1; }
command -v jq >/dev/null || { echo "❌ Missing jq"; exit 1; }

############################################
# REQUIRED ENV
############################################
if [[ -z "${CF_API_TOKEN:-}" ]]; then
  echo "❌ CF_API_TOKEN is not set"
  echo "Run: export CF_API_TOKEN=\"your_token_here\""
  exit 1
fi

############################################
# VERIFY TOKEN
############################################
echo "🔍 Verifying Cloudflare API token…"
ACCOUNT_JSON=$(curl -s \
  -H "Authorization: Bearer $CF_API_TOKEN" \
  https://api.cloudflare.com/client/v4/accounts)

if [[ "$(echo "$ACCOUNT_JSON" | jq -r '.success')" != "true" ]]; then
  echo "❌ Cloudflare API token invalid or under-permissioned"
  echo "$ACCOUNT_JSON"
  exit 1
fi

ACCOUNT_ID=$(echo "$ACCOUNT_JSON" | jq -r '.result[0].id')
echo "✅ Account ID: $ACCOUNT_ID"

############################################
# CREATE ACCESS APPLICATION
############################################
echo "🔎 Creating Access Application for $APP_URL …"

APP_RESPONSE=$(curl -s -X POST \
  "https://api.cloudflare.com/client/v4/accounts/$ACCOUNT_ID/access/apps" \
  -H "Authorization: Bearer $CF_API_TOKEN" \
  -H "Content-Type: application/json" \
  --data @- <<EOF
{
  "name": "$APP_NAME",
  "domain": "api.pupculture.site",
  "type": "self_hosted",
  "session_duration": "24h",
  "allowed_idps": [],
  "auto_redirect_to_identity": false,
  "path": "/bot/*"
}
EOF
)

if [[ "$(echo "$APP_RESPONSE" | jq -r '.success')" != "true" ]]; then
  echo "❌ Failed to create Access app"
  echo "$APP_RESPONSE"
  exit 1
fi

APP_ID=$(echo "$APP_RESPONSE" | jq -r '.result.id')
echo "✅ Access App ID: $APP_ID"

############################################
# CREATE SERVICE TOKEN
############################################
echo "🔐 Creating Cloudflare Service Token…"

TOKEN_RESPONSE=$(curl -s -X POST \
  "https://api.cloudflare.com/client/v4/accounts/$ACCOUNT_ID/access/service_tokens" \
  -H "Authorization: Bearer $CF_API_TOKEN" \
  -H "Content-Type: application/json" \
  --data '{"name":"pupculture-bot"}')

if [[ "$(echo "$TOKEN_RESPONSE" | jq -r '.success')" != "true" ]]; then
  echo "❌ Failed to create service token"
  echo "$TOKEN_RESPONSE"
  exit 1
fi

CF_CLIENT_ID=$(echo "$TOKEN_RESPONSE" | jq -r '.result.client_id')
CF_CLIENT_SECRET=$(echo "$TOKEN_RESPONSE" | jq -r '.result.client_secret')

############################################
# GENERATE BOT API KEY
############################################
BOT_API_KEY="bot_$(openssl rand -hex 32)"

############################################
# WRITE .env
############################################
echo "✍️ Writing credentials to .env"

touch "$ENV_FILE"

sed -i '/^CF_ACCESS_CLIENT_ID=/d' "$ENV_FILE"
sed -i '/^CF_ACCESS_CLIENT_SECRET=/d' "$ENV_FILE"
sed -i '/^BOT_API_KEY=/d' "$ENV_FILE"

cat >> "$ENV_FILE" <<EOF
CF_ACCESS_CLIENT_ID=$CF_CLIENT_ID
CF_ACCESS_CLIENT_SECRET=$CF_CLIENT_SECRET
BOT_API_KEY=$BOT_API_KEY
API_BASE_URL=https://api.pupculture.site
EOF

############################################
# FINAL OUTPUT
############################################
echo ""
echo "✅ Cloudflare bot access configured"
echo "----------------------------------"
echo "CF_ACCESS_CLIENT_ID=$CF_CLIENT_ID"
echo "CF_ACCESS_CLIENT_SECRET=********"
echo "BOT_API_KEY=$BOT_API_KEY"
echo ""
echo "➡️ Run: docker compose up -d --build"
echo ""

