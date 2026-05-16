<!-- ========== FILE: UI_EXPECTATIONS.md ========== -->

# iOS UI Expectations (Hackathon Demo)

This backend is designed for a **Williams Sonoma AI Hackathon** demo. The iOS UI should make AI feel **everywhere**: proactive, personalized, and “smart” on every screen.

## 1) Smart Registry (primary demo flow)

### Create Registry (Event Setup)
- Inputs: `event_type`, `event_date`, optional `budget`, optional `style_hints`.
- After the user picks an event type, immediately call:
  - `POST /ai/registry/suggest` to show **8 category tiles** (essential/recommended/nice-to-have) with “why it matters”.
  - `POST /ai/registry/theme` to show **3 theme cards** (palette + vibe).
  - `POST /ai/registry/budget-plan` (if budget known) to show a **category allocation breakdown**.

### Registry Dashboard (main screen)
Use `GET /registry/:id/dashboard` as the single source of truth:
- Top: event info + `budget_total`, `budget_used`, `budget_remaining`, `completion_pct`, `days_until_event`.
- Middle: “AI Registry Health” widget:
  - call `POST /ai/registry/completeness` and show score + missing categories + “next 3 to add”.
- Items list:
  - display each item’s `ai_reason` (if present) as a subtle “AI suggested: …”
  - show **group gifting progress** using `total_contributed` vs target.
  - show “Most wanted” badge using `is_most_wanted`.

### Group Gifting (critical “wow” moment)
- On an item, show a “Contribute” CTA.
- Contribution modal fields: `contributor_name`, `amount`, optional `message`.
- Call `POST /registry/:id/contribute` and update the item’s progress bar.
- Optional delight: after a contribution, generate a message preview via `POST /ai/gift-message`.

### Collaborators (co-planning)
- Add collaborator: email + role selector.
- Call `POST /registry/:id/collaborators` (idempotent).
- List: `GET /registry/:id/collaborators`.

### Sharing (guest view)
- Show share link using `GET /registry/:id/share-link`.
- Guest registry screen uses `GET /registry/public/:shareToken` and renders the same dashboard layout (read-only UX).

## 2) Smart Cart + Save For Later

### Save for later
- “Save for later” button on product detail and cart.
- `POST /cart/save-for-later` and show a “Saved” toast.
- Saved list screen calls `GET /cart/saved/:deviceId`.
- Move to registry from saved list:
  - `POST /cart/move-to-registry` (then remove from list visually).

### Cart AI coach
- On cart screen, call `POST /ai/cart-coach` and show:
  - score + headline
  - 3 insights list with icons by type (`missing`, `bundle`, `value`)
  - “Top suggestion” CTA that pre-fills a search query.

### Occasion detection (delight)
- Call `POST /ai/occasion-detect` to show “Looks like you’re shopping for…” with suggested categories.

### Resurface (re-engagement)
- Use `GET /ai/resurface?device_id=...` on app open / home screen:
  - show up to 3 “Saved but trending” cards with urgency wording.

## 3) Conversational Shopping Assistant (stateful)
- Entry points:
  - floating “Ask AI” button (global)
  - registry dashboard “Ask about my registry”
  - product detail “Ask about this product”
- The chat UI calls `POST /ai/chat-session` and renders:
  - `reply`
  - optional “quick actions” from `actions` (search/add_to_registry style)
  - follow-up question chips from `follow_up_questions`
- History screen calls `GET /ai/chat-history`.

## 4) Personalization (per device)
- On home screen, call `GET /ai/style-profile?device_id=...`:
  - show persona name + tagline
  - use `top_categories` to populate “For you” carousels (by filtering `/products?category=...`)

## Tomorrow Build Requirement: On-device Aesthetic Matching (No Gemini)

Gemini keys expire quickly, so the long-term plan is **on-device aesthetic extraction** in iOS and server-side matching without any vision AI dependency.

### iOS (tomorrow)
- Use VisionKit / CoreImage to extract:
  - dominant palette (`palette_hex`: 3–6 hex colors)
  - inferred materials/finishes (simple classifier or rules): `materials`, `finish_keywords`
  - vibe keywords: `mood_keywords` (e.g. “coastal”, “minimal”, “warm”)
  - desired shopping targets: `desired_items` (e.g. `["cutlery","dinnerware"]`)
- Then call backend:
  - `POST /ai/aesthetic-match` with the extracted profile

### Backend (already supports this)
- Matches against products via:
  - search queries built from the profile (via existing `/ai/search` pipeline)
  - category/tag fallback
- Returns `suggestions` with fixed image URLs for immediate UI rendering.
