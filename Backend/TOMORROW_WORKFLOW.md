<!-- ========== FILE: TOMORROW_WORKFLOW.md ========== -->

# Backend Changes + Tomorrow Workflow (Williams Sonoma AI Hackathon)

Date: 2026-05-17

This doc is the single source of truth for:
1) What was added/changed in the backend (end-to-end flows)
2) What integrations are still left for tomorrow (iOS + deploy + DB)
3) How to run + validate locally end-to-end

---

## 1) What Was Added / Changed (Summary)

### Database migrations
- `migrations/new_features_schema.sql`
  - New tables: `registry_contributions`, `registry_collaborators`, `save_for_later`, `user_style_profiles`, `ai_conversation_history`
  - New columns:
    - `registries`: `budget`, `share_token`, `theme`
    - `registry_items`: `price_snapshot`, `ai_reason`
  - RLS enabled on new tables + permissive policies (hackathon-safe)

- `migrations/v3_ambitious_features.sql`
  - New tables: `style_quiz_results`, `occasion_plans`, `product_qa_cache`, `notification_log`, `cart_intent_events`, `curated_collections`
  - New columns:
    - `user_style_profiles`: quiz-related fields
    - `recent_searches`: `parsed_intent`, `result_count`
    - `registry_contributions`: `is_anonymous`, `email`
  - RLS enabled + permissive policies

### API + routes
- Registry upgrades: `routes/registry.js`
  - Added: budget, dashboard aggregation, contributions, collaborators, share link, public view
  - Extended: `POST /registry/:id/items` now snapshots price + accepts `ai_reason`

- Cart upgrades: `routes/cart.js`
  - Added: save-for-later endpoints + move-to-registry
  - Route order fixed so `/:userId` doesn’t shadow `/saved/:deviceId` etc.

- AI upgrades:
  - Registry AI split into `routes/ai_registry.js` mounted at `/ai/registry`
  - Main AI in `routes/ai.js` expanded to cover:
    - search UX endpoints, visual search, cart coach, occasion detect, resurface, style detect/profile, content gen, compare, bundle build, chat session/history, smart search, price insights
  - Added aesthetic matching:
    - `POST /ai/aesthetic-suggest` (Gemini vision; now optional)
    - `POST /ai/aesthetic-match` (NO Gemini; client sends extracted palette/keywords)

### Infra / deploy
- `server.js` now mounts `/ai/registry` and adds `GET /health`
- `render.yaml` added for Render one-click deploy
- `.env.example` added

### Demo + testing
- `scripts/seed_demo_data.js` seeds realistic demo content in Supabase
- `scripts/test_all_endpoints.sh` bash smoke tests (Git Bash/WSL)

---

## 2) End-to-End User Flows (How the App Should Work)

### Flow A — Create Registry (AI-first onboarding)
1) iOS creates registry:
   - `POST /registry`
2) iOS immediately calls registry AI:
   - `POST /ai/registry/suggest` → show 8 recommended categories + real products per category
   - `POST /ai/registry/theme` → show 3 theme cards (palette + vibe)
   - `POST /ai/registry/budget-plan` (if user set a budget) → show allocations
3) When user adds a product:
   - `POST /registry/:id/items` with `ai_reason` optional
   - backend snapshots `price_snapshot` automatically

### Flow B — Registry Dashboard (single request screen)
1) iOS loads dashboard:
   - `GET /registry/:id/dashboard`
2) Screen shows:
   - event details + budget stats + completion + days_until_event
   - list of items (joined products, image URLs fixed)
   - group gifting status (total contributed + funded boolean)
3) Optional “AI health” widget:
   - `POST /ai/registry/completeness` with `registry_id` + `event_type`

### Flow C — Group gifting (contribution)
1) Guest/user contributes:
   - `POST /registry/:id/contribute`
2) UI updates progress bar on the item.
3) Optional delight:
   - `POST /ai/gift-message` to generate message options.

### Flow D — Collaborators (co-planning)
1) Add collaborator:
   - `POST /registry/:id/collaborators` (idempotent)
2) List collaborators:
   - `GET /registry/:id/collaborators`

### Flow E — Sharing (guest view)
1) Owner gets share link:
   - `GET /registry/:id/share-link`
2) Guest opens:
   - `GET /registry/public/:shareToken` (same dashboard format; read-only UI)

### Flow F — Save for later → move to registry
1) Save:
   - `POST /cart/save-for-later` (device-scoped)
2) List:
   - `GET /cart/saved/:deviceId`
3) Move into registry:
   - `POST /cart/move-to-registry` (snapshots price + removes saved entry)

### Flow G — Aesthetic-based suggestions (kitchen photo → matching cutlery)
Two modes:

**Mode 1 (tomorrow): No Gemini, on-device extraction**
1) iOS extracts palette + keywords (VisionKit/CoreImage).
2) iOS calls:
   - `POST /ai/aesthetic-match`
3) Backend returns:
   - `suggestions` products + `suggested_next_searches` chips

**Mode 2 (optional): Gemini vision**
1) iOS calls:
   - `POST /ai/aesthetic-suggest`
2) Backend returns style profile + matching suggestions
Note: This now requires `GEMINI_API_KEY` and can be disabled.

---

## 3) Tomorrow — Integrations Still Left (Checklist)

### A) Database / Supabase
- Run migrations in Supabase SQL editor:
  - `migrations/new_features_schema.sql`
  - `migrations/v3_ambitious_features.sql`
- Confirm `products.tags` is `text[]` (used by overlap filters).
- Confirm `recent_searches` exists and can be altered (adds `parsed_intent`, `result_count` in v3).
- Ensure Supabase RPC `hybrid_search` exists if you want embedding+vector behavior.
  - If it doesn’t, the search pipeline still falls back to Postgres `ILIKE`.

### B) iOS integrations
- RegistryService.swift
  - wire `/registry/:id/dashboard` as the main screen request
  - wire `/registry/:id/contribute` for group gifting
  - wire collaborators + share link + public view
- CartService.swift
  - wire save-for-later list and move-to-registry
- Aesthetic matching (NO Gemini) — build tomorrow:
  - implement palette extraction on-device
  - call `POST /ai/aesthetic-match` with `{ palette_hex, materials, finish_keywords, mood_keywords, categories, desired_items, budget }`

### C) Deploy (Render)
- Push repo to GitHub and connect Render to the `Backend` service root (or set Render root to `Backend`).
- Ensure Render env vars are set:
  - `SUPABASE_URL`
  - `SUPABASE_SERVICE_ROLE_KEY`
  - `GEMINI_API_KEY` (optional; only needed for Gemini endpoints)
- Health check is `GET /health`

### D) Local tooling
- Install Node LTS with npm (this Codex environment has Node but not npm).
- Run:
  - `npm install`
  - `npm start`

---

## 4) Local End-to-End Validation (Do This Before Demo)

From `Backend/`:
0) Create `D:\\Williams\\Ecommerce-IOS\\Backend\\.env`:
   - copy `.env.example` → `.env`
   - fill `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`
   - (optional) `GEMINI_API_KEY` if you want Gemini-powered endpoints enabled
1) Run both migrations in Supabase.
2) Install and start:
   - `npm install`
   - `npm start`
3) Seed demo:
   - `node scripts/seed_demo_data.js`
4) Run smoke tests:
   - `bash scripts/test_all_endpoints.sh`
   - or the Node-based script (recommended on Windows): `node scripts/test_all_endpoints_node.js`

If anything fails, check:
- Supabase keys and URL
- Missing tables/columns (migrations not run)
- `hybrid_search` RPC missing (search will still work via fallback)
