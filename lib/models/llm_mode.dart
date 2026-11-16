/// How SecondBrain picks an LLM backend.
enum LlmMode {
  /// Always use local Ollama (default).
  local,

  /// Always use the selected cloud provider (API key required).
  cloud,

  /// Prefer Ollama; if unreachable, fall back to selected cloud provider.
  auto,
}

extension LlmModeX on LlmMode {
  String get storageValue => name;

  String get labelRu {
    switch (this) {
      case LlmMode.local:
        return 'Локально (Ollama)';
      case LlmMode.cloud:
        return 'Облако';
      case LlmMode.auto:
        return 'Авто (Ollama → облако)';
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
