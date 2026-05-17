<!-- ========== FILE: API_DOCS.md ========== -->

# SmartCart Backend API (Williams Sonoma AI Hackathon)

Base URL (local): `http://localhost:3000`  
All endpoints return JSON.

## Health

### GET /health
**What it does**: Render / uptime health check

**Response**
```json
{ "status": "ok", "timestamp": "2026-05-17T12:00:00.000Z", "env": "development" }
```

**iOS integration**: Use for debug diagnostics / status screen

---

## Products

### GET /products
**What it does**: List products (optionally filtered by category)

**Request**
Query params:
- `category` (optional)

**Response**
```json
[
  { "id": 12, "name": "…", "price": 89, "category": "Cookware", "image_url": "https://…" }
]
```

**iOS integration**: `ProductsService.swift` for browse + category pages

### GET /products/:id
**What it does**: Get a single product by id

**Response**
```json
{ "id": 12, "name": "…", "price": 89, "category": "Cookware", "image_url": "https://…" }
```

### GET /products/:id/stock
**What it does**: Get current stock count

**Response**
```json
{ "id": 12, "stock": 7 }
```

---

## Auth

### POST /auth/signup
**What it does**: Create a user in Supabase Auth

**Request**
```json
{ "name": "Jordan", "email": "jordan@example.com", "password": "secret123" }
```

**Response**
```json
{ "user": { "id": "uuid", "email": "…", "name": "Jordan" }, "access_token": "…" }
```

### POST /auth/login
**What it does**: Login via Supabase Auth

**Request**
```json
{ "email": "jordan@example.com", "password": "secret123" }
```

### POST /auth/logout
**What it does**: Logout current session (server-side)

---

## Orders

### POST /orders
**What it does**: Verifies stock, inserts an order, deducts stock for cart items

**Request**
```json
{
  "user_id": "uuid",
  "total": 249.0,
  "items_summary": "Skillet x1, Knife x1",
  "image_url": "https://…",
  "payment_id": "pay_123",
  "cart_items": [ { "product_id": 12, "quantity": 1 } ]
}
```

**Response**
```json
{ "message": "Order placed successfully", "order": { "id": "…", "status": "Processing" } }
```

### GET /orders/:userId
**What it does**: Fetches order history for a user

---

## Payment

### POST /payment/create-order
**What it does**: Creates a Razorpay order

**Request**
```json
{ "amount": 50.0 }
```

### POST /payment/verify
**What it does**: Verifies Razorpay signature

---

## Registry

### GET /registry/user/:userId
**What it does**: Lists registries for a user

### GET /registry/:id
**What it does**: Gets a registry by id

### POST /registry
**What it does**: Creates a registry

**Request**
```json
{
  "user_id": "uuid",
  "event_type": "Wedding",
  "event_date": "2030-01-01",
  "event_location": "Jordan & Alex's Wedding",
  "is_public": true
}
```

### GET /registry/:id/items
**What it does**: Lists registry items joined with product details (image URLs fixed)

### POST /registry/:id/items
**What it does**: Adds a product to the registry and snapshots product price (`price_snapshot`)

**Request**
```json
{ "product_id": 12, "quantity_requested": 1, "is_most_wanted": true, "ai_reason": "Perfect starter cookware essential." }
```

### PUT /registry/:id/items/:itemId
**What it does**: Updates a registry item (e.g., quantities received)

### DELETE /registry/:id/items/:itemId
**What it does**: Deletes a registry item

### POST /registry/:id/budget
**What it does**: Updates registry budget

**Request**
```json
{ "budget": 3000 }
```

### GET /registry/:id/dashboard
**What it does**: Aggregate endpoint for the main registry screen (registry + stats + items + contributions)

**Response**
```json
{
  "registry": { "id": "…", "event_type": "Wedding", "event_date": "2030-01-01", "budget": 3000, "share_token": "…", "theme": "…" },
  "stats": { "total_items": 8, "purchased_items": 3, "pending_items": 5, "budget_total": 3000, "budget_used": 178, "budget_remaining": 2822, "completion_pct": 38, "days_until_event": 120 },
  "items": [ { "id": "…", "price_snapshot": 89, "product": { "id": 12, "name": "…", "image_url": "https://…" }, "total_contributed": 125, "is_fully_funded": false } ]
}
```

**iOS integration**: `RegistryService.swift` main registry screen

### POST /registry/:id/contribute
**What it does**: Adds a group-gifting contribution to a registry item

**Request**
```json
{ "registry_item_id": "uuid", "contributor_name": "Taylor", "amount": 50, "message": "So happy for you!" }
```

