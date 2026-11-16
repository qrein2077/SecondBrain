; SecondBrain Windows installer (Inno Setup 6)
; Packs the Flutter Windows Release folder into a setup .exe.
;
; Build prerequisites:
;   1) flutter build windows --release
;   2) Inno Setup 6 (ISCC.exe)
; Or run: scripts\windows\build_installer.ps1
;
; App settings (vault path, Ollama URL, model, system prompt) are stored by
; Flutter shared_preferences under %APPDATA%\com.qrein.secondbrain\SecondBrain\
; and are NOT deleted on uninstall/upgrade so reinstall keeps preferences.

#define MyAppName "SecondBrain"
#define MyAppVersion "1.0.0"
#define MyAppPublisher "qrein2077"
#define MyAppExeName "secondbrain.exe"
#ifndef SourceDir
  #define SourceDir "..\..\build\windows\x64\runner\Release"
#endif
#ifndef OutputDir
  #define OutputDir "..\..\dist"
#endif

[Setup]
; Stable GUID — keep forever so upgrades replace the same install.
AppId={{A7C3E2F1-9B4D-4E6A-8C21-2F0D5B7A91E3}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppVerName={#MyAppName} {#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL=https://github.com/qrein2077/SecondBrain
AppSupportURL=https://github.com/qrein2077/SecondBrain
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
AllowNoIcons=yes
; User can pick another folder.
DisableDirPage=no
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
OutputDir={#OutputDir}
OutputBaseFilename=SecondBrain-Setup-{#MyAppVersion}
Compression=lzma
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
UninstallDisplayIcon={app}\{#MyAppExeName}
CloseApplications=yes
RestartApplications=no
; Do not touch %APPDATA% — settings must survive reinstall.
SetupLogging=yes

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"
Name: "russian"; MessagesFile: "compiler:Languages\Russian.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
; Entire Flutter Release bundle (exe + DLLs + data\).
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{group}\{cm:UninstallProgram,{#MyAppName}}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent

[Code]
// Intentionally no [UninstallDelete] for AppData — preferences survive.
function InitializeSetup(): Boolean;
begin
  Result := True;
end;
