import Foundation

struct Config {
    // Paste your Razorpay Test Key here
    static let razorpayKey = "rzp_test_Sl0hrrQoUTyluF"
    
    // Simulator: 127.0.0.1 works.
    // Real device: change this to your Mac's LAN IP (e.g. http://192.168.1.11:3000).
    static let apiBaseURL = "https://ecommerce-ios.onrender.com"

    // Legacy placeholder from an older branch; kept commented so nothing is lost.
    // static let geminiAPIKey = "YOUR_GEMINI_API_KEY_HERE"
}
