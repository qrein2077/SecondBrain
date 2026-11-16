import 'package:flutter/foundation.dart';

import '../models/app_settings.dart';
import '../models/chat_message.dart';
import '../services/agent_parser.dart';
import '../services/ollama_client.dart';
import '../services/settings_store.dart';
import '../services/vault_service.dart';

/// Top-level app state: settings, vault browsing, editor, chat, drafts.
class AppController extends ChangeNotifier {
  AppController({
    SettingsStore? settingsStore,
    OllamaClient? ollamaClient,
  })  : settingsStore = settingsStore ?? SettingsStore(),
        _ollama = ollamaClient ?? OllamaClient();

  final SettingsStore settingsStore;
  final OllamaClient _ollama;

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

  NoteDraftBundle? pendingDraft;

  AppSettings get settings => settingsStore.settings;

  VaultService? get vault {
    final path = settings.vaultPath;
    if (path.trim().isEmpty) return null;
    return VaultService(vaultRoot: path);
  }

  Future<void> init() async {
    await settingsStore.load();
    settingsStore.addListener(_onSettingsChanged);
    await refreshVault();
    await checkOllama();
  }

  void _onSettingsChanged() {
    notifyListeners();
  }

  Future<void> saveSettings(AppSettings next) async {
    final vaultChanged = next.vaultPath != settings.vaultPath;
    await settingsStore.update(next);
    if (vaultChanged) {
      selectedPath = null;
      editorText = '';
      editorDirty = false;
      await refreshVault();
    }
    await checkOllama();
    notifyListeners();
  }

  Future<void> checkOllama() async {
    ollamaOnline = await _ollama.ping(settings.ollamaBaseUrl);
    notifyListeners();
  }

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
    if (editorDirty) {
      // Caller should confirm; still allow force via discard+open.
    }
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

  Future<void> sendChat(String userText) async {
    final text = userText.trim();
    if (text.isEmpty || chatBusy) return;

    chat.add(ChatMessage(role: ChatRole.user, content: text));
    chatBusy = true;
    chatError = null;
    notifyListeners();

    try {
      final reply = await _ollama.chat(
        baseUrl: settings.ollamaBaseUrl,
        model: settings.modelName,
        systemPrompt: settings.systemPrompt,
        history: chat
            .where((m) =>
                m.role == ChatRole.user || m.role == ChatRole.assistant)
            .toList(),
      );
      final parsed = AgentParser.parse(reply);
      chat.add(
        ChatMessage(
          role: ChatRole.assistant,
          content: parsed.displayText,
          draftBundle: parsed.draft,
        ),
      );
      if (parsed.draft != null && parsed.draft!.isNotEmpty) {
        pendingDraft = parsed.draft;
      }
      ollamaOnline = true;
    } catch (e) {
      chatError = e.toString();
      chat.add(ChatMessage(role: ChatRole.error, content: e.toString()));
      ollamaOnline = false;
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
    final written = await v.approveDrafts(draft);
    pendingDraft = null;
    await refreshVault();
    chat.add(
      ChatMessage(
        role: ChatRole.system,
        content: 'Утверждено и записано: ${written.join(', ')}',
      ),
    );
    notifyListeners();
    return written;
  }

  void rejectPendingDraft() {
    if (pendingDraft == null) return;
    chat.add(
      ChatMessage(
        role: ChatRole.system,
        content: 'Черновик отклонён. Vault не изменён.',
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
    _ollama.dispose();
    super.dispose();
  }
}
