/// How SecondBrain picks an LLM backend.
enum LlmMode {
  /// Always use local Ollama (default).
  local,

  /// Always use Google Gemini (AI Studio API key required).
  cloud,

  /// Prefer Ollama; if unreachable, fall back to Gemini when a key is set.
  auto,
}

extension LlmModeX on LlmMode {
  String get storageValue => name;

  String get labelRu {
    switch (this) {
      case LlmMode.local:
        return 'Локально (Ollama)';
      case LlmMode.cloud:
        return 'Облако (Gemini)';
      case LlmMode.auto:
        return 'Авто (Ollama → Gemini)';
    }
  }

  static LlmMode fromStorage(String? raw) {
    switch (raw) {
      case 'cloud':
        return LlmMode.cloud;
      case 'auto':
        return LlmMode.auto;
      case 'local':
      default:
        return LlmMode.local;
    }
  }
}
