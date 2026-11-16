import 'package:flutter/foundation.dart';

import '../models/app_settings.dart';
import '../models/chat_message.dart';
import '../models/cloud_provider.dart';
import '../models/llm_mode.dart';
import '../services/agent_parser.dart';
import '../services/openai_compat_client.dart';
import '../services/settings_store.dart';
import '../services/vault_retriever.dart';
import '../services/vault_service.dart';

/// Which backend produced the last successful chat reply.
enum LlmBackend { ollama, gemini, groq, openRouter }

extension LlmBackendX on LlmBackend {
  String get label {
    switch (this) {
      case LlmBackend.ollama:
        return 'Ollama';
      case LlmBackend.gemini:
        return 'Gemini';
      case LlmBackend.groq:
        return 'Groq';
      case LlmBackend.openRouter:
        return 'OpenRouter';
    }
  }

  static LlmBackend fromCloud(CloudProvider p) {
    switch (p) {
      case CloudProvider.gemini:
        return LlmBackend.gemini;
      case CloudProvider.groq:
        return LlmBackend.groq;
      case CloudProvider.openRouter:
        return LlmBackend.openRouter;
    }
  }
}

/// Top-level app state: settings, vault browsing, editor, chat, drafts.
class AppController extends ChangeNotifier {
  AppController({
    SettingsStore? settingsStore,
    OpenAiCompatClient? llmClient,
  })  : settingsStore = settingsStore ?? SettingsStore(),
        _llm = llmClient ?? OpenAiCompatClient();

  final SettingsStore settingsStore;
  final OpenAiCompatClient _llm;

  List<String> markdownFiles = [];
  String? selectedPath;
  String editorText = '';
  bool editorDirty = false;
  bool loadingVault = false;
  String? vaultError;

  final List<ChatMessage> chat = [];
  bool chatBusy = false;
  String? chatError;
  bool ollamaOnline = false;
  bool cloudReachable = false;
  LlmBackend? lastBackend;

  NoteDraftBundle? pendingDraft;

  /// Paths from the last RAG-lite retrieval (for UI chips).
  List<String> lastRetrievalSources = [];

  final VaultRetriever _retriever = const VaultRetriever();

  AppSettings get settings => settingsStore.settings;

  /// Kept for older UI bindings.
  bool get geminiReachable =>
      settings.cloudProvider == CloudProvider.gemini && cloudReachable;

  VaultService? get vault {
    final path = settings.vaultPath;
    if (path.trim().isEmpty) return null;
    return VaultService(vaultRoot: path);
  }

  String get activeModelLabel {
    switch (settings.llmMode) {
      case LlmMode.local:
        return settings.modelName;
      case LlmMode.cloud:
        return settings.cloudModelFor(settings.cloudProvider);
      case LlmMode.auto:
        return '${settings.modelName} / '
            '${settings.cloudModelFor(settings.cloudProvider)}';
    }
  }

  Future<void> init() async {
    await settingsStore.load();
    settingsStore.addListener(_onSettingsChanged);
    await refreshVault();
    await checkBackends();
  }

  void _onSettingsChanged() {
    notifyListeners();
  }

  Future<void> saveSettings(
    AppSettings next, {
    String? geminiApiKey,
    String? groqApiKey,
    String? openRouterApiKey,
    bool clearGeminiApiKey = false,
    bool clearGroqApiKey = false,
    bool clearOpenRouterApiKey = false,
  }) async {
    final vaultChanged = next.vaultPath != settings.vaultPath;
    await settingsStore.update(
      next,
      geminiApiKey: geminiApiKey,
      groqApiKey: groqApiKey,
      openRouterApiKey: openRouterApiKey,
      clearGeminiApiKey: clearGeminiApiKey,
      clearGroqApiKey: clearGroqApiKey,
      clearOpenRouterApiKey: clearOpenRouterApiKey,
    );
    if (vaultChanged) {
      selectedPath = null;
      editorText = '';
      editorDirty = false;
      await refreshVault();
    }
    await checkBackends();
    notifyListeners();
  }

  Future<void> checkBackends() async {
    ollamaOnline = await _llm.pingOllama(settings.ollamaBaseUrl);
    final provider = settings.cloudProvider;
    if (settingsStore.hasKeyFor(provider)) {
      cloudReachable =
          await _llm.pingCloud(provider, settingsStore.apiKeyFor(provider));
    } else {
      cloudReachable = false;
    }
    notifyListeners();
  }

  Future<void> checkOllama() => checkBackends();

