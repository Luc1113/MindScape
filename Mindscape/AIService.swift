//
//  AIService.swift
//  Mindscape
//
//  Rewritten for Hugging Face Inference API
//

import Foundation

struct ChatMessage: Identifiable, Codable, Equatable {
    let id: UUID
    let text: String
    let isUserMessage: Bool

    init(id: UUID = UUID(), text: String, isUserMessage: Bool) {
        self.id = id
        self.text = text
        self.isUserMessage = isUserMessage
    }
}

@MainActor
class AIService: ObservableObject {
    // MARK: - Published state (Dashboard bindings expect these)
    @Published var motivationalMessage: String = "Loading your daily motivation..."
    @Published var isLoading: Bool = false
    @Published var hasError: Bool = false

    @Published var chatMessages: [ChatMessage] = []
    @Published var isChatLoading: Bool = false

    // MARK: - HF Config
    /// Change the model if you like (accept license on its model page if required).
    private let modelURL = URL(string: "https://api-inference.huggingface.co/pipeline/text-generation/tiiuae/falcon-7b-instruct")!

    // MARK: - Secrets
    private var apiKey: String? {
        guard
            let path = Bundle.main.path(forResource: "Secrets", ofType: "plist"),
            let secrets = NSDictionary(contentsOfFile: path),
            let key = secrets["HF_KEY"] as? String,
            !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            print("❌ HF API Key not found in Secrets.plist (key: HF_KEY)")
            return nil
        }
        return key
    }

    // MARK: - Public API (Motivation)

    /// Fire-and-forget wrapper to keep call sites simple.
    func fetchMotivationalMessage(todayRating: Int?, completedTodos: Int, totalTodos: Int) {
        Task { await fetchMotivationalMessageAsync(todayRating: todayRating, completedTodos: completedTodos, totalTodos: totalTodos) }
    }

    /// Async implementation using HF Inference API.
    func fetchMotivationalMessageAsync(todayRating: Int?, completedTodos: Int, totalTodos: Int) async {
        guard let apiKey = apiKey else {
            self.motivationalMessage = "AI features unavailable — missing API key."
            self.hasError = true
            return
        }

        isLoading = true
        hasError = false

        let userPrompt = createMotivationalPrompt(todayRating: todayRating, completedTodos: completedTodos, totalTodos: totalTodos)
        // Give the model a short instruction prefix
        let prompt = """
        You are a supportive AI assistant that provides brief, personalized motivational messages (2–3 sentences max). Be encouraging, positive, and specific to the user's current situation.

        Task: \(userPrompt)
        """

        do {
            let text = try await hfGenerateText(apiKey: apiKey,
                                                prompt: prompt,
                                                maxNewTokens: 120,
                                                temperature: 0.7)
            let content = text
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "\n", with: " ")

            self.motivationalMessage = content.isEmpty
                ? "You've got this! One task at a time! 🎯"
                : content
        } catch let HFError.badStatus(code, msg) {
            self.hasError = true
            self.motivationalMessage = friendlyErrorMessage(for: code)
            print("HTTP Error: \(code), body: \(msg)")
        } catch {
            print("❌ HF request failed: \(error.localizedDescription)")
            self.hasError = true
            self.motivationalMessage = "You're doing great — small steps add up. Keep going! ✨"
        }

        isLoading = false
    }

    // MARK: - Public API (Chat)

    /// Send a chat message with lightweight context (recent history) and some app-aware hints.
    func sendChatMessage(
        _ text: String,
        todayRating: Int?,
        completedTodos: Int,
        totalTodos: Int
    ) {
        Task { await sendChatMessageAsync(text, todayRating: todayRating, completedTodos: completedTodos, totalTodos: totalTodos) }
    }

    private func sendChatMessageAsync(
        _ text: String,
        todayRating: Int?,
        completedTodos: Int,
        totalTodos: Int
    ) async {
        guard let apiKey = apiKey else {
            appendAssistant("AI features unavailable — missing API key.")
            return
        }

        // Optimistic UI: append user message immediately
        let userMsg = ChatMessage(text: text, isUserMessage: true)
        chatMessages.append(userMsg)
        isChatLoading = true

        // Build system prompt with light context from app state
        let systemContext = """
        You are an encouraging, succinct AI coach inside a personal productivity app.
        Style: supportive, actionable, concise. Prefer 1–4 sentences. Avoid fluff.
        If asked about today: rating=\(todayRating.map(String.init) ?? "nil"), completed=\(completedTodos), goal=\(totalTodos).
        If user asks for help on tasks, suggest concrete next steps and keep tone positive.
        """

        // Prepare recent chat history (last N = 10) to preserve context
        let recent = Array(chatMessages.suffix(10))
        let historyText = recent.map { msg in
            (msg.isUserMessage ? "User: " : "Assistant: ") + msg.text
        }.joined(separator: "\n")

        // Compose a single prompt for a text-generation model
        let combinedPrompt = """
        \(systemContext)

        Conversation:
        \(historyText)

        Assistant:
        """

        do {
            let reply = try await hfGenerateText(apiKey: apiKey,
                                                 prompt: combinedPrompt,
                                                 maxNewTokens: 300,
                                                 temperature: 0.7)
            let content = reply
                .trimmingCharacters(in: .whitespacesAndNewlines)

            appendAssistant(content.isEmpty
                            ? "Let’s take a small, clear step: pick one task and spend 5 focused minutes on it. Then check in with me. 😊"
                            : content)
        } catch let HFError.badStatus(code, msg) {
            appendAssistant(friendlyErrorMessage(for: code))
            print("HTTP Error (chat): \(code), body: \(msg)")
        } catch {
            print("❌ Chat request failed: \(error.localizedDescription)")
            appendAssistant("I hit a snag connecting. Try again in a moment?")
        }

        isChatLoading = false
    }

    // MARK: - Connectivity Test

    /// Light ping: send a tiny request to the model endpoint and report status.
    func testAPIConnection() {
        guard let apiKey = apiKey else {
            print("❌ API Key not found")
            return
        }

        var request = URLRequest(url: modelURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = HFTextRequest(inputs: "ping", parameters: .init(max_new_tokens: 1, temperature: 0.1, top_p: 0.95, repetition_penalty: 1.0, return_full_text: false))
        request.httpBody = try? JSONEncoder().encode(body)

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("API Test Error: \(error.localizedDescription)")
                return
            }
            if let http = response as? HTTPURLResponse {
                print("API Test Status Code: \(http.statusCode)")
                if http.statusCode == 200 {
                    print("✅ HF token and model endpoint reachable!")
                } else if http.statusCode == 503 {
                    print("ℹ️ Model loading (503). Try again shortly.")
                } else {
                    print("❌ HF test failed \(http.statusCode): \(String(data: data ?? Data(), encoding: .utf8) ?? "")")
                }
            }
        }.resume()
    }

    // MARK: - Private helpers

    private func createMotivationalPrompt(todayRating: Int?, completedTodos: Int, totalTodos: Int) -> String {
        var prompt = "Create a brief motivational message for a user based on their day. "

        if let rating = todayRating {
            let ratingText = getRatingText(rating)
            prompt += "They rated their day as '\(ratingText)' (\(rating)/6). "
        } else {
            prompt += "They haven't rated their day yet. "
        }

        prompt += "They've completed \(completedTodos) out of \(totalTodos) todo items today. "

        if totalTodos > 0 && completedTodos == totalTodos {
            prompt += "Congratulate them on completing all tasks! "
        } else if completedTodos > totalTodos / 2 {
            prompt += "Encourage them to finish strong. "
        } else if completedTodos == 0 {
            prompt += "Motivate them to get started. "
        } else {
            prompt += "Encourage their progress so far. "
        }

        prompt += "Keep it positive, personal, and under 3 sentences."

        return prompt
    }

    private func getRatingText(_ rating: Int) -> String {
        switch rating {
        case 0: return "Terrible"
        case 1: return "Bad"
        case 2: return "Meh"
        case 3: return "Alright"
        case 4: return "Good"
        case 5: return "Great"
        case 6: return "Awesome"
        default: return "Unknown"
        }
    }

    private func friendlyErrorMessage(for status: Int) -> String {
        switch status {
        case 400: return "The AI request was malformed. Try again in a moment."
        case 401: return "AI features unavailable — check your API key."
        case 403: return "Access to the model is restricted."
        case 429: return "The AI is a bit busy (rate limited). Try again shortly."
        case 503: return "The model is spinning up. Try again in a few seconds."
        case 500...599: return "AI service is temporarily unavailable. Please try again soon."
        default: return "Something went wrong talking to the AI."
        }
    }

    private func appendAssistant(_ text: String) {
        let clean = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\n", with: " ")
        chatMessages.append(ChatMessage(text: clean, isUserMessage: false))
    }

    // MARK: - HF Request Helper

    /// Calls the HF Inference API for text generation and returns the generated text.
    private func hfGenerateText(apiKey: String,
                                prompt: String,
                                maxNewTokens: Int,
                                temperature: Double) async throws -> String {
        var request = URLRequest(url: modelURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = HFTextRequest(
            inputs: prompt,
            parameters: .init(
                max_new_tokens: maxNewTokens,
                temperature: temperature,
                top_p: 0.95,
                repetition_penalty: 1.1,
                return_full_text: false
            )
        )

        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? -1
        if status < 200 || status >= 300 {
            let msg = String(data: data, encoding: .utf8) ?? ""
            throw HFError.badStatus(status, msg)
        }

        // HF returns an array of items; most text-gen models expose "generated_text".
        if let items = try? JSONDecoder().decode([HFTextResponseItem].self, from: data),
           let text = items.first?.generated_text, !text.isEmpty {
            return text
        }

        // Some pipelines may return a different schema (rare for text-generation),
        // so fall back to raw string for debugging.
        if let raw = String(data: data, encoding: .utf8), !raw.isEmpty {
            return raw
        }

        throw HFError.empty
    }
}

// MARK: - HF Models

private struct HFTextRequest: Encodable {
    let inputs: String
    let parameters: Parameters?

    struct Parameters: Encodable {
        let max_new_tokens: Int?
        let temperature: Double?
        let top_p: Double?
        let repetition_penalty: Double?
        let return_full_text: Bool?
    }
}

private struct HFTextResponseItem: Decodable {
    let generated_text: String?
}

private enum HFError: Error {
    case missingKey
    case badStatus(Int, String)
    case empty
}
