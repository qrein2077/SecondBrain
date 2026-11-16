<#
.SYNOPSIS
  Build SecondBrain Flutter Windows Release and pack an Inno Setup installer.

.DESCRIPTION
  Run on Windows with Flutter + Visual Studio C++ toolchain installed.
  Optionally installs/uses Inno Setup 6 (ISCC.exe) to produce
  dist\SecondBrain-Setup-<version>.exe

.PARAMETER SkipFlutterBuild
  Skip `flutter build windows --release` (use an existing Release folder).

.PARAMETER SkipInno
  Only build Flutter; do not compile the .iss installer.

.PARAMETER InnoSetupPath
  Path to ISCC.exe if not on PATH / default install location.

.EXAMPLE
  .\scripts\windows\build_installer.ps1
#>
[CmdletBinding()]
param(
  [switch]$SkipFlutterBuild,
  [switch]$SkipInno,
  [string]$InnoSetupPath = ""
)

$ErrorActionPreference = "Stop"

$RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
Set-Location $RepoRoot

$ReleaseDir = Join-Path $RepoRoot "build\windows\x64\runner\Release"
$IssFile = Join-Path $RepoRoot "installer\windows\SecondBrain.iss"
$DistDir = Join-Path $RepoRoot "dist"
$Pubspec = Join-Path $RepoRoot "pubspec.yaml"

function Get-AppVersion {
  $line = Select-String -Path $Pubspec -Pattern '^version:\s*([0-9]+\.[0-9]+\.[0-9]+)' | Select-Object -First 1
  if (-not $line) { return "1.0.0" }
  return $line.Matches[0].Groups[1].Value
}

$Version = Get-AppVersion
Write-Host "==> SecondBrain installer build (version $Version)" -ForegroundColor Cyan
Write-Host "    Repo: $RepoRoot"

if (-not $SkipFlutterBuild) {
  Write-Host "==> flutter pub get" -ForegroundColor Cyan
  flutter pub get
  if ($LASTEXITCODE -ne 0) { throw "flutter pub get failed" }

  Write-Host "==> flutter build windows --release" -ForegroundColor Cyan
  flutter build windows --release
  if ($LASTEXITCODE -ne 0) { throw "flutter build windows failed" }
} else {
  Write-Host "==> Skipping Flutter build" -ForegroundColor Yellow
}

if (-not (Test-Path (Join-Path $ReleaseDir "secondbrain.exe"))) {
  throw "Release binary not found: $ReleaseDir\secondbrain.exe — run without -SkipFlutterBuild"
}

if ($SkipInno) {
  Write-Host "==> Flutter Release ready at: $ReleaseDir" -ForegroundColor Green
  Write-Host "    Skipping Inno Setup (-SkipInno)."
  exit 0
}

function Find-ISCC {
  param([string]$Explicit)
  if ($Explicit -and (Test-Path $Explicit)) { return $Explicit }
  $cmd = Get-Command "ISCC.exe" -ErrorAction SilentlyContinue
  if ($cmd) { return $cmd.Source }
  $candidates = @(
    "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe",
    "${env:ProgramFiles}\Inno Setup 6\ISCC.exe",
    "${env:LOCALAPPDATA}\Programs\Inno Setup 6\ISCC.exe"
  )
  foreach ($c in $candidates) {
    if (Test-Path $c) { return $c }
  }
  return $null
}

$iscc = Find-ISCC -Explicit $InnoSetupPath
if (-not $iscc) {
  Write-Host "==> Inno Setup 6 not found. Install from https://jrsoftware.org/isinfo.php" -ForegroundColor Yellow
  Write-Host "    Or: choco install innosetup -y"
  Write-Host "    Flutter Release is ready at: $ReleaseDir"
  Write-Host "    Re-run this script after installing Inno Setup."
  exit 2
}

New-Item -ItemType Directory -Force -Path $DistDir | Out-Null

Write-Host "==> Compiling installer with: $iscc" -ForegroundColor Cyan
& $iscc `
  "/DMyAppVersion=$Version" `
  "/DSourceDir=$ReleaseDir" `
  "/DOutputDir=$DistDir" `
  $IssFile
if ($LASTEXITCODE -ne 0) { throw "ISCC failed with exit $LASTEXITCODE" }

$setup = Get-ChildItem -Path $DistDir -Filter "SecondBrain-Setup-*.exe" |
  Sort-Object LastWriteTime -Descending |
  Select-Object -First 1

Write-Host "==> Done." -ForegroundColor Green
Write-Host "    Installer: $($setup.FullName)"
Write-Host "    Settings survive reinstall under:"
Write-Host "      %APPDATA%\com.qrein.secondbrain\SecondBrain\"
Write-Host "    Day-to-day: download/run the new setup .exe — no flutter build needed."