  Future<void> refreshVault() async {
    final v = vault;
    if (v == null) {
      markdownFiles = [];
      vaultError = null;
      notifyListeners();
      return;
    }
    loadingVault = true;
    vaultError = null;
    notifyListeners();
    try {
      markdownFiles = await v.listMarkdownFiles();
    } catch (e) {
      vaultError = e.toString();
      markdownFiles = [];
    } finally {
      loadingVault = false;
      notifyListeners();
    }
  }

  Future<void> openNote(String relativePath) async {
    final v = vault;
    if (v == null) return;
    try {
      editorText = await v.readNote(relativePath);
      selectedPath = relativePath;
      editorDirty = false;
      vaultError = null;
    } catch (e) {
      vaultError = e.toString();
    }
    notifyListeners();
  }

  void updateEditorText(String text) {
    editorText = text;
    editorDirty = true;
    notifyListeners();
  }

  Future<void> saveCurrentNote() async {
    final v = vault;
    final path = selectedPath;
    if (v == null || path == null) return;
    await v.saveNote(path, editorText);
    editorDirty = false;
    await refreshVault();
    notifyListeners();
  }

  Future<void> setQaOnly(bool value) async {
    if (settings.qaOnly == value) return;
    if (value) {
      // Drop any leftover draft UI when switching to Q&A-only.
      pendingDraft = null;
    }
    await saveSettings(settings.copyWith(qaOnly: value));
  }

  String buildChatSystemPrompt({List<VaultHit> hits = const []}) {
    final buf = StringBuffer(settings.systemPrompt.trim());
    buf.writeln();
    buf.writeln();
    buf.writeln(AppSettings.vaultGroundingAddonPrompt.trim());
    if (settings.qaOnly) {
      buf.writeln();
      buf.writeln();
      buf.writeln(AppSettings.qaOnlyAddonPrompt.trim());
    }
    buf.writeln();
    buf.writeln();
    buf.writeln(VaultRetriever.formatForPrompt(hits));
    buf.writeln();
    buf.writeln();
    buf.writeln('## Контекст vault (приложение, не пользователь)');
    if (settings.qaOnly) {
      buf.writeln(
        'Режим только ответов: анализируй выдержки выше; '
        'список путей — справочно. Не предлагай запись.',
      );
    } else {
      buf.writeln(
        'Работай со ВСЕМ vault. На вопросы о знаниях — сначала выдержки. '
        'Для правок: сначала уточняй, потом предлагай пакет заметок.',
      );
    }
    if (selectedPath != null && selectedPath!.isNotEmpty) {
      buf.writeln(
        'В редакторе сейчас открыт (только справка): `$selectedPath`',
      );
    } else {
      buf.writeln('В редакторе ничего не открыто.');
    }
    final files = markdownFiles;
    buf.writeln('Файлов .md в vault: ${files.length}');
    if (files.isEmpty) {
      buf.writeln(
        settings.qaOnly
            ? '(список пуст)'
            : '(список пуст — после уточнений можно предложить первые заметки)',
      );
    } else {
      buf.writeln(
        settings.qaOnly
            ? 'Существующие пути (справочно):'
            : 'Существующие пути (для [[wiki-links]] и update):',
      );
      final limit = 250;
      for (final f in files.take(limit)) {
        buf.writeln('- $f');
      }
      if (files.length > limit) {
        buf.writeln('… и ещё ${files.length - limit}');
      }
    }
    return buf.toString();
  }

  Future<({String content, LlmBackend backend})> _viaCloud(
    CloudProvider provider, {
    required String systemPrompt,
    required List<ChatMessage> history,
  }) async {
    final key = settingsStore.apiKeyFor(provider);
    if (key.isEmpty) {
      throw LlmException(
        'Облако (${provider.shortLabel}): укажите API-ключ в Настройках.',
      );
    }
    final content = await _llm.chatCloud(
      provider: provider,
      apiKey: key,
      model: settings.cloudModelFor(provider),
      systemPrompt: systemPrompt,
      history: history,
    );
    cloudReachable = true;
    return (content: content, backend: LlmBackendX.fromCloud(provider));
  }

  Future<({String content, LlmBackend backend})> _chatWithRouting({
    required String systemPrompt,
    required List<ChatMessage> history,
  }) async {
    final mode = settings.llmMode;
    final provider = settings.cloudProvider;
    final ollamaUp = await _llm.pingOllama(settings.ollamaBaseUrl);
    ollamaOnline = ollamaUp;

    Future<({String content, LlmBackend backend})> viaOllama() async {
      final content = await _llm.chatOllama(
        baseUrl: settings.ollamaBaseUrl,
        model: settings.modelName,
        systemPrompt: systemPrompt,
        history: history,
      );
      return (content: content, backend: LlmBackend.ollama);
    }

    switch (mode) {
      case LlmMode.local:
        return viaOllama();
      case LlmMode.cloud:
        return _viaCloud(
          provider,
          systemPrompt: systemPrompt,
          history: history,
        );
      case LlmMode.auto:
        if (ollamaUp) {
          try {
            return await viaOllama();
          } catch (_) {
            // Fall through to selected cloud provider.
          }
        }
        if (!settingsStore.hasKeyFor(provider)) {
          throw LlmException(
            ollamaUp
                ? 'Ollama не ответила, а ключ ${provider.shortLabel} не задан.'
                : 'Ollama offline, ключ ${provider.shortLabel} не задан. '
                    'Включите Ollama или добавьте ключ облака в Настройках.',
          );
        }
        return _viaCloud(
          provider,
          systemPrompt: systemPrompt,
          history: history,
        );
    }
  }