### GET /registry/:id/contributions
**What it does**: Returns contributions grouped by registry item

### POST /registry/:id/collaborators
**What it does**: Adds a collaborator (idempotent)

**Request**
```json
{ "email": "partner@example.com", "role": "editor" }
```

### GET /registry/:id/collaborators
**What it does**: Lists collaborators

### GET /registry/:id/share-link
**What it does**: Returns share token + share URL

### GET /registry/public/:shareToken
**What it does**: Public guest view of registry dashboard

---

## Cart

### POST /cart
**What it does**: Adds an item to cart (upserts quantity)

### GET /cart/:userId
**What it does**: Gets a user’s cart (joined products)

### DELETE /cart/:itemId
**What it does**: Removes a cart item

### POST /cart/save-for-later
**What it does**: Saves a product for later (device-scoped)

**Request**
```json
{ "device_id": "demo-device-001", "product_id": 12 }
```

### DELETE /cart/save-for-later
**What it does**: Removes a saved item

### GET /cart/saved/:deviceId
**What it does**: Lists saved items joined with product details

### POST /cart/move-to-registry
**What it does**: Moves a saved product into a registry item (snapshots price)

**Request**
```json
{ "device_id": "demo-device-001", "product_id": 12, "registry_id": "uuid", "quantity_requested": 1, "ai_reason": "Completes your cookware basics." }
```

---

## AI (Search + Discovery)

### POST /ai/search
**What it does**: Hybrid search (local embeddings + Supabase `hybrid_search` RPC fallback)

**Request**
```json
{ "query": "cast iron skillet", "device_id": "demo-device-001" }
```

### GET /ai/autocomplete?q=...
**What it does**: Returns search suggestions

### POST /ai/search/analytics
**What it does**: Records a search term for analytics

### GET /ai/trending-searches
**What it does**: Returns top searches from the last 7 days

### GET /ai/recent-searches?device_id=...
**What it does**: Returns recent searches for a device

### POST /ai/smart-search
**What it does**: Gemini intent analysis + routed into the search pipeline

**Request**
```json
{ "query": "coffee gifts", "device_id": "demo-device-001" }
```

### POST /ai/price-insight
**What it does**: Gemini pricing analysis for a product vs similar products

---

## AI (Visual)

### POST /ai/visual-search
**What it does**: Gemini turns an image into a search query and returns products

**Request**
```json
{ "image_url": "https://example.com/myimage.jpg", "device_id": "demo-device-001" }
```

### POST /ai/visual-search/feedback
**What it does**: Logs feedback on a visual result

### POST /ai/aesthetic-suggest
**What it does**: Upload a kitchen photo and get aesthetic-matched product suggestions (cutlery/tabletop) + a style profile

**Request**
```json
{
  "image_url": "https://example.com/kitchen.jpg",
  "budget": 200,
  "room_type": "kitchen",
  "desired_items": ["cutlery", "dinnerware"]
}
```

**Response**
```json
{
  "profile": { "style_label": "Modern Minimal", "dominant_colors": ["#111827","#F5F0E8"], "search_queries": ["brushed stainless flatware set"] },
  "suggestions": [ { "id": 12, "name": "…", "price": 89, "image_url": "https://…" } ],
  "suggested_next_searches": ["brushed stainless flatware set"]
}
```

### POST /ai/aesthetic-match
**What it does**: Aesthetic-matched product suggestions **without Gemini**. iOS extracts palette/keywords on-device (VisionKit/CoreImage) and sends them here.

**Request**
```json
{
  "palette_hex": ["#111827", "#F5F0E8", "#C8B8A6"],
  "materials": ["stainless steel", "ceramic"],
  "finish_keywords": ["matte", "brushed"],
  "mood_keywords": ["minimal", "warm"],
  "categories": ["Dinnerware", "Kitchen Tools"],
  "desired_items": ["cutlery", "dinnerware"],
  "budget": 200
}
```

**Response**
```json
{
  "profile": { "style_label": "client_extracted", "dominant_colors": ["#111827","#F5F0E8"] },
  "suggestions": [ { "id": 12, "name": "…", "price": 89, "image_url": "https://…" } ],
  "suggested_next_searches": ["brushed matte stainless steel cutlery flatware dinnerware"]
}
```

---

## AI (Smart Cart)

### POST /ai/cart-coach
**What it does**: Scores a cart and gives insights

### POST /ai/occasion-detect
**What it does**: Detects likely occasion from cart contents

### GET /ai/resurface?device_id=...
**What it does**: Re-engagement prompts for saved-for-later items (cross-referenced with trending)

---

## AI (Personalization)

