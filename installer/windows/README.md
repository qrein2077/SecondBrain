# Windows installer (Inno Setup)

Produces `SecondBrain-Setup-<version>.exe` from the Flutter Windows **Release** build.

| File | Role |
|------|------|
| `SecondBrain.iss` | Inno Setup 6 script |
| `../../scripts/windows/build_installer.ps1` | Local one-shot build on Windows |
| `../../.github/workflows/windows-installer.yml` | CI on `windows-latest` → Actions artifact |

## Local (Windows)

1. Install [Flutter](https://docs.flutter.dev/get-started/install/windows/desktop) + VS 2022 Desktop C++.
2. Install [Inno Setup 6](https://jrsoftware.org/isinfo.php) (or `choco install innosetup`).
3. From repo root in PowerShell:

```powershell
.\scripts\windows\build_installer.ps1
```

Output: `dist\SecondBrain-Setup-1.0.0.exe` (version from `pubspec.yaml`).

## CI

Every push/PR run uploads artifact **SecondBrain-Setup-Windows**.  
User flow: Actions → latest successful run → Artifacts → download → run setup.

## Settings survival

Preferences live in `%APPDATA%\com.qrein.secondbrain\SecondBrain\` (Flutter `shared_preferences`).  
The installer/uninstaller does **not** delete AppData, so vault path / Ollama URL / model / system prompt survive updates.
