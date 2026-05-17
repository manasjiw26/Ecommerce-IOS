#!/usr/bin/env bash
# ========== FILE: scripts/test_all_endpoints.sh ==========
set -euo pipefail

BASE_URL="${BASE_URL:-http://localhost:3000}"
REGISTRY_ID="${REGISTRY_ID:-}"
SHARE_TOKEN="${SHARE_TOKEN:-}"
DEVICE_ID="${DEVICE_ID:-demo-device-001}"

pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1"; exit 1; }

json_get() {
  local url="$1"
  curl -sS -f "$url"
}

json_post() {
  local url="$1"
  local body="$2"
  curl -sS -f -X POST "$url" -H "Content-Type: application/json" -d "$body"
}

json_put() {
  local url="$1"
  local body="$2"
  curl -sS -f -X PUT "$url" -H "Content-Type: application/json" -d "$body"
}

json_delete_body() {
  local url="$1"
  local body="$2"
  curl -sS -f -X DELETE "$url" -H "Content-Type: application/json" -d "$body"
}

node_pick() {
  node -e "let d='';process.stdin.on('data',c=>d+=c);process.stdin.on('end',()=>{try{const j=JSON.parse(d);$1}catch(e){console.error('bad json');process.exit(2)}})"
}

echo "Base URL: $BASE_URL"

# Health
json_get "$BASE_URL/health" | node_pick "if(j.status==='ok') process.exit(0); process.exit(1)"
pass "/health"

# Get a product id
PRODUCT_JSON="$(json_get "$BASE_URL/products")"
PRODUCT_ID="$(echo "$PRODUCT_JSON" | node_pick "const id=(j[0]&&j[0].id)||''; if(!id) process.exit(1); process.stdout.write(String(id))")"
pass "/products"

# Ensure registry id exists (optional: create one quickly)
if [[ -z "$REGISTRY_ID" ]]; then
  echo "REGISTRY_ID not set. Creating a quick registry for tests..."
  REGISTRY_ID="$(json_post "$BASE_URL/registry" "{\"user_id\":\"00000000-0000-0000-0000-000000000001\",\"event_type\":\"Wedding\",\"event_date\":\"2030-01-01\",\"event_location\":\"Test Registry\",\"is_public\":true}" \
    | node_pick "if(!j.id) process.exit(1); process.stdout.write(j.id)")"
fi
pass "registry id ready ($REGISTRY_ID)"

# Add an item to registry
ITEM_ID="$(json_post "$BASE_URL/registry/$REGISTRY_ID/items" "{\"product_id\":$PRODUCT_ID,\"quantity_requested\":1,\"is_most_wanted\":true,\"ai_reason\":\"Seeded by test script\"}" \
  | node_pick "if(!j.id) process.exit(1); process.stdout.write(j.id)")"
pass "POST /registry/:id/items"

# Registry dashboard + budget + share
json_get "$BASE_URL/registry/$REGISTRY_ID/dashboard" | node_pick "if(!j.registry||!j.stats||!Array.isArray(j.items)) process.exit(1)"
pass "GET /registry/:id/dashboard"

json_post "$BASE_URL/registry/$REGISTRY_ID/budget" "{\"budget\":2500}" | node_pick "if(typeof j.budget!=='number') process.exit(1)"
pass "POST /registry/:id/budget"

json_get "$BASE_URL/registry/$REGISTRY_ID/share-link" | node_pick "if(!j.share_token||!j.share_url) process.exit(1); process.stdout.write(j.share_token)"
SHARE_TOKEN="${SHARE_TOKEN:-$(json_get "$BASE_URL/registry/$REGISTRY_ID/share-link" | node_pick "process.stdout.write(j.share_token||'')")}"
pass "GET /registry/:id/share-link"

json_get "$BASE_URL/registry/$REGISTRY_ID/contributions" | node_pick "if(!Array.isArray(j)) process.exit(1)"
pass "GET /registry/:id/contributions"

json_post "$BASE_URL/registry/$REGISTRY_ID/collaborators" "{\"email\":\"partner@example.com\",\"role\":\"editor\"}" | node_pick "if(!j.collaborator) process.exit(1)"
pass "POST /registry/:id/collaborators"

