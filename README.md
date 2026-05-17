# ShopEase iOS Ecommerce App

ShopEase is a full-stack iOS ecommerce app for home, kitchen, gift, and registry shopping. It includes product browsing, authentication, cart, checkout, orders, AI search, visual search, chat assistance, and registry features.

## Tech Stack

| Part | Technology |
| --- | --- |
| iOS App | Swift, SwiftUI |
| Architecture | MVVM |
| Backend | Node.js, Express.js |
| Database | Supabase PostgreSQL |
| Authentication | Supabase Auth |
| Payments | Razorpay |
| AI Features | Gemini, Groq, Ollama Cloud fallback |
| Search | Semantic search, autocomplete, fuzzy search, recent/trending searches |
| Visual Search | Apple Vision, CLIP image similarity |
| Media Storage | Cloudinary |
| Hosting | Render |

## Live Backend

The backend is already hosted and running at:

```
https://ecommerce-ios.onrender.com
```

Health check:

```
https://ecommerce-ios.onrender.com/health
```

> **Note:** The backend is hosted on Render's free tier. The first request after a period of inactivity may take 30–60 seconds while the server wakes up. Subsequent requests are fast. If the live backend is unresponsive, you can run it locally — see [Running the Backend Locally](#running-the-backend-locally-optional) below.

## Running the iOS App

No backend setup is needed. The backend is already live.

**Steps:**

1. Open the Xcode project:

```text
IOS/Ecommerce/Ecommerce.xcodeproj
```

2. Make sure `Config.swift` points to the hosted backend:

```swift
import Foundation

struct Config {
    static let apiBaseURL = "https://ecommerce-ios.onrender.com"
}
```

3. Select a simulator or connected iPhone in Xcode and press **Run**.

That's it — the app will connect to the live backend automatically.

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

## Running the Backend Locally (Optional)

If the live backend is down or you want to run it locally for development:

1. Create `Backend/.env` based on the example below.
2. Run:

```bash
cd Backend
npm install
npm start
```

3. Update `Config.swift` to point to your local backend:

```swift
static let apiBaseURL = "http://127.0.0.1:3000"
```

For testing on a real iPhone with a local backend, use your Mac's Wi-Fi IP instead:

```swift
static let apiBaseURL = "http://192.168.1.x:3000"
```

Find your Mac's IP:

```bash
ipconfig getifaddr en0
```

### Backend Environment Variables

```env
PORT=3000
NODE_ENV=development

SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your_supabase_anon_key
SUPABASE_SERVICE_ROLE_KEY=your_supabase_service_role_key

GEMINI_API_KEY=your_gemini_api_key
GEMINI_MODEL=gemini-2.0-flash
GEMINI_CHAT_MODEL=gemini-2.0-flash

GROQ_API_KEY=your_groq_api_key
OLLAMA_CLOUD_URL=https://your-ollama-cloud-url/api/chat
OLLAMA_CLOUD_AUTH=optional_auth_value

REDIS_URL=redis://localhost:6379
```

> Razorpay keys (`RAZORPAY_KEY_ID`, `RAZORPAY_KEY_SECRET`) are already configured in the hosted environment and do not need to be added manually.

## Supabase Database

Migration files are in:

```text
Backend/migrations/
```

Key migration files:

```text
search_analytics.sql
registry_schema.sql
new_features_schema.sql
chatbot_schema.sql
v3_ambitious_features.sql
```

## Security Notes

- `.env` should not be committed to GitHub.
- `SUPABASE_SERVICE_ROLE_KEY` must never be exposed in the iOS app.
- Razorpay secret must stay on the backend only.
- API keys for Gemini, Groq, and Ollama should stay in backend environment variables.
- `Config.swift` should only contain public client-side values such as the backend URL and Razorpay public key ID.