  Future<void> sendChat(String userText) async {
    final text = userText.trim();
    if (text.isEmpty || chatBusy) return;

    chat.add(ChatMessage(role: ChatRole.user, content: text));
    chatBusy = true;
    chatError = null;
    notifyListeners();

    try {
      if (vault != null) {
        try {
          markdownFiles = await vault!.listMarkdownFiles();
        } catch (_) {}
      }

      List<VaultHit> hits = const [];
      final v = vault;
      if (v != null && markdownFiles.isNotEmpty) {
        try {
          hits = await _retriever.retrieve(
            vault: v,
            files: markdownFiles,
            query: text,
          );
        } catch (_) {
          hits = const [];
        }
      }
      lastRetrievalSources = hits.map((h) => h.path).toList();

      final result = await _chatWithRouting(
        systemPrompt: buildChatSystemPrompt(hits: hits),
        history: chat
            .where((m) =>
                m.role == ChatRole.user || m.role == ChatRole.assistant)
            .toList(),
      );
      lastBackend = result.backend;
      final parsed = AgentParser.parse(
        result.content,
        allowDrafts: !settings.qaOnly,
      );
      chat.add(
        ChatMessage(
          role: ChatRole.assistant,
          content: parsed.displayText,
          draftBundle: parsed.draft,
          sources: List<String>.from(lastRetrievalSources),
        ),
      );
      final srcNote = hits.isEmpty
          ? 'источники: не найдены'
          : 'источники: ${hits.length}';
      chat.add(
        ChatMessage(
          role: ChatRole.system,
          content: settings.qaOnly
              ? 'Ответ через ${result.backend.label} · только ответы · $srcNote'
              : 'Ответ через ${result.backend.label} · $srcNote',
        ),
      );
      if (!settings.qaOnly &&
          parsed.draft != null &&
          parsed.draft!.isNotEmpty) {
        pendingDraft = parsed.draft;
      }
      if (result.backend == LlmBackend.ollama) {
        ollamaOnline = true;
      }
    } catch (e) {
      chatError = e.toString();
      chat.add(ChatMessage(role: ChatRole.error, content: e.toString()));
      if (settings.llmMode == LlmMode.local) {
        ollamaOnline = false;
      }
    } finally {
      chatBusy = false;
      notifyListeners();
    }
  }

  void clearPendingDraft() {
    pendingDraft = null;
    notifyListeners();
  }

  void setPendingDraft(NoteDraftBundle? draft) {
    pendingDraft = draft;
    notifyListeners();
  }

  Future<List<String>> approvePendingDraft() async {
    final draft = pendingDraft;
    final v = vault;
    if (draft == null || v == null) {
      throw StateError('Нет черновика или vault');
    }
    final n = draft.files.length;
    final delN = draft.deleteCount;
    final written = await v.approveDrafts(draft);
    pendingDraft = null;
    if (selectedPath != null &&
        draft.files.any((f) => f.isDelete && f.path == selectedPath)) {
      selectedPath = null;
      editorText = '';
      editorDirty = false;
    }
    await refreshVault();
    chat.add(
      ChatMessage(
        role: ChatRole.system,
        content: delN > 0
            ? 'Утверждён пакет ($n, удал. $delN): ${written.join(', ')}'
            : 'Утверждён пакет ($n файл.): ${written.join(', ')}',
      ),
    );
    notifyListeners();
    return written;
  }

  void rejectPendingDraft() {
    if (pendingDraft == null) return;
    final n = pendingDraft!.files.length;
    chat.add(
      ChatMessage(
        role: ChatRole.system,
        content: 'Пакет черновика отклонён ($n файл.). Vault не изменён.',
      ),
    );
    pendingDraft = null;
    notifyListeners();
  }

  void clearChat() {
    chat.clear();
    pendingDraft = null;
    lastRetrievalSources = [];
    chatError = null;
    notifyListeners();
  }

  @override
  void dispose() {
    settingsStore.removeListener(_onSettingsChanged);
    _llm.dispose();
    super.dispose();
  }
}
