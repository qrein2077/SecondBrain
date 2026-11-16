import 'package:flutter/foundation.dart';

import '../models/app_settings.dart';
import '../models/chat_message.dart';
import '../models/llm_mode.dart';
import '../services/agent_parser.dart';
import '../services/openai_compat_client.dart';
import '../services/settings_store.dart';
import '../services/vault_service.dart';

/// Which backend produced the last successful chat reply.
enum LlmBackend { ollama, gemini }

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
  bool geminiReachable = false;
  LlmBackend? lastBackend;

  NoteDraftBundle? pendingDraft;

  AppSettings get settings => settingsStore.settings;

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
        return settings.geminiModel;
      case LlmMode.auto:
        return '${settings.modelName} / ${settings.geminiModel}';
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
    bool clearGeminiApiKey = false,
  }) async {
    final vaultChanged = next.vaultPath != settings.vaultPath;
    await settingsStore.update(
      next,
      geminiApiKey: geminiApiKey,
      clearGeminiApiKey: clearGeminiApiKey,
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
    if (settingsStore.hasGeminiApiKey) {
      geminiReachable = await _llm.pingGemini(settingsStore.geminiApiKey);
    } else {
      geminiReachable = false;
    }
    notifyListeners();
  }

  /// @Deprecated alias — prefer [checkBackends].
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

  /// System prompt + live vault context (paths / open note).
  String buildChatSystemPrompt() {
    final buf = StringBuffer(settings.systemPrompt.trim());
    buf.writeln();
    buf.writeln();
    buf.writeln('## Контекст vault (приложение, не пользователь)');
    buf.writeln(
      'Работай со ВСЕМ vault. Не ограничивайся одной заметкой.',
    );
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
      buf.writeln('(список пуст — можно предложить первые заметки)');
    } else {
      buf.writeln('Существующие пути (для [[wiki-links]] и update):');
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

  Future<({String content, LlmBackend backend})> _chatWithRouting({
    required String systemPrompt,
    required List<ChatMessage> history,
  }) async {
    final mode = settings.llmMode;
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

    Future<({String content, LlmBackend backend})> viaGemini() async {
      final key = settingsStore.geminiApiKey;
      if (key.isEmpty) {
        throw LlmException(
          'Режим Gemini: укажите API-ключ Google AI Studio в Настройках.',
        );
      }
      final content = await _llm.chatGemini(
        apiKey: key,
        model: settings.geminiModel,
        systemPrompt: systemPrompt,
        history: history,
      );
      geminiReachable = true;
      return (content: content, backend: LlmBackend.gemini);
    }

    switch (mode) {
      case LlmMode.local:
        return viaOllama();
      case LlmMode.cloud:
        return viaGemini();
      case LlmMode.auto:
        if (ollamaUp) {
          try {
            return await viaOllama();
          } catch (_) {
            // Fall through to Gemini if Ollama fails mid-request.
          }
        }
        if (!settingsStore.hasGeminiApiKey) {
          throw LlmException(
            ollamaUp
                ? 'Ollama недоступна для ответа, а ключ Gemini не задан.'
                : 'Ollama offline, ключ Gemini не задан. '
                    'Включите Ollama или добавьте Gemini в Настройках.',
          );
        }
        return viaGemini();
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

      final result = await _chatWithRouting(
        systemPrompt: buildChatSystemPrompt(),
        history: chat
            .where((m) =>
                m.role == ChatRole.user || m.role == ChatRole.assistant)
            .toList(),
      );
      lastBackend = result.backend;
      final parsed = AgentParser.parse(result.content);
      final backendTag =
          result.backend == LlmBackend.ollama ? 'Ollama' : 'Gemini';
      chat.add(
        ChatMessage(
          role: ChatRole.assistant,
          content: parsed.displayText,
          draftBundle: parsed.draft,
        ),
      );
      // Soft status line for transparency (not part of model reply).
      chat.add(
        ChatMessage(
          role: ChatRole.system,
          content: 'Ответ через $backendTag',
        ),
      );
      if (parsed.draft != null && parsed.draft!.isNotEmpty) {
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
    final written = await v.approveDrafts(draft);
    pendingDraft = null;
    await refreshVault();
    chat.add(
      ChatMessage(
        role: ChatRole.system,
        content: 'Утверждён пакет ($n файл.): ${written.join(', ')}',
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
