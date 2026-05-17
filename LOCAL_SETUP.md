# Running ShopEase Locally

This guide will walk you through cloning the ShopEase repository and running the entire full-stack application (Backend + iOS App) on your local machine.

---

## 1. Clone the Repository

First, clone the repository to your local machine:

```bash
git clone https://github.com/manasjiw26/Ecommerce-IOS.git
cd Ecommerce-IOS
```

---

## 2. Setting up the Backend

The backend is an Express.js server that connects to Supabase (PostgreSQL), Gemini (AI), and Cloudinary (Images).

### Install Dependencies

Navigate to the `Backend` directory and install the required Node.js packages:

```bash
cd Backend
npm install
```

### Environment Variables (.env)

You must create a `.env` file in the `Backend/` directory. You can copy the template provided in `.env.example`:

```bash
cp .env.example .env
```

Open the `.env` file and fill in your keys. It should look like this:

```env
# ========== FILE: .env ==========
PORT=3000
NODE_ENV=development

# Supabase Keys (Database & Auth)
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_SERVICE_ROLE_KEY=your_service_role_key

# AI Integration
GEMINI_API_KEY=your_gemini_api_key

# Payments
RAZORPAY_KEY_ID=your_razorpay_key_id
RAZORPAY_KEY_SECRET=your_razorpay_key_secret

# Image Storage (Optional, if using Cloudinary)
CLOUDINARY_URL=your_cloudinary_url
```

### Start the Server

Once your dependencies are installed and your `.env` is configured, start the backend server:

```bash
npm start
```
You should see:
> `Server running on port 3000`

---

## 3. Setting up the iOS App

With your backend running locally, you now need to point the iOS app to your local server instead of the live Render production server.

1. Open the Xcode project:
   ```bash
   open ../IOS/Ecommerce/Ecommerce.xcodeproj
   ```

2. Inside Xcode, open `Config.swift` (located at `IOS/Ecommerce/Ecommerce/Config.swift`).

3. Change the `apiBaseURL` to your localhost address:

   ```swift
   import Foundation
   
   struct Config {
       // Paste your Razorpay Test Key here
       static let razorpayKey = "rzp_test_Sl0hrrQoUTyluF"
       
       // Use your local backend URL:
       static let apiBaseURL = "http://127.0.0.1:3000"
   }
   ```

   > **Testing on a Physical iPhone?**
   > If you are running the app on a real iPhone instead of the iOS Simulator, `127.0.0.1` will not work because the phone will look for the server on itself. 
   > Instead, find your Mac's local Wi-Fi IP address (e.g., `192.168.1.11`) by running `ipconfig getifaddr en0` in your terminal.
   > Change `Config.swift` to: `static let apiBaseURL = "http://192.168.1.11:3000"`

4. Select an iPhone Simulator in Xcode and press **Run (Cmd + R)**.

---

## 4. Troubleshooting

* **App not fetching products:** Make sure your `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` are correct in your `.env` file and that your backend server is actively running.
* **Network Connection Lost:** If you get a connection timeout error on the iOS simulator, ensure `http://127.0.0.1:3000` is typed correctly and that there is no trailing slash.
* **AI features not working:** Ensure you have added a valid `GEMINI_API_KEY` to your `.env` file.
