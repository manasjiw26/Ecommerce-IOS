# iOS Ecommerce App

Hearth & Table is a full-stack iOS ecommerce app for home, kitchen, gift, and registry shopping. It includes product browsing, authentication, cart, checkout, orders, AI search, visual search, chat assistance, and registry features.

## Tech Stack

| Part | Technology |
| --- | --- |
| iOS App | Swift, SwiftUI, Combine, async/await |
| Architecture | MVVM |
| Backend | Node.js, Express.js |
| Database | Supabase PostgreSQL |
| Authentication | Supabase Auth |
| Payments | Razorpay |
| AI Features | Gemini, Groq, Ollama Cloud fallback |
| Search | Semantic search, autocomplete, fuzzy search, recent/trending searches |
| Visual Search | Apple Vision, CLIP image similarity |
| Hosting | Render or any Node.js hosting provider |

## Project Structure

```text
Backend/
  routes/
  services/search/
  migrations/
  scripts/
  server.js
  package.json
  render.yaml

IOS/Ecommerce/
  Ecommerce/
    Views/
    ViewModels/
    Services/
    Models/
    Components/
    Config.swift
```

## Frontend Features

- SwiftUI iOS app using MVVM.
- User signup and login.
- Product catalog and product detail pages.
- Cart with local persistence and backend sync.
- Razorpay checkout using `WKWebView`.
- Order history.
- Search with filters and autocomplete.
- AI recommendation carousel.
- Visual search using camera or photo library.
- AI shopping chat.
- Registry creation and registry item management.
- Profile and logout support.
- Cached image loading.

## Backend Features

- Express REST API.
- Supabase Auth integration.
- Supabase PostgreSQL database access.
- Product, cart, order, payment, auth, registry, AI, and chat routes.
- Razorpay order creation and payment verification.
- AI search and recommendation endpoints.
- Visual search endpoint.
- Chat endpoint with Groq, Ollama Cloud, and Gemini fallback.
- Registry endpoints for items, dashboard, contributions, collaborators, and sharing.
- SQL migrations for search analytics, registry, chatbot, promotions, returns, reviews, watchlist, and advanced AI features.

## Main API Groups

| Feature | Routes |
| --- | --- |
| Health | `/`, `/health` |
| Products | `/products` |
| Auth | `/auth` |
| Cart | `/cart` |
| Orders | `/orders` |
| Payments | `/payment` |
| Search and AI | `/ai` |
| Chat | `/chat` |
| Registry | `/registry`, `/ai/registry` |

## Environment Variables

The backend uses a local `.env` file. This file should not be uploaded to GitHub.

Example `Backend/.env`:

```env
PORT=3000
NODE_ENV=development

SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your_supabase_anon_key
SUPABASE_SERVICE_ROLE_KEY=your_supabase_service_role_key

RAZORPAY_KEY_ID=rzp_test_your_key_id
RAZORPAY_KEY_SECRET=your_razorpay_key_secret

GEMINI_API_KEY=your_gemini_api_key
GEMINI_MODEL=gemini-2.0-flash
GEMINI_CHAT_MODEL=gemini-2.0-flash

GROQ_API_KEY=your_groq_api_key
OLLAMA_CLOUD_URL=https://your-ollama-cloud-url/api/chat
OLLAMA_CLOUD_AUTH=optional_auth_value

REDIS_URL=redis://localhost:6379
```

Private values such as Supabase service role key, Razorpay secret, Gemini key, Groq key, and Ollama auth token should only be stored in `.env` locally or in the hosting provider’s environment variable dashboard.

## Required Backend Config

Minimum required variables:

```env
SUPABASE_URL=
SUPABASE_SERVICE_ROLE_KEY=
RAZORPAY_KEY_ID=
RAZORPAY_KEY_SECRET=
```

Optional AI variables:

```env
GEMINI_API_KEY=
GROQ_API_KEY=
OLLAMA_CLOUD_URL=
OLLAMA_CLOUD_AUTH=
REDIS_URL=
```

## iOS Config

The iOS app reads backend and payment config from:

```text
IOS/Ecommerce/Ecommerce/Config.swift
```

Example:

```swift
import Foundation

struct Config {
    static let razorpayKey = "rzp_test_your_key_id"

    #if DEBUG
    static let apiBaseURL = "http://127.0.0.1:3000"
    #else
    static let apiBaseURL = "https://your-hosted-backend-url.com"
    #endif
}
```

For simulator testing, `127.0.0.1` can be used.

For real iPhone testing, use the Mac’s local Wi-Fi IP:

```swift
static let apiBaseURL = "http://192.168.1.11:3000"
```

## Local Backend Setup

```bash
cd Backend
npm install
npm start
```

Local backend URL:

```text
http://127.0.0.1:3000
```

Health check:

```text
http://127.0.0.1:3000/health
```

## Local iOS Setup

Open the Xcode project:

```text
IOS/Ecommerce/Ecommerce.xcodeproj
```

The app can be run on an iPhone simulator or a connected iPhone from Xcode.

## Real iPhone Local Testing

For real iPhone testing with a backend running on Mac:

```text
Mac and iPhone must be on the same Wi-Fi.
Backend should run on the Mac.
Config.swift should use the Mac Wi-Fi IP instead of 127.0.0.1.
```

Mac IP command:

```bash
ipconfig getifaddr en0
```

Example iPhone API URL:

```swift
static let apiBaseURL = "http://192.168.1.11:3000"
```

## Supabase Database

The backend depends on Supabase tables for products, users, cart, orders, events, registry, search, chat, and AI features.

Migration files are stored in:

```text
Backend/migrations/
```

Important migration files:

```text
search_analytics.sql
registry_schema.sql
new_features_schema.sql
chatbot_schema.sql
v3_ambitious_features.sql
```

## Hosting

The backend can be hosted on Render or any Node.js hosting service.

Render config is included:

```text
Backend/render.yaml
```

Production environment variables should be added in the hosting dashboard instead of uploading `.env`.

For production iOS builds, update `Config.swift` with the hosted backend URL:

```swift
static let apiBaseURL = "https://your-hosted-backend-url.com"
```

## Security Notes

- `.env` should not be committed to GitHub.
- `SUPABASE_SERVICE_ROLE_KEY` must never be exposed in the iOS app.
- Razorpay secret must stay on the backend only.
- API keys for Gemini, Groq, and Ollama should stay in backend environment variables.
- `Config.swift` should only contain public client-side values such as backend URL and Razorpay public key ID.
