import Foundation
let urlStr = "https://czahuzfliuuhhegynsjr.supabase.co/storage/v1/object/public/Product%20Images/gemini_kitchen_1.png"
if let url = URL(string: urlStr) {
    print("URL is valid: \(url)")
} else {
    print("URL is INVALID")
}
