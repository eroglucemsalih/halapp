<#
fix_java_home_and_build_apk.ps1

Automatic helper to:
- ensure JDK17 is present (runs install_jdk17_and_setup.ps1 if needed)
- find a valid JDK17 installation and set User-scoped JAVA_HOME + PATH
- remove known-bad PATH entries (Oracle Common Files x86)
- run the existing `collect_and_fix_build_logs.ps1` to build the APK and collect logs
- if an APK is produced, copy it to repo root `build_outputs/` for easy retrieval

Run as Administrator for best results.
#>

function Write-Log { param($m) Write-Host "[fix-java] $m" }

$scriptRoot = $PSScriptRoot
$repoRoot = Resolve-Path (Join-Path $scriptRoot '..') | Select-Object -ExpandProperty Path

Write-Log "Repository root: $repoRoot"

# Helper: get java version string (returns null if not found)
function Get-JavaVersionString {
    $j = Get-Command java -ErrorAction SilentlyContinue
    if ($null -eq $j) { return $null }
    try {
        $out = & java -version 2>&1 | Out-String
        return $out.Trim()
    } catch {
        return $null
    }
}

# 1) Check current java
$verOut = Get-JavaVersionString
if ($verOut) {
    Write-Log "Detected java -version output:`n$verOut"
} else {
    Write-Log "No java command found on PATH. Will attempt to install Temurin JDK 17."
}

# If java not present or not 17, run installer script
$needInstall = $false
if (-not $verOut) { $needInstall = $true } elseif ($verOut -notmatch 'version "17') { $needInstall = $true }

if ($needInstall) {
    Write-Log "Attempting to run install_jdk17_and_setup.ps1 (may prompt for elevation)..."
    $installScript = Join-Path $repoRoot 'scripts\install_jdk17_and_setup.ps1'
    if (Test-Path $installScript) {
        try {
            & powershell -ExecutionPolicy Bypass -File $installScript
        } catch {
            Write-Log "Installer script execution failed: $_"
            Write-Log "Please run the installer manually as Administrator: $installScript"
            exit 1
        }
        Start-Sleep -Seconds 2
        $verOut = Get-JavaVersionString
        if ($verOut) { Write-Log "Post-install java -version:`n$verOut" } else { Write-Log "java still not found after installer." }
    } else {
        Write-Log "Installer script not found at: $installScript"
        exit 1
    }
}

# 2) If java still points to an old/invalid JAVA_HOME, try to locate a JDK17 installation
$javaCmd = Get-Command java -ErrorAction SilentlyContinue
$candidateJdk = $null

if ($javaCmd) {
    $src = $javaCmd.Source
    if ($src -like '*Common Files\Oracle\Java*') {
        Write-Log 'Detected java.exe from Oracle Common Files (x86) — locating a proper JDK17 installation...'
    }
}

if (-not $javaCmd -or ($javaCmd.Source -like '*Common Files\Oracle\Java*')) {
    $searchRoots = @('C:\Program Files','C:\Program Files (x86)')
    foreach ($root in $searchRoots) {
        if (-not (Test-Path $root)) { continue }
        try {
            $found = Get-ChildItem -Path $root -Directory -Recurse -ErrorAction SilentlyContinue |
                     Where-Object { $_.Name -match 'jdk|jdk-17|temurin|adoptium|openjdk' } |
                     Select-Object -ExpandProperty FullName -Unique
            foreach ($f in $found) {
                $maybeJava = Join-Path $f 'bin\java.exe'
                if (Test-Path $maybeJava) {
                    try {
                        $out = & $maybeJava -version 2>&1 | Out-String
                        if ($out -match 'version "17') { $candidateJdk = $f; break }
                    } catch { }
                }
            }
            if ($candidateJdk) { break }
        } catch { }
    }
}

if (-not $candidateJdk -and $javaCmd) {
    $javaBin = Split-Path -Path $javaCmd.Source -Parent
    $possible = Split-Path -Path $javaBin -Parent
    Write-Log "Using java from PATH at: $($javaCmd.Source); derived JAVA_HOME: $possible"
    $candidateJdk = $possible
}

if (-not $candidateJdk) {
    Write-Log 'Could not find a JDK17 installation automatically. Please install Temurin/OpenJDK 17 and re-run this script.'
    exit 1
}

Write-Log "Selected JDK path: $candidateJdk"
$javaBinPath = Join-Path $candidateJdk 'bin'

# 3) Fix user-scoped JAVA_HOME and PATH: remove known-bad entries and ensure JDK bin is present
$userPath = [Environment]::GetEnvironmentVariable('Path','User')
if (-not $userPath) { $userPath = '' }

# Remove Oracle Common Files entry if present
$pathParts = $userPath -split ';' | Where-Object { $_ -and ($_ -notlike '*Common Files\Oracle\Java*') }

# Ensure javaBinPath is present (put it at front)
if ($pathParts -notcontains $javaBinPath) { $newPath = $javaBinPath + ';' + ($pathParts -join ';') } else { $newPath = ($pathParts -join ';') }

[Environment]::SetEnvironmentVariable('JAVA_HOME', $candidateJdk, 'User')
[Environment]::SetEnvironmentVariable('Path', $newPath, 'User')

# Also set for current session
$env:JAVA_HOME = $candidateJdk
$env:Path = $javaBinPath + ';' + (($env:Path -split ';' | Where-Object { $_ -ne $javaBinPath }) -join ';')

Write-Log "JAVA_HOME set to: $env:JAVA_HOME"
Write-Log ('java -version now reports:' )
Write-Log (Get-JavaVersionString)

# 4) Run the existing log collection/build script (it will run flutter build and gradle)
$collectScript = Join-Path $repoRoot 'scripts\collect_and_fix_build_logs.ps1'
if (-not (Test-Path $collectScript)) {
    Write-Log "Build/log script not found: $collectScript"
    exit 1
}

Write-Log "Running build/log collection script... this may take several minutes"
try {
    & powershell -ExecutionPolicy Bypass -File $collectScript
} catch {
    Write-Log "Build script finished with error: $_"
}

# 5) If build produced an APK, copy it to repo root build_outputs
$apkSource = Join-Path $repoRoot 'mobile-flutter\build\app\outputs\flutter-apk\app-release.apk'
if (Test-Path $apkSource) {
    $outDir = Join-Path $repoRoot 'build_outputs'
    if (-not (Test-Path $outDir)) { New-Item -Path $outDir -ItemType Directory | Out-Null }
    $dest = Join-Path $outDir 'mobile-flutter-app-release.apk'
    Copy-Item -Path $apkSource -Destination $dest -Force
    Write-Log "APK produced and copied to: $dest"
} else {
    Write-Log "APK not found at expected path: $apkSource"
    Write-Log "Check logs in repo root: flutter_build_verbose.log, gradle_assembleRelease.log, gradle_assemble_after_clean.log"
    exit 1
}

Write-Log "Finished. If APK exists in build_outputs, you can transfer it to your device." 
