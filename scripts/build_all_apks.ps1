<# 
PowerShell script to build both Flutter and React Native (Expo) APKs locally.

Preconditions: Run after running `setup_android_flutter_env.ps1` and after restarting PowerShell so PATH changes apply.
Usage:
1) Open PowerShell (not necessarily admin) and ensure environment variables are loaded (or restart shell)
2) From repository root run: .\scripts\build_all_apks.ps1

What it does:
- Builds Flutter APK: runs `flutter pub get` and `flutter build apk --release` in `mobile-flutter`
- Builds Expo (managed) APK locally: uses `npx expo prebuild --platform android` then runs Gradle assembleRelease in created `android` dir.

Notes:
- For Expo local build, this runs a local Android build and requires Android SDK + JDK available and configured.
- For production release signing, you should provide a release keystore and update `android/gradle.properties` / `key.properties` accordingly. This script will produce an unsigned release APK by default unless you configure signing.
#>

function Write-Log { param($m) Write-Host "[build] $m" }

Write-Log "Starting build for both apps..."

# Resolve script root robustly (fallback if $PSScriptRoot is empty)
$ScriptRoot = $PSScriptRoot
if (-not $ScriptRoot -or $ScriptRoot -eq '') {
    try {
        $ScriptRoot = Split-Path -Path $MyInvocation.MyCommand.Path -Parent
    } catch {
        $ScriptRoot = (Get-Location).Path
    }
}

Write-Log "Using script root: $ScriptRoot"

# --- Flutter build
$flutterProject = Join-Path $ScriptRoot "..\mobile-flutter"
if (Test-Path $flutterProject) {
    Write-Log "Building Flutter APK..."
    Push-Location $flutterProject
    & flutter pub get
    & flutter build apk --release
    Pop-Location
    Write-Log "Flutter build finished. APK(s) located under mobile-flutter\build\app\outputs\flutter-apk\"
} else {
    Write-Log "mobile-flutter folder not found; skipping Flutter build. Expected at: $flutterProject"
}

# --- Expo (React Native) local build
$expoProject = Join-Path $ScriptRoot "..\mobile-reactnative"
if (Test-Path $expoProject) {
    Write-Log "Building Expo (React Native) local Android APK via prebuild + Gradle..."
    Push-Location $expoProject
    Write-Log "Installing npm deps..."
    npm install

    Write-Log "Running expo prebuild (this will generate android folder)..."
    npx expo prebuild --platform android --no-install

    $androidDir = Join-Path $expoProject "android"
    if (Test-Path $androidDir) {
        Push-Location $androidDir
        Write-Log "Invoking Gradle assembleRelease..."
        if (Test-Path "gradlew.bat") {
            & .\gradlew.bat assembleRelease
        } else {
            Write-Log "gradlew.bat not found. Ensure Android project exists and Gradle wrapper available."
        }
        Pop-Location
        Write-Log "Expo Android build finished. Look under mobile-reactnative\android\app\build\outputs\apk\release\"
    } else {
        Write-Log "Android prebuild did not generate android folder; check expo diagnostics."
    }
    Pop-Location
} else {
    Write-Log "mobile-reactnative folder not found; skipping Expo build. Expected at: $expoProject"
}

Write-Log "Build script finished."
