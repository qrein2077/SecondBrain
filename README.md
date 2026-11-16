# SecondBrain

Local-first AI companion for an Obsidian vault (Windows + Android).  
Default LLM is **local Ollama (Qwen2.5)**; optional **Google Gemini** (AI Studio) via cloud / auto modes.  
The app **never writes** to the vault until you **Approve** a draft preview. Remotely Save is left alone.

**English (short):** Download `SecondBrain-Setup-*.exe` from [Actions](https://github.com/qrein2077/SecondBrain/actions/workflows/windows-installer.yml) → install → Ollama + `qwen2.5:7b` (default). Optional: paste Gemini API key in Settings, pick model, switch mode to cloud/auto. Update = new setup.exe. Flutter-from-source is advanced (Russian below).

---

## Возможности (MVP)

- Выбор локальной папки Obsidian vault
- Список `.md`, редактор Markdown + превью, ручное сохранение
- Один универсальный агент (редактируемый system prompt)
- LLM: **Ollama** по умолчанию (`qwen2.5:7b`) + опционально **Gemini** (режимы local / cloud / auto)
- Предложение создать/обновить одну или несколько связанных заметок (`[[wiki-links]]`) → превью → **Утвердить все / Отклонить все**
- Базовые русские подписи в UI
- Windows-установщик (Inno Setup) + сборка в GitHub Actions

**Пока не входит:** Whisper/STT, Tailscale, RAG, мульти-агенты, полировка Android.

---

## Установка через установщик (рекомендуется)

Обычному пользователю **не нужно** ставить Flutter и каждый раз собирать проект. Сборка делается в CI (или один раз у разработчика); вы только скачиваете и запускаете новый setup.

### Честно про обновления

| Кто | Что делает |
|-----|------------|
| **Вы (день за днём)** | Скачиваете новый `SecondBrain-Setup-*.exe` → запускаете → приложение обновляется в Program Files (или выбранной папке). Flutter не нужен. |
| **CI / разработчик** | На каждый push в PR/`main` GitHub Actions на Windows собирает Flutter Release + Inno Setup и кладёт артефакт. |

### 1. LLM: Ollama (по умолчанию) и/или Gemini (опционально)

Установщик SecondBrain **не** включает модели — только UI-клиент.

**Рекомендуемый путь (локально):**

1. Установите [Ollama для Windows](https://ollama.com)
2. Скачайте модель:

```bat
ollama pull qwen2.5:7b
```

3. Проверьте: `http://127.0.0.1:11434` отвечает.

**Опционально — Google Gemini** (если хотите cloud / auto): см. [Gemini (Google AI Studio)](#gemini-google-ai-studio) ниже. Без ключа достаточно режима «Локально (Ollama)».

### 2. Скачать установщик из GitHub Actions

1. Откройте workflow: [Windows installer](https://github.com/qrein2077/SecondBrain/actions/workflows/windows-installer.yml)
2. Выберите **успешный** прогон (зелёная галочка) для нужной ветки / PR #1
3. Внизу страницы прогона → **Artifacts** → **SecondBrain-Setup-Windows**
4. Распакуйте zip артефакта → запустите `SecondBrain-Setup-1.0.0.exe` (версия из `pubspec.yaml`)

Пока PR #1 не влит, берите прогон с ветки `cursor/windows-vault-chat-shell-77ba` / pull request. После merge — прогоны с `main`.

> Артефакты Actions хранятся ограниченное время (сейчас ~30 дней). Позже можно публиковать GitHub Releases с тем же `.exe`.

### 3. Установка и обновление

1. Запустите setup → при желании смените папку (по умолчанию под Program Files / user install).
2. Язык мастера: English / **Русский**.
3. **Обновление:** скачайте новый setup и установите поверх (тот же `AppId`). Старую версию вручную сносить не обязательно.
4. **Настройки не сбрасываются** при переустановке: vault path, URL Ollama, модель и system prompt лежат в  
   `%APPDATA%\com.qrein.secondbrain\SecondBrain\`  
   (Flutter `shared_preferences`). Деинсталлятор **не** удаляет AppData.

### 4. Первый запуск после установки

1. Запустите **SecondBrain** из меню Пуск.
2. **Настройки** (шестерёнка): папка vault → режим LLM (**Локально** по умолчанию) → Ollama URL `http://127.0.0.1:11434` → модель `qwen2.5:7b` → при необходимости Gemini (ключ + модель) → **Сохранить**.
3. Чат и редактор — как в MVP. Запись в vault только после **Утвердить все**.

### Сборка установщика у себя (опционально)

Нужны Flutter + VS 2022 Desktop C++ + [Inno Setup 6](https://jrsoftware.org/isinfo.php) (или `choco install innosetup`).

```powershell
.\scripts\windows\build_installer.ps1
```

Результат: `dist\SecondBrain-Setup-<version>.exe`  
Скрипт: [`scripts/windows/build_installer.ps1`](scripts/windows/build_installer.ps1) · ISS: [`installer/windows/SecondBrain.iss`](installer/windows/SecondBrain.iss) · CI: [`.github/workflows/windows-installer.yml`](.github/workflows/windows-installer.yml)

---

## Gemini (Google AI Studio)

Опциональный облачный backend. Vault по-прежнему local-first; в облако уходит текст чата (промпт + история), не «весь диск». Черновики `.md` пишутся локально только после Approve.

### Как получить бесплатный API-ключ

1. Откройте [Google AI Studio](https://aistudio.google.com/) и войдите в Google-аккаунт.
2. **Get API key** / [API keys](https://aistudio.google.com/apikey) → создайте ключ.
3. Скопируйте ключ (обычно `AIza…`). **Не коммитьте** в git и не кладите в vault.

### Настройка в SecondBrain

1. **Настройки** → блок **Облако — Google Gemini**
2. Вставьте API-ключ (хранится в защищённом хранилище ОС через `flutter_secure_storage`).
3. Укажите **модель вручную**:

| Модель | Зачем |
|--------|--------|
| `gemini-2.5-flash` | **Default** — быстрый free-tier-ориентир |
| `gemini-2.5-pro` | Качественнее, медленнее |
| `gemini-3.8-flash` | Более новый flash (если доступен вашему ключу) |

Имена — как в [OpenAI-compat docs](https://aistudio.google.com/docs/openai). При «model not found» смените тег.

4. Режим LLM: **Локально** (default) / **Облако (Gemini)** / **Авто (Ollama → Gemini)**.
5. **Сохранить** → в чате строка «Ответ через Ollama/Gemini» покажет backend.

Технически: `POST https://generativelanguage.googleapis.com/v1beta/openai/chat/completions` + `Authorization: Bearer <key>`. Multi-file `<<<PROPOSE_NOTES>>>` + Approve одинаковы для обоих backends.

---

## Сборка из исходников (для разработчиков)

Если хотите править код и запускать без установщика — ставьте toolchain ниже. Для простого использования достаточно раздела **«Установка через установщик»**.

### 0. Что понадобится

| Компонент | Зачем |
|-----------|--------|
| **Git** | Клонировать репозиторий |
| **Flutter (stable)** | Сборка и запуск приложения |
| **Visual Studio 2022** с workload **Desktop development with C++** | Компиляция Windows desktop |
| **Ollama** | Локальный LLM по умолчанию |
| **(опц.) ключ Gemini** | Cloud / auto режимы через Google AI Studio |
| Модель **`qwen2.5:7b`** | Default chat (Qwen2.5 7B–8B Q4/Q5) |
| Папка **Obsidian vault** | Локальная копия заметок (как у Remotely Save) |

Железо (ориентир проекта): 32 GB RAM + RTX 5060 Ti; приложение держит concurrency = 1, чтобы не грузить ПК.

---

### 1. Установите Git

1. Скачайте установщик: [https://git-scm.com/download/win](https://git-scm.com/download/win)
2. Установите с настройками по умолчанию (достаточно).
3. Проверьте в **PowerShell** или **cmd**:

```bat
git --version
```

Должна появиться версия Git.

---

### 2. Установите Flutter (канал stable)

1. Откройте официальную инструкцию: [Install Flutter on Windows](https://docs.flutter.dev/get-started/install/windows/desktop)
2. Скачайте **Flutter SDK (stable)** и распакуйте, например в `C:\src\flutter`  
   (путь **без** пробелов и без необходимости прав администратора для каждой сборки — удобнее).
3. Добавьте в **PATH** пользователя: `C:\src\flutter\bin` (свой путь).
4. Закройте и заново откройте терминал, затем:

```bat
flutter --version
```

Убедитесь, что канал **stable**. При необходимости:

```bat
flutter channel stable
flutter upgrade
```

---

### 3. Visual Studio 2022 — Desktop development with C++

Flutter для Windows требует toolchain Visual Studio (не только VS Code).

1. Установите [Visual Studio 2022](https://visualstudio.microsoft.com/downloads/) (Community достаточно).
2. В Visual Studio Installer отметьте workload:

   **Desktop development with C++**

3. В деталях workload обычно нужны (если не включились сами):

   - MSVC v143 (или актуальный) toolset  
   - Windows 10/11 SDK  
   - CMake tools for Windows  

4. Перезапустите терминал после установки.

Документация Flutter: [Windows desktop requirements](https://docs.flutter.dev/platform-integration/windows/setup).

---

### 4. Проверка окружения — `flutter doctor`

```bat
flutter doctor
flutter doctor -v
```

Ожидаемо для этого MVP:

- **Flutter** — без критических ошибок  
- **Visual Studio** — найден, с C++ desktop  
- **Windows** / desktop — готов к разработке  
- **Android toolchain** — можно игнорировать на первом этапе (Android в проекте есть, но фокус — Windows)  
- **Chrome** / сеть — не обязательны для desktop

Если `flutter doctor` ругается — см. раздел [Устранение неполадок](#устранение-неполадок).

Включите desktop (если ещё не включён):

```bat
flutter config --enable-windows-desktop
flutter devices
```

В списке устройств должен быть **Windows (desktop)**.

---

### 5. Установите Ollama и скачайте модель

1. Скачайте Ollama для Windows: [https://ollama.com](https://ollama.com)  
2. Установите и убедитесь, что служба/приложение запущено (иконка в трее или процесс `ollama`).
3. В терминале:

```bat
ollama --version
ollama pull qwen2.5:7b
```

Проверка, что API отвечает локально:

```bat
curl http://127.0.0.1:11434/api/tags
```

или откройте в браузере: `http://127.0.0.1:11434` — должен ответить Ollama.

**По умолчанию** используется локальный Ollama. Gemini — **opt-in** (ключ в защищённом хранилище устройства, не в vault/git). Можно оставить только Ollama.

Если тег `qwen2.5:7b` недоступен, подтяните ближайший Q4/Q5 вариант, например:

```bat
ollama pull qwen2.5:7b-instruct-q5_K_M
```

и укажите **точный** тег в настройках приложения.

Чтобы не грузить ПК: не держите несколько больших моделей загруженными одновременно; в приложении уже очередь на **1** активную генерацию.

---

### 6. Получите код репозитория

#### Сейчас (пока PR #1 не влит в `main`)

Код MVP живёт в pull request: [https://github.com/qrein2077/SecondBrain/pull/1](https://github.com/qrein2077/SecondBrain/pull/1)

**Вариант A — клон + checkout PR-ветки:**

```bat
git clone https://github.com/qrein2077/SecondBrain.git
cd SecondBrain
git fetch origin pull/1/head:pr-1
git checkout pr-1
```

**Вариант B — уже клонировали `main`:**

```bat
cd SecondBrain
git fetch origin pull/1/head:pr-1
git checkout pr-1
```

**Вариант C — ветка агента напрямую:**

```bat
git clone -b cursor/windows-vault-chat-shell-77ba https://github.com/qrein2077/SecondBrain.git
cd SecondBrain
```

#### После merge в `main`

Упростится до обычного клона:

```bat
git clone https://github.com/qrein2077/SecondBrain.git
cd SecondBrain
```

или, если репозиторий уже есть:

```bat
git checkout main
git pull origin main
```

---

### 7. Зависимости и запуск

В каталоге проекта:

```bat
flutter pub get
flutter run -d windows
```

Первая сборка Windows может занять несколько минут (CMake / MSVC). Повторные запуски быстрее.

Альтернатива: открыть проект в IDE и выбрать устройство **Windows**, затем Run.

Проверки без GUI:

```bat
flutter analyze
flutter test
```

---

### 8. Первый запуск — настройки

1. В шапке приложения нажмите **шестерёнку** → **Настройки**.
2. **Путь к папке vault** → **Обзор…** (корень Obsidian vault; Remotely Save не трогаем).
3. **Режим LLM:** Локально / Облако / Авто (default — Локально).
4. **Ollama:** URL `http://127.0.0.1:11434`, модель `qwen2.5:7b`.
5. **(Опц.) Gemini:** API-ключ + модель (`gemini-2.5-flash` и т.д.).
6. System prompt при желании → **Сохранить**.

Дальше: список `.md` / редактор слева; чат справа (индикатор Ollama/Gemini).

---

### 9. Запись в vault только после Approve

Агент **не** пишет файлы сам (ни через Ollama, ни через Gemini). Он предлагает пакет `.md` + `[[wiki-links]]`.

1. Баннер/кнопка **Пакет N файл.**
2. Превью: список путей + Markdown.
3. **Отклонить все** — vault не меняется.  
4. **Утвердить все** — пакетная запись (`temp` → rename) **только** внутрь vault.

Ручное сохранение открытой заметки в редакторе — отдельное явное действие пользователя (**Сохранить**).

---

## Устранение неполадок

### `flutter doctor` — Visual Studio / toolchain

| Симптом | Что сделать |
|---------|-------------|
| Visual Studio not found / incomplete | Установите VS 2022 + workload **Desktop development with C++**, перезапустите терминал, снова `flutter doctor -v` |
| Missing Windows SDK / MSVC | В Installer → Modify → отметьте Windows 10/11 SDK и MSVC C++ build tools |
| `flutter devices` без Windows | `flutter config --enable-windows-desktop`, перелогиньтесь в терминал |
| PATH / `flutter` не находится | Добавьте `...\flutter\bin` в PATH пользователя, новый терминал |

Полезные ссылки: [Flutter Windows install](https://docs.flutter.dev/get-started/install/windows/desktop), [Windows setup](https://docs.flutter.dev/platform-integration/windows/setup).

### Ollama: connection refused / offline в приложении

1. Запущено ли Ollama (трей / службы Windows)?
2. Проверьте: `curl http://127.0.0.1:11434/api/tags`
3. В настройках URL должен быть именно `http://127.0.0.1:11434` (без лишнего слэша в конце — приложение обычно нормализует).
4. Firewall: для localhost обычно не мешает; если меняли порт Ollama — укажите тот же порт в приложении.
5. После старта Ollama нажмите в чате проверку связи (иконка сети).

### Неверная модель / тег

```bat
ollama list
```

Тег в **Настройки → Модель** должен **точно** совпадать с именем из списка (например `qwen2.5:7b`).  
Если pull другого варианта — обновите поле модели и сохраните настройки.

Ошибка вроде «model not found» в чате = тег не скачан или опечатка.

### Vault: пустой список / «нет .md»

1. В настройках выбран **корень** vault (там, где лежат заметки и часто папка `.obsidian`), а не случайная подпапка без markdown.
2. Файлы должны иметь расширение `.md`. Скрытые каталоги (`.obsidian` и т.п.) приложение пропускает намеренно.
3. Нажмите **Обновить** в панели Vault.
4. Права доступа: папка должна читаться вашим пользователем Windows.

### Сборка `flutter run -d windows` падает

- Дождитесь окончания первой генерации CMake; смотрите лог на MSVC / SDK.
- Закройте антивирус на время первой сборки, если он блокирует `build\windows`.
- `flutter clean` → `flutter pub get` → `flutter run -d windows`.

### Установщик / настройки пропали

- Настройки должны жить в `%APPDATA%\com.qrein.secondbrain\SecondBrain\` — переустановка setup **не** должна их стирать.
- Если «всё с нуля» после смены пользователя Windows или очистки Roaming — заново укажите vault в Настройках.
- Антивирус иногда блокирует свежий setup из Actions (неподписанный). Разрешите файл или «Разблокировать» в свойствах `.exe`.

### После merge

Когда [#1](https://github.com/qrein2077/SecondBrain/pull/1) вольют в `main`, больше не нужен `git fetch origin pull/1/head:pr-1` — достаточно `git clone` / `git pull` с `main` (см. выше). Установщик берите из Actions на `main`.

---

## Заметки для разработки

- Репозиторий можно править на Linux, но **Windows Release + Inno Setup** собираются на **Windows** (локально или GitHub Actions `windows-latest`).
- Установщик: `installer/windows/SecondBrain.iss`, скрипт `scripts/windows/build_installer.ps1`, workflow `.github/workflows/windows-installer.yml`.
- Android-таргет включён (`android/`); полировка телефона и SAF — позже.
- Формат предложения заметок агентом описан в system prompt (`<<<PROPOSE_NOTES>>>` … `<<<END_PROPOSE_NOTES>>>`).

## Лицензия

Личный проект, если не указано иное.