json_get "$BASE_URL/registry/$REGISTRY_ID/collaborators" | node_pick "if(!Array.isArray(j)) process.exit(1)"
pass "GET /registry/:id/collaborators"

if [[ -n "$SHARE_TOKEN" ]]; then
  json_get "$BASE_URL/registry/public/$SHARE_TOKEN" | node_pick "if(!j.registry||!j.stats) process.exit(1)"
  pass "GET /registry/public/:shareToken"
fi

# Cart save-for-later + saved + move-to-registry
json_post "$BASE_URL/cart/save-for-later" "{\"device_id\":\"$DEVICE_ID\",\"product_id\":$PRODUCT_ID}" | node_pick "if(!j.id) process.exit(1)"
pass "POST /cart/save-for-later"

json_get "$BASE_URL/cart/saved/$DEVICE_ID" | node_pick "if(!Array.isArray(j)) process.exit(1)"
pass "GET /cart/saved/:deviceId"

json_post "$BASE_URL/cart/move-to-registry" "{\"device_id\":\"$DEVICE_ID\",\"product_id\":$PRODUCT_ID,\"registry_id\":\"$REGISTRY_ID\",\"quantity_requested\":1,\"ai_reason\":\"Move from saved\"}" | node_pick "if(!j.success) process.exit(1)"
pass "POST /cart/move-to-registry"

json_delete_body "$BASE_URL/cart/save-for-later" "{\"device_id\":\"$DEVICE_ID\",\"product_id\":$PRODUCT_ID}" | node_pick "if(!j.success) process.exit(1)"
pass "DELETE /cart/save-for-later"

# AI: cart
json_post "$BASE_URL/ai/cart-coach" "{\"cart_items\":[{\"product_name\":\"Test\",\"category\":\"Cookware\",\"price\":89,\"quantity\":1}]}" | node_pick "if(typeof j.score!=='number') process.exit(1)"
pass "POST /ai/cart-coach"

json_post "$BASE_URL/ai/occasion-detect" "{\"cart_items\":[{\"name\":\"Skillet\",\"category\":\"Cookware\",\"tags\":[\"cast iron\"]}]}" | node_pick "if(!j.occasion) process.exit(1)"
pass "POST /ai/occasion-detect"

json_get "$BASE_URL/ai/resurface?device_id=$DEVICE_ID" | node_pick "if(!j.all_saved) process.exit(1)"
pass "GET /ai/resurface"

# AI: personalization
json_post "$BASE_URL/ai/style-detect" "{\"device_id\":\"$DEVICE_ID\"}" | node_pick "if(!j.device_id) process.exit(1)"
pass "POST /ai/style-detect"

json_get "$BASE_URL/ai/style-profile?device_id=$DEVICE_ID" | node_pick "if(!j.device_id) process.exit(1)"
pass "GET /ai/style-profile"

# AI: content
json_post "$BASE_URL/ai/gift-message" "{\"contributor_name\":\"Taylor\",\"recipient_name\":\"Jordan\",\"event_type\":\"Wedding\",\"product_name\":\"Skillet\",\"amount\":50}" | node_pick "if(!Array.isArray(j.messages)) process.exit(1)"
pass "POST /ai/gift-message"

json_post "$BASE_URL/ai/thank-you-note" "{\"registry_owner_name\":\"Jordan\",\"contributor_name\":\"Taylor\",\"product_name\":\"Skillet\",\"event_type\":\"Wedding\"}" | node_pick "if(!Array.isArray(j.notes)) process.exit(1)"
pass "POST /ai/thank-you-note"

json_post "$BASE_URL/ai/product-story" "{\"product_id\":$PRODUCT_ID}" | node_pick "if(!j.story) process.exit(1)"
pass "POST /ai/product-story"

# AI: compare + bundle
json_post "$BASE_URL/ai/compare-products" "{\"product_ids\":[${PRODUCT_ID}]}" >/dev/null 2>&1 && fail "POST /ai/compare-products should reject 1 id" || pass "POST /ai/compare-products validation"

