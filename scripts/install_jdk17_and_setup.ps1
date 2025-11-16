<#
install_jdk17_and_setup.ps1

Installs Temurin / OpenJDK 17 and sets JAVA_HOME + updates user PATH.

Usage:
- Open PowerShell as Administrator (recommended).
- From repository root run:
    Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force
    .\scripts\install_jdk17_and_setup.ps1

What it does:
- If winget is available, installs EclipseAdoptium.Temurin.17 via winget.
- Otherwise downloads the Temurin JDK 17 MSI from Adoptium and launches the installer.
- Waits for the installer to exit, then finds java on PATH and sets JAVA_HOME (User scope)
  and appends the Java bin directory to the user's PATH.

Note: Installer GUI may require user interaction. Run as Administrator for winget and silent install.
#>

function Write-Log { param($m) Write-Host "[install-jdk] $m" }

if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Log 'Script is not running as Administrator. Some steps may fail. Run PowerShell as Administrator if possible.'
}

try {
    $winget = Get-Command winget -ErrorAction SilentlyContinue
} catch {
    $winget = $null
}

if ($winget) {
    Write-Log 'winget found — installing Temurin JDK 17 via winget...'
    try {
        winget install -e --id EclipseAdoptium.Temurin.17 --accept-package-agreements --accept-source-agreements
        Write-Log 'winget install command finished.'
    } catch {
            Write-Log ('winget install failed: ' + $_)
            Write-Log 'Falling back to direct MSI download/install.'
            # Fallback to MSI download and run installer
            $msi = Join-Path $env:TEMP 'temurin17.msi'
            $uri = 'https://github.com/adoptium/temurin17-binaries/releases/latest/download/OpenJDK17U-jdk_x64_windows_hotspot.msi'
            try {
                Invoke-WebRequest -Uri $uri -OutFile $msi -UseBasicParsing -ErrorAction Stop
                Write-Log ('Downloaded MSI to ' + $msi)
                Write-Log 'Starting MSI installer (may prompt for elevation) — follow the GUI to complete installation.'
                $p = Start-Process -FilePath $msi -Verb RunAs -PassThru
                Write-Log ('Waiting for installer to exit (PID: ' + $p.Id + ')...')
                $p | Wait-Process
                Write-Log 'Installer finished.'
            } catch {
                Write-Log ('Failed to download or run MSI fallback: ' + $_)
                Write-Log 'Please manually download from https://adoptium.net/ and install OpenJDK 17 (MSI).'
            }
    }
} else {
    Write-Log 'winget not found. Downloading Temurin JDK 17 MSI from Adoptium...'
    $msi = Join-Path $env:TEMP 'temurin17.msi'
    $uri = 'https://github.com/adoptium/temurin17-binaries/releases/latest/download/OpenJDK17U-jdk_x64_windows_hotspot.msi'
    try {
        Invoke-WebRequest -Uri $uri -OutFile $msi -UseBasicParsing -ErrorAction Stop
        Write-Log ('Downloaded MSI to ' + $msi)
        Write-Log 'Starting MSI installer (may prompt for elevation) — follow the GUI to complete installation.'
        $p = Start-Process -FilePath $msi -Verb RunAs -PassThru
        Write-Log ('Waiting for installer to exit (PID: ' + $p.Id + ')...')
        $p | Wait-Process
        Write-Log 'Installer finished.'
    } catch {
        Write-Log ('Failed to download or run MSI: ' + $_)
        Write-Log 'Please manually download from https://adoptium.net/ and install OpenJDK 17 (MSI).'
    }
}

# Short wait then try to find java on PATH
Start-Sleep -Seconds 2
try {
    $javaCmd = Get-Command java -ErrorAction Stop
    $javaBin = Split-Path -Path $javaCmd.Source -Parent
    $javaHome = Split-Path -Path $javaBin -Parent
    Write-Log ('Found java at: ' + $javaCmd.Source)
    Write-Log ('Setting JAVA_HOME to: ' + $javaHome + ' (User scope)')
    [Environment]::SetEnvironmentVariable('JAVA_HOME', $javaHome, 'User')

    # Append java bin to user PATH if it's not already there
    $userPath = [Environment]::GetEnvironmentVariable('Path','User')
    if ($userPath -notlike ("*" + $javaBin + "*")) {
        $newPath = $userPath + ';' + $javaBin
        [Environment]::SetEnvironmentVariable('Path',$newPath,'User')
        Write-Log ('Added ' + $javaBin + ' to user PATH.')
    } else {
        Write-Log 'Java bin already in user PATH.'
    }

    # Set variables for current session
    $env:JAVA_HOME = $javaHome
    $env:Path = $env:Path + ';' + $javaBin

    Write-Log 'JAVA_HOME and PATH updated for current session. Close and reopen PowerShell windows to pick up persistent changes.'
    Write-Log 'Current java version:'
    & java -version
} catch {
    Write-Log 'Could not find java on PATH after installation. Please ensure JDK 17 was installed correctly and that java.exe is in PATH.'
    Write-Log 'You can manually verify: open a new PowerShell and run java -version.'
}

Write-Log 'Done. After verifying java -version shows Java 17, re-run build/log script: .\scripts\collect_and_fix_build_logs.ps1'
