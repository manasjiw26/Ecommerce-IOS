# Private Cloud AI Core API Documentation
**Base URL:** `https://ai.amay.fun`  
**Authentication Type:** Custom Header Verification  
**Enforcement Layer:** Caddy Proxy Sandbox

This document outlines the integration specifications for your dedicated, cloud-hosted LLM microservice. The service is optimized for standard request-response operations and ultra-low latency real-time streaming architectures.

---

## 1. Authentication & Security Configuration

All inbound requests must pass through the security perimeter via a custom authorization header. Requests missing this header or providing incorrect tokens will be dropped instantly at the gateway with an HTTP status `401 Unauthorized`.

| Header Key | Expected Value | Description |
| :--- | :--- | :--- |
| `Content-Type` | `application/json` | Required for all payloads. |
| `X-Custom-Auth` | `Janaki0510#` | Your private gateway access token. |

---

## 2. Model Registry

Two distinct model configurations are cached locally on the server filesystem:

1. **`llama3.2:1b` (Recommended / Default)**
   * **Size:** ~1.3 GB (1 Billion Parameters)
   * **Performance Profile:** Optimized for CPU-only architectures. Token throughput sits at ~73ms per token (~14 tokens/sec).
   * **Best For:** Real-time interactive UI streaming, mobile execution, and text manipulation tasks.

2. **`llama3.2`**
   * **Size:** ~2.0 GB (3 Billion Parameters)
   * **Performance Profile:** Denser context mapping but highly compute-heavy on standard instances (~6.0s generation overhead).
   * **Best For:** Complex logic, zero-shot structured text extraction, or non-interactive batch actions.

---

## 3. API Endpoints Reference

### Endpoint A: Code Execution / Text Generation (`/api/generate`)
Generates a text completion based on a raw prompt input string.

#### Payload Structure (POST Request)

```json
{
  "model": "llama3.2:1b",
  "prompt": "Why is the sky blue?",
  "stream": true
}
```

#### Non-Streamed Response Payload (`"stream": false`)

```json
{
  "model": "llama3.2:1b",
  "created_at": "2026-05-16T11:25:19.821054959Z",
  "response": "The sky appears blue because of Rayleigh scattering...",
  "done": true,
  "total_duration": 2737337527,
  "load_duration": 994860898,
  "prompt_eval_count": 37,
  "prompt_eval_duration": 1006468204,
  "eval_count": 45,
  "eval_duration": 726147017
}
```

#### Streamed Response Payload (`"stream": true`)

Returns an `NDJSON` (Newline-Delimited JSON) stream. Each line is an individual atomic JSON object representing an extracted token chunk:

```json
{"model":"llama3.2:1b","created_at":"...","response":"The","done":false}
{"model":"llama3.2:1b","created_at":"...","response":" sky","done":false}
{"model":"llama3.2:1b","created_at":"...","response":"","done":true}
```

---

### Endpoint B: Multi-Turn Conversation (`/api/chat`)

Maintains conversation state and persona history via sequential message maps.

#### Payload Structure (POST Request)

```json
{
  "model": "llama3.2:1b",
  "messages": [
    { "role": "system", "content": "You are a concise engineering assistant." },
    { "role": "user", "content": "What is the port for HTTPS?" },
    { "role": "assistant", "content": "The port for HTTPS is 443." },
    { "role": "user", "content": "And SSH?" }
  ],
  "stream": false
}
```

---

## 4. Platform Integration SDK Examples

### Cross-Platform JavaScript / TypeScript (Vercel, Node, React)

Uses the native `ReadableStream` system to tap directly into incoming chunk frames.

