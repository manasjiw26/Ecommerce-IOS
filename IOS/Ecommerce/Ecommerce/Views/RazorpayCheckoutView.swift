import SwiftUI
import WebKit

struct RazorpayCheckoutView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var cartManager: CartManager
    
    @State private var paymentStatus: String? = nil
    @State private var paymentId: String? = nil
    
    let razorpayTestKey = Config.razorpayKey
    
    var body: some View {
        NavigationView {
            VStack {
                if paymentStatus == "SUCCESS" {
                    VStack(spacing: 20) {
                        Image(systemName: "checkmark.circle.fill")
                            .resizable()
                            .frame(width: 80, height: 80)
                            .foregroundColor(.green)
                            .padding(.top, 40)
                        
                        Text("Payment Successful")
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Text("Transaction ID: \(paymentId ?? "")")
                            .foregroundColor(.gray)
                        
                        Spacer()
                        
                        Button(action: {
                            cartManager.removeAll()
                            presentationMode.wrappedValue.dismiss()
                        }) {
                            Text("Return to Shop")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.green)
                                .cornerRadius(10)
                        }
                        .padding()
                    }
                } else if paymentStatus == "FAILED" {
                    VStack(spacing: 20) {
                        Image(systemName: "xmark.circle.fill")
                            .resizable()
                            .frame(width: 80, height: 80)
                            .foregroundColor(.red)
                            .padding(.top, 40)
                        
                        Text("Payment Failed")
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Text("There was an error processing your payment.")
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        Spacer()
                        
                        Button("Try Again") {
                            paymentStatus = nil
                        }
                        .padding()
                    }
                } else {
                    if razorpayTestKey == "rzp_test_YOUR_KEY_HERE" {
                        VStack(spacing: 16) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                                .font(.system(size: 50))
                            Text("Missing Razorpay Key")
                                .font(.headline)
                            Text("Please open Config.swift and replace 'rzp_test_YOUR_KEY_HERE' with your real Razorpay Test Key.")
                                .multilineTextAlignment(.center)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                    } else {
                        RazorpayWebView(
                            amount: cartManager.total,
                            razorpayKey: razorpayTestKey,
                            onPaymentSuccess: { pid in
                                // Save order to OrderManager before clearing cart
                                OrderManager.shared.addOrder(
                                    from: cartManager.items,
                                    total: cartManager.total,
                                    paymentId: pid
                                )
                                paymentId = pid
                                paymentStatus = "SUCCESS"
                            },
                            onPaymentError: { error in
                                print("Razorpay Error: \(error)")
                                paymentStatus = "FAILED"
                            }
                        )
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(leading: Button("Close") {
                presentationMode.wrappedValue.dismiss()
            })
            .onAppear {
                NotificationCenter.default.post(name: .aiCheckoutStarted, object: nil)
            }
        }
    }
}

// Custom WebView to bridge Razorpay JS to Swift
struct RazorpayWebView: UIViewRepresentable {
    let amount: Double
    let razorpayKey: String
    let onPaymentSuccess: (String) -> Void
    let onPaymentError: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> WKWebView {
        let contentController = WKUserContentController()
        contentController.add(context.coordinator, name: "razorpay")
        
        let config = WKWebViewConfiguration()
        config.userContentController = contentController
        // Required for Razorpay popup windows
        config.preferences.javaScriptCanOpenWindowsAutomatically = true
        
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.uiDelegate = context.coordinator
        webView.navigationDelegate = context.coordinator
        context.coordinator.mainWebView = webView
        
        // Convert USD to INR (1 USD ≈ 83 INR)
        let amountInINR = amount * 83.0
        let amountInPaise = Int(amountInINR * 100)
        
        let htmlString = """
        <html>
        <head>
            <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
            <style>
                body { background-color: white; margin: 0; padding: 0; display: flex; flex-direction: column; justify-content: center; align-items: center; height: 100vh; font-family: -apple-system, sans-serif;}
                .loader { border: 4px solid #f3f3f3; border-top: 4px solid #0d6efd; border-radius: 50%; width: 40px; height: 40px; animation: spin 1s linear infinite; margin-bottom: 20px;}
                @keyframes spin { 0% { transform: rotate(0deg); } 100% { transform: rotate(360deg); } }
            </style>
        </head>
        <body>
        <div class="loader" id="loader"></div>
        <p id="text" style="color: gray;">Loading Secure Checkout...</p>
        <script src="https://checkout.razorpay.com/v1/checkout.js"></script>
        <script>
            var options = {
                "key": "\(razorpayKey)",
                "amount": \(amountInPaise),
                "currency": "INR",
                "name": "ShopEase",
                "description": "Order Checkout",
                "handler": function (response) {
                    window.webkit.messageHandlers.razorpay.postMessage("SUCCESS:" + response.razorpay_payment_id);
                },
                "modal": {
                    "ondismiss": function() {
                        window.webkit.messageHandlers.razorpay.postMessage("DISMISSED");
                    }
                },
                "prefill": {
                    "name": "\(AuthSession.shared.currentUser?.name ?? "Customer")",
                    "email": "\(AuthSession.shared.currentUser?.email ?? "")",
                    "contact": "8888888888"
                },
                "theme": {
                    "color": "#0d6efd"
                }
            };
            var rzp1 = new Razorpay(options);
            rzp1.on('payment.failed', function (response) {
                window.webkit.messageHandlers.razorpay.postMessage("FAILED:" + response.error.description);
            });
            setTimeout(function() {
                rzp1.open();
                document.getElementById('loader').style.display = 'none';
                document.getElementById('text').style.display = 'none';
            }, 800);
        </script>
        </body>
        </html>
        """
        
        webView.loadHTMLString(htmlString, baseURL: URL(string: "https://checkout.razorpay.com"))
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    class Coordinator: NSObject, WKScriptMessageHandler, WKUIDelegate, WKNavigationDelegate {
        var parent: RazorpayWebView
        var mainWebView: WKWebView?
        var popupWebView: WKWebView?

        init(_ parent: RazorpayWebView) {
            self.parent = parent
        }

        // Create a separate popup WKWebView overlaid on the main one
        // so the main checkout JS context stays alive
        func webView(_ webView: WKWebView,
                     createWebViewWith configuration: WKWebViewConfiguration,
                     for navigationAction: WKNavigationAction,
                     windowFeatures: WKWindowFeatures) -> WKWebView? {
            guard let mainView = mainWebView else { return nil }
            
            let popup = WKWebView(frame: mainView.bounds, configuration: configuration)
            popup.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            popup.navigationDelegate = self
            popup.uiDelegate = self
            mainView.addSubview(popup)
            popupWebView = popup
            return popup
        }

        // Called when popup calls window.close()
        func webViewDidClose(_ webView: WKWebView) {
            webView.removeFromSuperview()
            if popupWebView == webView { popupWebView = nil }
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard let msg = message.body as? String else { return }
            DispatchQueue.main.async {
                if msg.hasPrefix("SUCCESS:") {
                    let pid = msg.replacingOccurrences(of: "SUCCESS:", with: "")
                    self.parent.onPaymentSuccess(pid)
                } else if msg.hasPrefix("FAILED:") {
                    let error = msg.replacingOccurrences(of: "FAILED:", with: "")
                    self.parent.onPaymentError(error)
                }
                // DISMISSED — user closed modal, no action needed
            }
        }
    }
}