### POST /ai/style-detect
**What it does**: Builds a style persona for a device based on browsing + searches

### GET /ai/style-profile?device_id=...
**What it does**: Fetches cached style profile; auto-refreshes if older than 24h

---

## AI (Content Generation)

### POST /ai/gift-message
**What it does**: Generates 3 contribution message options

### POST /ai/thank-you-note
**What it does**: Generates thank-you note options

### POST /ai/product-story
**What it does**: Generates a 2-sentence lifestyle story for a product

---

## AI (Compare & Bundles)

### POST /ai/compare-products
**What it does**: Gemini comparison across 2–3 products

### POST /ai/bundle-build
**What it does**: Builds a themed bundle within a budget and returns real products

---

## AI (Chat)

### POST /ai/chat-session
**What it does**: Stateful shopping assistant (stores conversation in Supabase)

### GET /ai/chat-history?device_id=...&session_id=...
**What it does**: Loads recent chat history

### DELETE /ai/chat-history
**What it does**: Deletes chat history for a session

---

## AI Registry (mounted at /ai/registry)

### POST /ai/registry/suggest
**What it does**: AI-powered registry category suggestions + example real products

**Request**
```json
{ "event_type": "Wedding", "budget": 2000, "existing_categories": ["Cookware"] }
```

**Response**
```json
{
  "event_type": "Wedding",
  "suggestions": [ { "category": "Serveware", "reason": "...", "budget_pct": 15, "priority": "essential" } ],
  "products_by_category": { "Serveware": [ { "id": 12, "name": "...", "price": 89, "image_url": "..." } ] }
}
```

**iOS integration**: Call from `RegistryService.swift` when user picks event type

### POST /ai/registry/budget-plan
**What it does**: Allocates a total registry budget across categories

### POST /ai/registry/completeness
**What it does**: Scores registry completeness and suggests what to add next

### POST /ai/registry/theme
**What it does**: Suggests themes + palettes for the registry

### POST /ai/registry/timeline
**What it does**: Action plan by phase based on days until the event

### GET /ai/registry/gift-picker?registry_id=...&budget=...
**What it does**: Picks the 3 best gift options for a giver’s budget

### POST /ai/registry/trending-occasion
**What it does**: Trend insights for an event type based on recent registry activity

---

# Local Testing (curl)

Start server:
```bash
cd Backend
npm install
npm start
```

Optional: seed demo data:
```bash
node scripts/seed_demo_data.js
```

## Smoke tests (script)
```bash
bash scripts/test_all_endpoints.sh
```

## Manual curls (new endpoints)

