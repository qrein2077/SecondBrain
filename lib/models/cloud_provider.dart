/// Optional cloud LLM when mode is cloud or auto-fallback.
enum CloudProvider {
  gemini,
  groq,
  openRouter,
}

extension CloudProviderX on CloudProvider {
  String get storageValue => name;

  String get labelRu {
    switch (this) {
      case CloudProvider.gemini:
        return 'Google Gemini (AI Studio)';
      case CloudProvider.groq:
        return 'Groq';
      case CloudProvider.openRouter:
        return 'OpenRouter';
    }
  }

  String get shortLabel {
    switch (this) {
      case CloudProvider.gemini:
        return 'Gemini';
      case CloudProvider.groq:
        return 'Groq';
      case CloudProvider.openRouter:
        return 'OpenRouter';
    }
  }

  static CloudProvider fromStorage(String? raw) {
    switch (raw) {
      case 'groq':
        return CloudProvider.groq;
      case 'openRouter':
        return CloudProvider.openRouter;
      case 'gemini':
      default:
        return CloudProvider.gemini;
    }
  }
}
