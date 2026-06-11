import Foundation

enum ProviderPreset: String, CaseIterable, Identifiable {
    case openai
    case openrouter
    case ollama
    case lmstudio
    case vllm
    case custom

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .openai: return "OpenAI"
        case .openrouter: return "OpenRouter"
        case .ollama: return "Ollama"
        case .lmstudio: return "LM Studio"
        case .vllm: return "vLLM"
        case .custom: return "Custom"
        }
    }

    var defaultBaseURL: String {
        switch self {
        case .openai: return "https://api.openai.com/v1"
        case .openrouter: return "https://openrouter.ai/api/v1"
        case .ollama: return "http://localhost:11434/v1"
        case .lmstudio: return "http://localhost:1234/v1"
        case .vllm: return "http://localhost:8000/v1"
        case .custom: return ""
        }
    }

    var defaultModel: String {
        switch self {
        case .openai: return "gpt-4.1-mini"
        case .openrouter: return "openai/gpt-4o-mini"
        case .ollama: return "qwen3:8b"
        case .lmstudio: return ""
        case .vllm: return ""
        case .custom: return ""
        }
    }

    var needsAPIKey: Bool {
        switch self {
        case .openai, .openrouter: return true
        case .ollama, .lmstudio, .vllm, .custom: return false
        }
    }

    /// Each provider exposes a different knob for disabling reasoning/"thinking".
    /// These extra body params are merged into the chat-completions request.
    /// A client-side <think>…</think> stripper covers providers with no knob.
    func thinkingDisableParams(model: String) -> [String: Any] {
        let m = model.lowercased()
        switch self {
        case .openai:
            if m.hasPrefix("gpt-5") { return ["reasoning_effort": "minimal"] }
            if m.range(of: #"^o\d"#, options: .regularExpression) != nil {
                return ["reasoning_effort": "low"]
            }
            return [:]
        case .openrouter:
            return ["reasoning": ["enabled": false]]
        case .ollama:
            // Ollama honors "think"; unknown fields are ignored by older versions.
            return ["think": false]
        case .vllm:
            return ["chat_template_kwargs": ["enable_thinking": false]]
        case .lmstudio, .custom:
            // No standard knob — rely on the <think> tag stripper.
            return [:]
        }
    }
}