```bash
# Health
curl http://localhost:3000/health

# Registry dashboard (replace REGISTRY_ID)
curl http://localhost:3000/registry/REGISTRY_ID/dashboard

# Update registry budget
curl -X POST http://localhost:3000/registry/REGISTRY_ID/budget \
  -H "Content-Type: application/json" \
  -d '{"budget":3000}'

# Contribute to a registry item (replace REGISTRY_ITEM_ID)
curl -X POST http://localhost:3000/registry/REGISTRY_ID/contribute \
  -H "Content-Type: application/json" \
  -d '{"registry_item_id":"REGISTRY_ITEM_ID","contributor_name":"Taylor","amount":50,"message":"So happy for you!"}'

# Add collaborator
curl -X POST http://localhost:3000/registry/REGISTRY_ID/collaborators \
  -H "Content-Type: application/json" \
  -d '{"email":"partner@example.com","role":"editor"}'

# Share link + public view
curl http://localhost:3000/registry/REGISTRY_ID/share-link
curl http://localhost:3000/registry/public/SHARE_TOKEN

# Cart save for later
curl -X POST http://localhost:3000/cart/save-for-later \
  -H "Content-Type: application/json" \
  -d '{"device_id":"demo-device-001","product_id":12}'

# Saved list
curl http://localhost:3000/cart/saved/demo-device-001

# Move saved item to registry
curl -X POST http://localhost:3000/cart/move-to-registry \
  -H "Content-Type: application/json" \
  -d '{"device_id":"demo-device-001","product_id":12,"registry_id":"REGISTRY_ID","quantity_requested":1,"ai_reason":"Completes the set"}'

# AI registry suggest
curl -X POST http://localhost:3000/ai/registry/suggest \
  -H "Content-Type: application/json" \
  -d '{"event_type":"Wedding","budget":2000,"existing_categories":["Cookware"]}'

# AI budget plan
curl -X POST http://localhost:3000/ai/registry/budget-plan \
  -H "Content-Type: application/json" \
  -d '{"event_type":"Wedding","total_budget":2000}'

# AI completeness
curl -X POST http://localhost:3000/ai/registry/completeness \
  -H "Content-Type: application/json" \
  -d '{"registry_id":"REGISTRY_ID","event_type":"Wedding"}'

# AI theme
curl -X POST http://localhost:3000/ai/registry/theme \
  -H "Content-Type: application/json" \
  -d '{"event_type":"Wedding","style_hints":"minimalist, coastal"}'

# AI timeline
curl -X POST http://localhost:3000/ai/registry/timeline \
  -H "Content-Type: application/json" \
  -d '{"event_type":"Wedding","event_date":"2030-01-01","registry_id":"REGISTRY_ID"}'

# AI gift picker
curl "http://localhost:3000/ai/registry/gift-picker?registry_id=REGISTRY_ID&budget=100"

# AI trending occasion
curl -X POST http://localhost:3000/ai/registry/trending-occasion \
  -H "Content-Type: application/json" \
  -d '{"event_type":"Wedding"}'

# AI cart coach
curl -X POST http://localhost:3000/ai/cart-coach \
  -H "Content-Type: application/json" \
  -d '{"cart_items":[{"product_name":"Cast Iron Skillet","category":"Cookware","price":89,"quantity":1}]}'

# AI occasion detect
curl -X POST http://localhost:3000/ai/occasion-detect \
  -H "Content-Type: application/json" \
  -d '{"cart_items":[{"name":"Skillet","category":"Cookware","tags":["cast iron"]}]}'

# AI resurface
curl "http://localhost:3000/ai/resurface?device_id=demo-device-001"

# AI style detect + profile
curl -X POST http://localhost:3000/ai/style-detect \
  -H "Content-Type: application/json" \
  -d '{"device_id":"demo-device-001"}'
curl "http://localhost:3000/ai/style-profile?device_id=demo-device-001"

# AI gift message
curl -X POST http://localhost:3000/ai/gift-message \
  -H "Content-Type: application/json" \
  -d '{"contributor_name":"Taylor","recipient_name":"Jordan","event_type":"Wedding","product_name":"Skillet","amount":50}'

# AI thank-you note
curl -X POST http://localhost:3000/ai/thank-you-note \
  -H "Content-Type: application/json" \
  -d '{"registry_owner_name":"Jordan","contributor_name":"Taylor","product_name":"Skillet","event_type":"Wedding"}'

# AI product story
curl -X POST http://localhost:3000/ai/product-story \
  -H "Content-Type: application/json" \
  -d '{"product_id":12}'

# AI compare products
curl -X POST http://localhost:3000/ai/compare-products \
  -H "Content-Type: application/json" \
  -d '{"product_ids":[12,13]}'

# AI bundle build
curl -X POST http://localhost:3000/ai/bundle-build \
  -H "Content-Type: application/json" \
  -d '{"theme":"starter kitchen","budget":250}'

# AI chat session + history
curl -X POST http://localhost:3000/ai/chat-session \
  -H "Content-Type: application/json" \
  -d '{"device_id":"demo-device-001","session_id":"demo-session-001","message":"Help me build a registry under $200"}'
curl "http://localhost:3000/ai/chat-history?device_id=demo-device-001&session_id=demo-session-001"
curl -X DELETE http://localhost:3000/ai/chat-history \
  -H "Content-Type: application/json" \
  -d '{"device_id":"demo-device-001","session_id":"demo-session-001"}'

# AI smart search + price insight
curl -X POST http://localhost:3000/ai/smart-search \
  -H "Content-Type: application/json" \
  -d '{"query":"cast iron","device_id":"demo-device-001"}'
curl -X POST http://localhost:3000/ai/price-insight \
  -H "Content-Type: application/json" \
  -d '{"product_id":12}'

# AI aesthetic suggestions (kitchen photo -> matching cutlery/tabletop)
curl -X POST http://localhost:3000/ai/aesthetic-suggest \
  -H "Content-Type: application/json" \
  -d '{"image_url":"https://example.com/kitchen.jpg","budget":200,"room_type":"kitchen","desired_items":["cutlery","dinnerware"]}'

# AI aesthetic matching (NO Gemini) — iOS sends extracted palette/keywords
curl -X POST http://localhost:3000/ai/aesthetic-match \
  -H "Content-Type: application/json" \
  -d '{"palette_hex":["#111827","#F5F0E8","#C8B8A6"],"materials":["stainless steel","ceramic"],"finish_keywords":["matte","brushed"],"mood_keywords":["minimal","warm"],"categories":["Dinnerware","Kitchen Tools"],"desired_items":["cutlery","dinnerware"],"budget":200}'
```
