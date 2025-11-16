<#
collect_and_fix_build_logs.ps1

This script collects build logs for the Flutter Android build and attempts safe quick fixes.

Usage: run from any PowerShell prompt in the repo root (no admin required):
  Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force
  .\scripts\collect_and_fix_build_logs.ps1

Outputs (written to repo root):
- flutter_build_verbose.log
- gradle_assembleRelease.log
- gradle_assemble_after_clean.log

It will:
- Run `flutter build apk --release -v` and save verbose output
- Run `gradlew assembleRelease --stacktrace --info` and save output
- Run `flutter clean` + `flutter pub get`
- Remove local Gradle caches (.gradle and android/app/build) and re-run gradle assemble
- Print the last 200 lines of each log to the console

NOTE: The script does not modify `android/` except removing build caches. If you prefer backups of .gradle, the script renames .gradle to .gradle.bak_<timestamp> instead of deleting.
#>

function Write-Log { param($m) Write-Host "[collect] $m" }

# Resolve repository root robustly: parent of the script's folder (scripts/..),
# or fallback to current working directory if needed.
$repoRoot = $null
try {
    $scriptPath = $MyInvocation.MyCommand.Path
    if ($scriptPath) {
        $scriptDir = Split-Path -Path $scriptPath -Parent
        $repoRoot = Split-Path -Path $scriptDir -Parent
        if (-not $repoRoot -or $repoRoot -eq '') { $repoRoot = (Get-Location).Path }
    } else {
        $repoRoot = (Get-Location).Path
    }
} catch {
    $repoRoot = (Get-Location).Path
}

Set-Location $repoRoot
Write-Log "Repository root: $repoRoot"

$mobileFlutter = Join-Path $repoRoot 'mobile-flutter'
$androidDir = Join-Path $mobileFlutter 'android'

if (-not (Test-Path $mobileFlutter)) { Write-Log "mobile-flutter folder not found at $mobileFlutter"; exit 1 }

# 1) Flutter verbose build (writes to repo root)
$flutterLog = Join-Path $repoRoot 'flutter_build_verbose.log'
Write-Log "Running: flutter build apk --release -v in mobile-flutter (this may take several minutes)"
if (Test-Path $mobileFlutter) {
    try {
        Set-Location $mobileFlutter
        & flutter build apk --release -v > $flutterLog 2>&1
    } catch {
        Write-Log "flutter command failed or not found. Ensure Flutter is installed and in PATH. Error: $_"
    }
    finally {
        Set-Location $repoRoot
    }
} else {
    Write-Log "mobile-flutter folder not found at $mobileFlutter; skipping flutter build."
}

if (Test-Path $flutterLog) {
    Write-Log "flutter verbose log written to $flutterLog"
    Write-Log "Last 200 lines of flutter log:"
    Get-Content $flutterLog -Tail 200 | ForEach-Object { Write-Host $_ }
} else {
    Write-Log "flutter verbose log not created. Skipping display."
}

# 2) Gradle assembleRelease (android dir)
if (-not (Test-Path $androidDir)) { Write-Log "android folder not found at $androidDir"; exit 1 }
Set-Location $androidDir

$gradleLog = Join-Path $repoRoot 'gradle_assembleRelease.log'
Write-Log "Running: gradlew assembleRelease --stacktrace --info"
# Check for java first
$javaCmd = Get-Command java -ErrorAction SilentlyContinue
if (-not $javaCmd) {
    Write-Log "JAVA not found in PATH. Skipping gradle assemble. Please install JDK and set JAVA_HOME."
} else {
    if (Test-Path '.\gradlew.bat') {
        & .\gradlew.bat assembleRelease --stacktrace --info > $gradleLog 2>&1
    } else {
        Write-Log "gradlew.bat not found in $androidDir. Ensure the Android project has a Gradle wrapper."
    }
}

if (Test-Path $gradleLog) {
    Write-Log "gradle assemble log written to $gradleLog"
    Write-Log "Last 200 lines of gradle log:"
    Get-Content $gradleLog -Tail 200 | ForEach-Object { Write-Host $_ }
} else {
    Write-Log "gradle log not created. Skipping display."
}

# 3) Quick fixes: flutter clean + pub get
Set-Location $mobileFlutter
Write-Log "Running flutter clean and flutter pub get"
try {
    & flutter clean
    & flutter pub get
} catch { Write-Log "flutter commands failed: $_" }

# 4) Remove Gradle caches (rename to backup) and remove android/app/build
Set-Location $androidDir
$timestamp = Get-Date -Format 'yyyyMMddHHmmss'
if (Test-Path '.gradle') {
    $backupGradle = ".gradle.bak_$timestamp"
    Write-Log "Renaming .gradle to $backupGradle"
    Rename-Item -Path '.gradle' -NewName $backupGradle -Force
}
if (Test-Path 'app\build') {
    Write-Log "Removing app\build"
    Remove-Item -Path 'app\build' -Recurse -Force
}

# 5) Re-run gradle assembleRelease
$gradleAfterLog = Join-Path $repoRoot 'gradle_assemble_after_clean.log'
Write-Log "Re-running: gradlew assembleRelease --stacktrace --info"
if (Test-Path '.\gradlew.bat') {
    & .\gradlew.bat assembleRelease --stacktrace --info > $gradleAfterLog 2>&1
} else {
    Write-Log "gradlew.bat still not found; cannot run gradle assemble."
}

if (Test-Path $gradleAfterLog) {
    Write-Log "gradle after-clean log written to $gradleAfterLog"
    Write-Log "Last 200 lines of after-clean gradle log:"
    Get-Content $gradleAfterLog -Tail 200 | ForEach-Object { Write-Host $_ }
} else {
    Write-Log "after-clean gradle log not created. Skipping display."
}

Write-Log "Script finished. Please attach the three logs from the repo root if you need further help:"
Write-Host "  - flutter_build_verbose.log"
Write-Host "  - gradle_assembleRelease.log"
Write-Host "  - gradle_assemble_after_clean.log"