```javascript
async function generateAIResponse(userPrompt) {
  try {
    const response = await fetch('https://ai.amay.fun/api/generate', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-Custom-Auth': 'Janaki0510#'
      },
      body: JSON.stringify({
        model: 'llama3.2:1b',
        prompt: userPrompt,
        stream: true
      })
    });

    if (response.status === 401) {
      console.error("Security Authentication Rejected.");
      return;
    }

    const reader = response.body.getReader();
    const decoder = new TextDecoder();
    let partialLine = '';

    while (true) {
      const { done, value } = await reader.read();
      if (done) break;

      const chunk = decoder.decode(value, { stream: true });
      const lines = (partialLine + chunk).split('\n');
      partialLine = lines.pop(); // Hold onto uncompleted line fragment

      for (const line of lines) {
        if (line.trim()) {
          const parsedJSON = JSON.parse(line);
          // Callback or state assignment to inject character text directly into the UI state
          process.stdout.write(parsedJSON.response);
        }
      }
    }
  } catch (error) {
    console.error("Network interface error:", error);
  }
}
```

---

### Native iOS Integration (Swift / SwiftUI)

Implements async/await parsing over low-level byte buffers to support instant mobile UI feedback loops.

```swift
import Foundation

class CloudAIViewModel: ObservableObject {
    @Published var outputText: String = ""
    @Published var isGenerating: Bool = false
    
    func streamPrompt(promptText: String) async {
        guard let url = URL(string: "https://ai.amay.fun/api/generate") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Janaki0510#", forHTTPHeaderField: "X-Custom-Auth")
        
        let payload: [String: Any] = [
            "model": "llama3.2:1b",
            "prompt": promptText,
            "stream": true
        ]
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: payload) else { return }
        request.httpBody = jsonData
        
        DispatchQueue.main.async {
            self.outputText = ""
            self.isGenerating = true
        }
        
        do {
            let (bytes, response) = try await URLSession.shared.bytes(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                print("Server security rejection or server fault.")
                return
            }
            
            for try await line in bytes.lines {
                if let data = line.data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let responseText = json["response"] as? String {
                    
                    DispatchQueue.main.async {
                        self.outputText += responseText
                    }
                }
            }
        } catch {
            print("Failed to stream sequence from cloud core: \\(error)")
        }
        
        DispatchQueue.main.async { self.isGenerating = false }
    }
}
```

---

### Native Android Integration (Kotlin / Coroutines Flow)

Exposes an asynchronous, cold stream of string tokens via Kotlin Coroutines.

```kotlin
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.flow
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONObject
import java.io.BufferedReader

class CloudAIService {
    private val client = OkHttpClient()
    private val mediaType = "application/json; charset=utf-8".toMediaType()

    fun streamAIResponse(promptText: String): Flow<String> = flow {
        val payload = JSONObject().apply {
            put("model", "llama3.2:1b")
            put("prompt", promptText)
            put("stream", true)
        }

        val request = Request.Builder()
            .url("https://ai.amay.fun/api/generate")
            .post(payload.toString().toRequestBody(mediaType))
            .addHeader("Content-Type", "application/json")
            .addHeader("X-Custom-Auth", "Janaki0510#")
            .build()

        client.newCall(request).execute().use { response ->
            if (!response.isSuccessful) throw Exception("Network error: ${response.code}")
            
            val reader = response.body?.charStream()?.let { BufferedReader(it) }
            var line: String? = reader?.readLine()
            
            while (line != null) {
                if (line.trim().isNotEmpty()) {
                    val jsonObject = JSONObject(line)
                    val token = jsonObject.optString("response", "")
                    emit(token) // Pushes individual character segments straight downstream
                }
                line = reader?.readLine()
            }
        }
    }
}
```

---

## 5. Architectural Lifecycle & Cost Optimization Guidelines

Your server is operating on an infrastructure consumption billing cycle costing **$0.0492 USD/hr**. To maximize utility from your available credits, adhere to these operational procedures:

* **Asynchronous Pausing:** When actively working away from integration environments for intervals extending beyond 48 hours, navigate to your Azure Portal compute engine management panel and execute a hard **Stop** command on the resource. Computing fees freeze immediately (leaving only negligible pennies for storage allocation metrics).
* **Connection Re-entry:** Upon executing a **Start** procedure on the instance later, your configuration is structured persistent—both Caddy proxies and Ollama system units automatically safely cycle online to receive inbound integration calls immediately without requiring manual configuration over SSH.
