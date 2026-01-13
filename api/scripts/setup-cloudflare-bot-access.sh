#!/usr/bin/env bash
set -euo pipefail

# =========================
# Cloudflare Access bot setup
# =========================
# Requires:
#   - curl
#   - jq
#
# Env vars required:
#   CF_API_TOKEN      (Cloudflare API token)
#   CF_ACCOUNT_ID     (Cloudflare account id)
#   CF_ZONE_ID        (Zone id for pupculture.site)
#   CF_TEAM_NAME      (Zero Trust team name, e.g. "pupculture" for pupculture.cloudflareaccess.com)
#   CF_APP_DOMAIN     (e.g. api.pupculture.site)
#
# Optional:
#   CF_APP_NAME       (default: "PupCulture Bot API")
#   CF_APP_PATH       (default: /bot/*)
#
# Output:
#   Prints Service Token client id/secret for use as:
#     CF_ACCESS_CLIENT_ID
#     CF_ACCESS_CLIENT_SECRET

need() { command -v "$1" >/dev/null 2>&1 || { echo "❌ Missing dependency: $1"; exit 1; }; }

need curl
need jq

: "${CF_API_TOKEN:?Set CF_API_TOKEN}"
: "${CF_ACCOUNT_ID:?Set CF_ACCOUNT_ID}"
: "${CF_ZONE_ID:?Set CF_ZONE_ID}"
: "${CF_TEAM_NAME:?Set CF_TEAM_NAME}"
: "${CF_APP_DOMAIN:?Set CF_APP_DOMAIN}"

CF_APP_NAME="${CF_APP_NAME:-PupCulture Bot API}"
CF_APP_PATH="${CF_APP_PATH:-/bot/*}"

api() {
  local method="$1"; shift
  local url="$1"; shift
  curl -sS -X "$method" "$url" \
    -H "Authorization: Bearer ${CF_API_TOKEN}" \
    -H "Content-Type: application/json" \
    "$@"
}

echo "🔎 Creating Access Application for https://${CF_APP_DOMAIN}${CF_APP_PATH} ..."

# 1) Create Application
APP_RESP="$(api POST "https://api.cloudflare.com/client/v4/accounts/${CF_ACCOUNT_ID}/access/apps" \
  --data "$(jq -n \
    --arg name "$CF_APP_NAME" \
    --arg domain "$CF_APP_DOMAIN" \
    --arg path "$CF_APP_PATH" \
    '{
      name: $name,
      domain: $domain,
      type: "self_hosted",
      session_duration: "24h",
      allowed_idps: [],
      auto_redirect_to_identity: false,
      app_launcher_visible: false,
      cors_headers: null,
      same_site_cookie_attribute: "lax",
      paths: [$path]
    }')"
)"

if [[ "$(echo "$APP_RESP" | jq -r '.success')" != "true" ]]; then
  echo "❌ Failed to create app:"
  echo "$APP_RESP" | jq .
  exit 1
fi

APP_ID="$(echo "$APP_RESP" | jq -r '.result.id')"
echo "✅ App created: $APP_ID"

# 2) Create a Service Token
echo "🔐 Creating Service Token..."
TOKEN_RESP="$(api POST "https://api.cloudflare.com/client/v4/accounts/${CF_ACCOUNT_ID}/access/service_tokens" \
  --data "$(jq -n --arg name "bot-${CF_APP_DOMAIN}-$(date +%Y%m%d%H%M%S)" '{name:$name}')"
)"

if [[ "$(echo "$TOKEN_RESP" | jq -r '.success')" != "true" ]]; then
  echo "❌ Failed to create service token:"
  echo "$TOKEN_RESP" | jq .
  exit 1
fi

TOKEN_ID="$(echo "$TOKEN_RESP" | jq -r '.result.id')"
CLIENT_ID="$(echo "$TOKEN_RESP" | jq -r '.result.client_id')"
CLIENT_SECRET="$(echo "$TOKEN_RESP" | jq -r '.result.client_secret')"

echo "✅ Service Token created: $TOKEN_ID"

# 3) Create Policy that allows ONLY this service token
echo "🛡️ Creating Access Policy: Service Token ONLY..."
POLICY_RESP="$(api POST "https://api.cloudflare.com/client/v4/accounts/${CF_ACCOUNT_ID}/access/apps/${APP_ID}/policies" \
  --data "$(jq -n \
    --arg name "Allow Bot Service Token" \
    --arg sid "$TOKEN_ID" \
    '{
      name: $name,
      decision: "allow",
      include: [
        { "service_token": { "id": $sid } }
      ]
    }')"
)"

if [[ "$(echo "$POLICY_RESP" | jq -r '.success')" != "true" ]]; then
  echo "❌ Failed to create policy:"
  echo "$POLICY_RESP" | jq .
  exit 1
fi

echo "✅ Policy created."

cat <<EOF

============================================================
✅ DONE. Put these in your .env (DO NOT COMMIT THEM)
CF_ACCESS_CLIENT_ID=${CLIENT_ID}
CF_ACCESS_CLIENT_SECRET=${CLIENT_SECRET}
============================================================

Your bot endpoint should be protected at:
https://${CF_APP_DOMAIN}${CF_APP_PATH}

EOF
