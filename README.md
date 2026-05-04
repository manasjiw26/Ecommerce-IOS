# Hearth & Table — iOS eCommerce App

> A full-stack iOS eCommerce application built with SwiftUI and a custom Node.js REST API backend, backed by Supabase (PostgreSQL).

---

## 📱 Demo

> _Add a screen recording GIF or YouTube link here before your interview_

---

## ✨ Features

- 🛍️ **Product Catalog** — Browse products with live search and category filters
- 🧠 **Recommendation Engine** — Personalized "Recommended for You" section based on browsing history (tracked via `UserDefaults`)
- 🛒 **Persistent Cart** — Cart state survives app restarts using `UserDefaults` + `Codable`
- 💳 **Razorpay Checkout** — Real payment gateway integration via `WKWebView` with USD→INR conversion
- 📦 **Order History** — Orders saved locally after successful payment with animated progress timeline (Processing → Shipped → Delivered)
- 👤 **Profile** — User profile sheet with logout functionality
- 🌗 **Dark Mode** — Full light and dark mode support
- ⚡ **Image Caching** — `CachedImageView` for smooth, lag-free image loading

---

## 🏗️ Architecture

```
┌─────────────────────┐     REST API      ┌──────────────────────┐
│   SwiftUI Frontend  │ ◄──────────────► │  Node.js/Express API  │
│   (MVVM Pattern)    │                   │  (Railway Deployed)   │
└─────────────────────┘                   └──────────┬───────────┘
                                                      │
                                                      ▼
                                          ┌──────────────────────┐
                                          │  Supabase (PostgreSQL)│
                                          │  + Storage (Images)  │
                                          └──────────────────────┘
```

### iOS Project Structure (MVVM)
```
Ecommerce/
├── Models/          # Codable Swift structs (Product, CartItem, etc.)
├── ViewModels/      # @Published ObservableObjects (CartManager, OrderManager)
├── Views/           # SwiftUI screens
├── Services/        # APIService, RecommendationEngine
└── Components/      # Reusable views (CachedImageView, etc.)
```

---

## 🔌 API Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| `GET` | `/products` | Fetch all products |
| `GET` | `/products/:id` | Get single product |
| `GET` | `/products?category=X` | Filter by category |
| `GET` | `/orders/:userId` | Get user's order history |
| `POST` | `/orders` | Place a new order |
| `POST` | `/cart` | Add item to cart |
| `POST` | `/payment/create-order` | Create Razorpay payment order |
| `POST` | `/payment/verify` | Verify payment signature |

---

## 🛠️ Tech Stack

| Layer | Technology |
|-------|------------|
| **Frontend** | Swift, SwiftUI, UIKit, WKWebView |
| **Architecture** | MVVM, Combine, async/await |
| **Backend** | Node.js, Express.js |
| **Database** | Supabase (PostgreSQL) |
| **Storage** | Supabase Storage (product images) |
| **Payments** | Razorpay Standard Checkout |
| **Deployment** | Railway |
| **Networking** | URLSession, async/await |

---

## 🚀 Getting Started

### Backend Setup

```bash
git clone https://github.com/manasjiw26/ws-ecommerce-ios
cd Backend
npm install
```

Create a `.env` file:
```env
SUPABASE_URL=your_supabase_url
SUPABASE_ANON_KEY=your_supabase_anon_key
PORT=3000
RAZORPAY_KEY_ID=rzp_test_xxxx
RAZORPAY_KEY_SECRET=your_secret
```

```bash
node server.js
```

Backend runs at `http://localhost:3000`. Live deployment: `https://ws-store.up.railway.app`

### iOS Setup

1. Open `IOS/Ecommerce/Ecommerce.xcodeproj` in Xcode
2. Open `Config.swift` and add your Razorpay Test Key ID
3. Select a simulator (iPhone 15 recommended)
4. Press `⌘ + R` to build and run

---

## 📁 Key Files

| File | Purpose |
|------|---------|
| `CartManager.swift` | Cart state + UserDefaults persistence |
| `OrderManager.swift` | Order history + UserDefaults persistence |
| `RecommendationEngine.swift` | Category-based recommendation tracking |
| `RazorpayCheckoutView.swift` | Real Razorpay checkout via WKWebView |
| `CachedImageView.swift` | NSCache-based async image caching |
| `APIService.swift` | Centralized URLSession networking layer |

---

## 👨‍💻 Author

**Manas Jiwnani**  
MIT WPU, Pune | B.Tech CSE  
[github.com/manasjiw26](https://github.com/manasjiw26)
