# SecondBrain

Local-first AI companion for an Obsidian vault (Windows + Android).  
Chat with a single universal agent via **local Ollama** only — no cloud LLM APIs.  
The app never writes to the vault until you **Approve** a draft preview.

Remotely Save / Cloud.Mail sync is left alone: SecondBrain only reads/writes the local vault folder you pick.

## Features (MVP slice)

- Pick a local Obsidian vault folder
- Browse `.md` notes, edit Markdown + live preview, manual save
- Chat with one agent (editable persistent system prompt)
- Ollama OpenAI-compatible API (`/v1/chat/completions`), default model `qwen2.5:7b`
- When the agent proposes note create/update (single or multi-file + `[[wiki-links]]`): draft preview → **Approve / Reject** → atomic write (`temp` + rename) only on Approve
- Russian UI labels

Out of scope for this PR: Whisper/STT, Tailscale, RAG embeddings, multi-agent.

## What you need to install

1. **Flutter** (stable) — [https://docs.flutter.dev/get-started/install](https://docs.flutter.dev/get-started/install)  
   Enable the **Windows** desktop toolchain (Visual Studio with “Desktop development with C++”).
2. **Ollama** for Windows — [https://ollama.com](https://ollama.com)
3. Pull the default chat model (Qwen2.5 7B quantized):

```bat
ollama pull qwen2.5:7b
```

Optional closer tags if `qwen2.5:7b` is unavailable: `qwen2.5:7b-instruct-q5_K_M` / `qwen2.5:7b-instruct-q4_K_M`. Set the exact tag in **Настройки**.

Keep PC load light: one chat generation at a time (app enforces concurrency 1). Prefer not to keep several large models loaded.

## Run on Windows

```bat
git clone https://github.com/qrein2077/SecondBrain.git
cd SecondBrain
flutter pub get
flutter run -d windows
```

Then:

1. Open **Настройки** (gear icon)
2. **Обзор…** → select your Obsidian vault folder
3. Confirm Ollama URL `http://127.0.0.1:11434` and model `qwen2.5:7b`
4. Save → use vault list / editor / chat

Android target is enabled in the project (`android/`). Phone polish and SAF vault access are later; this PR prioritizes the Windows shell.

## Agent note drafts

The default system prompt asks the model to append:

```text
<<<PROPOSE_NOTES>>>
[
  {"path": "relative/note.md", "op": "create", "content": "# Title\n\n[[link]]"}
]
<<<END_PROPOSE_NOTES>>>
```

The UI strips that block from chat text and opens a draft preview. Vault files change only after **Утвердить**.

## Develop / analyze

```bat
flutter analyze
flutter test
```

### Cloud / Linux agents

This repository can be developed on Linux, but **Windows desktop binaries must be built on Windows** (or CI with a Windows runner). Android SDK is optional for this MVP slice.

## License

Private project for personal use unless otherwise stated.
