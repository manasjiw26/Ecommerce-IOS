<!-- ========== FILE: CHANGES_MADE.md ========== -->

# What Was Added / Changed (Backend)

This document summarizes what was implemented for the **Williams Sonoma AI Hackathon** backend features.

## Database (Supabase)

Added `Backend/migrations/new_features_schema.sql`:
- New tables: `registry_contributions`, `registry_collaborators`, `save_for_later`, `user_style_profiles`, `ai_conversation_history`
- New columns:
  - `registries`: `budget`, `share_token`, `theme`
  - `registry_items`: `price_snapshot`, `ai_reason`
- RLS enabled on new tables + permissive policies (`USING (true)` / `WITH CHECK (true)`).

## Registry API

Updated `Backend/routes/registry.js`:
- Added:
  - `POST /registry/:id/budget`
  - `GET /registry/:id/dashboard` (aggregates registry + items + contributions + computed stats)
  - `POST /registry/:id/contribute`
  - `GET /registry/:id/contributions`
  - `POST /registry/:id/collaborators`
  - `GET /registry/:id/collaborators`
  - `GET /registry/:id/share-link`
  - `GET /registry/public/:shareToken`
- Extended:
  - `POST /registry/:id/items` now stores `price_snapshot` (from `products.price`) and optional `ai_reason`.
- Standardized: try/catch + JSON error shape `{ error, code }` and image URL fixing in returned products.

## Cart API

Updated `Backend/routes/cart.js`:
- Added:
  - `POST /cart/save-for-later`
  - `DELETE /cart/save-for-later`
  - `GET /cart/saved/:deviceId`
  - `POST /cart/move-to-registry`
- Kept existing cart endpoints intact; reordered routes so static paths don’t get shadowed by `/:userId` and `/:itemId`.

## AI APIs

Added `Backend/routes/ai_registry.js` and mounted under `/ai/registry`:
- `POST /ai/registry/suggest`
- `POST /ai/registry/budget-plan`
- `POST /ai/registry/completeness`
- `POST /ai/registry/theme`
- `POST /ai/registry/timeline`
- `GET /ai/registry/gift-picker`
- `POST /ai/registry/trending-occasion`

Updated `Backend/routes/ai.js`:
- Kept and strengthened existing endpoints: `/ai/search`, `/ai/recommend`, `/ai/events`
- Added “missing” AI endpoints mentioned in the spec:
  - Search UX: `GET /ai/autocomplete`, `POST /ai/search/analytics`, `GET /ai/trending-searches`, `GET /ai/recent-searches`
  - Visual: `POST /ai/visual-search`, `POST /ai/visual-search/feedback`
  - Smart cart: `POST /ai/cart-coach`, `POST /ai/occasion-detect`, `GET /ai/resurface`
  - Personalization: `POST /ai/style-detect`, `GET /ai/style-profile`
  - Content generation: `POST /ai/gift-message`, `POST /ai/thank-you-note`, `POST /ai/product-story`
  - Compare & discovery: `POST /ai/compare-products`, `POST /ai/bundle-build`
  - Chat: `POST /ai/chat-session`, `GET /ai/chat-history`, `DELETE /ai/chat-history`
  - Smart search: `POST /ai/smart-search`, `POST /ai/price-insight`

Added `Backend/searchOrchestrator.js`:
- Shared search pipeline used by `/ai/search` and `/ai/smart-search`.
- Uses local embeddings + Supabase `hybrid_search` RPC when available; falls back to Postgres ILIKE search.

## Server & Deploy

Updated `Backend/server.js`:
- Mounted `app.use('/ai/registry', require('./routes/ai_registry'));`
- Added `GET /health` endpoint for Render health checks

Added `Backend/render.yaml`:
- One-click Render deploy config (expects env vars to be set in Render dashboard)

Added `Backend/.env.example`:
- Local environment variable template

## Demo & Testing Scripts

Added `Backend/scripts/seed_demo_data.js`:
- Seeds a realistic demo registry, items, contributions, collaborator, cart, and save-for-later items.

Added `Backend/scripts/test_all_endpoints.sh`:
- Runs curl-based smoke tests for the new endpoints (auto-creates a test registry if `REGISTRY_ID` isn’t set).