TWO_IDS="$(echo "$PRODUCT_JSON" | node_pick "const ids=j.slice(0,2).map(x=>x.id); if(ids.length<2) process.exit(1); process.stdout.write(ids.join(','))")"
json_post "$BASE_URL/ai/compare-products" "{\"product_ids\":[${TWO_IDS}]}" | node_pick "if(!j.winner_id) process.exit(1)"
pass "POST /ai/compare-products"

json_post "$BASE_URL/ai/bundle-build" "{\"theme\":\"starter kitchen\",\"budget\":250}" | node_pick "if(!j.bundle_name||!Array.isArray(j.products)) process.exit(1)"
pass "POST /ai/bundle-build"

# AI: chat
SESSION_ID="demo-session-001"
json_post "$BASE_URL/ai/chat-session" "{\"device_id\":\"$DEVICE_ID\",\"session_id\":\"$SESSION_ID\",\"messages\":[{\"role\":\"user\",\"content\":\"I need wedding registry help under 200\"}]}" \
  | node_pick "if(!Array.isArray(j.content)||!j.content[0]||!j.content[0].text) process.exit(1)"
pass "POST /ai/chat-session"

json_get "$BASE_URL/ai/chat-history?device_id=$DEVICE_ID&session_id=$SESSION_ID" | node_pick "if(!Array.isArray(j.messages)) process.exit(1)"
pass "GET /ai/chat-history"

json_delete_body "$BASE_URL/ai/chat-history" "{\"device_id\":\"$DEVICE_ID\",\"session_id\":\"$SESSION_ID\"}" | node_pick "if(!j.success) process.exit(1)"
pass "DELETE /ai/chat-history"

# AI: search enhancements
json_post "$BASE_URL/ai/smart-search" "{\"query\":\"cast iron\",\"device_id\":\"$DEVICE_ID\"}" | node_pick "if(!j.intent_analysis||!Array.isArray(j.products)) process.exit(1)"
pass "POST /ai/smart-search"

json_post "$BASE_URL/ai/price-insight" "{\"product_id\":$PRODUCT_ID}" | node_pick "if(!j.verdict) process.exit(1)"
pass "POST /ai/price-insight"

# AI Registry router
json_post "$BASE_URL/ai/registry/suggest" "{\"event_type\":\"Wedding\",\"budget\":2000,\"existing_categories\":[\"Cookware\"]}" | node_pick "if(!Array.isArray(j.suggestions)) process.exit(1)"
pass "POST /ai/registry/suggest"

json_post "$BASE_URL/ai/registry/budget-plan" "{\"event_type\":\"Wedding\",\"total_budget\":2000}" | node_pick "if(!Array.isArray(j.allocations)) process.exit(1)"
pass "POST /ai/registry/budget-plan"

json_post "$BASE_URL/ai/registry/completeness" "{\"registry_id\":\"$REGISTRY_ID\",\"event_type\":\"Wedding\"}" | node_pick "if(typeof j.score!=='number') process.exit(1)"
pass "POST /ai/registry/completeness"

json_post "$BASE_URL/ai/registry/theme" "{\"event_type\":\"Wedding\",\"style_hints\":\"minimalist\"}" | node_pick "if(!Array.isArray(j.themes)) process.exit(1)"
pass "POST /ai/registry/theme"

json_post "$BASE_URL/ai/registry/timeline" "{\"event_type\":\"Wedding\",\"event_date\":\"2030-01-01\",\"registry_id\":\"$REGISTRY_ID\"}" | node_pick "if(!Array.isArray(j.phases)) process.exit(1)"
pass "POST /ai/registry/timeline"

json_get "$BASE_URL/ai/registry/gift-picker?registry_id=$REGISTRY_ID&budget=100" | node_pick "if(!Array.isArray(j.recommendations)) process.exit(1)"
pass "GET /ai/registry/gift-picker"

json_post "$BASE_URL/ai/registry/trending-occasion" "{\"event_type\":\"Wedding\"}" | node_pick "if(!j.event_type) process.exit(1)"
pass "POST /ai/registry/trending-occasion"

echo "ALL TESTS PASSED ✅"
