# Claude Native Messaging Setup for Chromium Browsers (Windows)
# This script configures Native Messaging Host for Claude extension
# in alternative Chromium-based browsers.

#Requires -Version 5.1

param(
    [switch]$Uninstall,
    [string]$Path,
    [switch]$Help
)

# Colors
function Write-Success { param($Message) Write-Host "OK " -ForegroundColor Green -NoNewline; Write-Host $Message }
function Write-Error { param($Message) Write-Host "X " -ForegroundColor Red -NoNewline; Write-Host $Message }
function Write-Warning { param($Message) Write-Host "! " -ForegroundColor Yellow -NoNewline; Write-Host $Message }
function Write-Info { param($Message) Write-Host "i " -ForegroundColor Cyan -NoNewline; Write-Host $Message }

# Extension IDs
$CLAUDE_EXTENSION_IDS = @(
    "chrome-extension://fcoeoabgfenejglbffodgkkbkcdhcgfn/",
    "chrome-extension://dihbgbndebgnbjfmelmegjepbnkhlgni/",
    "chrome-extension://dngcpimnedloihjnnfngkgjoidhnaolf/"
)
$PRIMARY_EXTENSION_ID = "fcoeoabgfenejglbffodgkkbkcdhcgfn"

# Browser configurations: Name, AppData Path
$BROWSER_CONFIGS = @(
    @{ Name = "Brave"; Path = "BraveSoftware\Brave-Browser\User Data" },
    @{ Name = "Vivaldi"; Path = "Vivaldi\User Data" },
    @{ Name = "Microsoft Edge"; Path = "Microsoft\Edge\User Data" },
    @{ Name = "Chromium"; Path = "Chromium\User Data" },
    @{ Name = "Opera"; Path = "Opera Software\Opera Stable" },
    @{ Name = "Opera GX"; Path = "Opera Software\Opera GX Stable" },
    @{ Name = "Genspark"; Path = "GensparkSoftware\Genspark-Browser\User Data" },
    @{ Name = "Google Chrome"; Path = "Google\Chrome\User Data" },
    @{ Name = "Yandex"; Path = "Yandex\YandexBrowser\User Data" },
    @{ Name = "Naver Whale"; Path = "Naver\Whale\User Data" },
    @{ Name = "Coc Coc"; Path = "CocCoc\Browser\User Data" },
    @{ Name = "Comodo Dragon"; Path = "Comodo\Dragon\User Data" },
    @{ Name = "Avast Secure Browser"; Path = "AVAST Software\Browser\User Data" },
    @{ Name = "AVG Secure Browser"; Path = "AVG\Browser\User Data" },
    @{ Name = "Epic Privacy Browser"; Path = "Epic Privacy Browser\User Data" },
    @{ Name = "Torch"; Path = "Torch\User Data" },
    @{ Name = "Slimjet"; Path = "Slimjet\User Data" },
    @{ Name = "SRWare Iron"; Path = "Chromium\User Data" },
    @{ Name = "Cent Browser"; Path = "CentBrowser\User Data" },
    @{ Name = "Maxthon"; Path = "Maxthon\User Data" },
    @{ Name = "Iridium"; Path = "Iridium\User Data" },
    @{ Name = "Sidekick"; Path = "Sidekick\User Data" }
)

function Get-AppDataBase {
    return $env:LOCALAPPDATA
}

function Get-ClaudeNativeHostPath {
    $possiblePaths = @(
        "$env:LOCALAPPDATA\Programs\claude\resources\chrome-native-host.exe",
        "$env:LOCALAPPDATA\Claude\chrome-native-host.exe",
        "$env:PROGRAMFILES\Claude\chrome-native-host.exe",
        "${env:PROGRAMFILES(x86)}\Claude\chrome-native-host.exe"
    )
    
    foreach ($p in $possiblePaths) {
        if (Test-Path $p) {
            return $p
        }
    }
    return $null
}

function Get-ClaudeCodeNativeHostPath {
    return "$env:USERPROFILE\.claude\chrome\chrome-native-host.exe"
}

function Get-InstalledBrowsers {
    $basePath = Get-AppDataBase
    $detected = @()
    
    foreach ($browser in $BROWSER_CONFIGS) {
        $browserPath = Join-Path $basePath $browser.Path
        if (Test-Path $browserPath) {
            $detected += @{
                Name = $browser.Name
                Path = $browserPath
            }
        }
    }
    
    return $detected
}

function Test-ExtensionInstalled {
    param($BrowserPath)
    
    $extensionPath = Join-Path $BrowserPath "Default\Extensions\$PRIMARY_EXTENSION_ID"
    if (Test-Path $extensionPath) {
        return $true
    }
    
    # Check other profiles
    $profiles = Get-ChildItem -Path $BrowserPath -Directory -Filter "Profile*" -ErrorAction SilentlyContinue
    foreach ($profile in $profiles) {
        $extPath = Join-Path $profile.FullName "Extensions\$PRIMARY_EXTENSION_ID"
        if (Test-Path $extPath) {
            return $true
        }
    }
    
    return $false
}

function New-ManifestFiles {
    param(
        $BrowserPath,
        $NativeHostPath,
        $CodeNativeHostPath
    )
    
    $nmhDir = Join-Path $BrowserPath "NativeMessagingHosts"
    
    if (-not (Test-Path $nmhDir)) {
        New-Item -ItemType Directory -Path $nmhDir -Force | Out-Null
    }
    
    # Build allowed_origins JSON array
    $originsJson = ($CLAUDE_EXTENSION_IDS | ForEach-Object { "`"$_`"" }) -join ",`n    "
    
    # Claude Desktop manifest
    $desktopManifest = @"
{
  "name": "com.anthropic.claude_browser_extension",
  "description": "Claude Browser Extension Native Host",
  "path": "$($NativeHostPath -replace '\\', '\\\\')",
  "type": "stdio",
  "allowed_origins": [
    $originsJson
  ]
}
"@
    
    $desktopManifestPath = Join-Path $nmhDir "com.anthropic.claude_browser_extension.json"
    Set-Content -Path $desktopManifestPath -Value $desktopManifest -Encoding UTF8
    
    # Claude Code manifest (if exists)
    $codeCreated = $false
    if (Test-Path $CodeNativeHostPath) {
        $codeManifest = @"
{
  "name": "com.anthropic.claude_code_browser_extension",
  "description": "Claude Code Browser Extension Native Host",
  "path": "$($CodeNativeHostPath -replace '\\', '\\\\')",
  "type": "stdio",
  "allowed_origins": [
    "chrome-extension://$PRIMARY_EXTENSION_ID/"
  ]
}
"@
        
        $codeManifestPath = Join-Path $nmhDir "com.anthropic.claude_code_browser_extension.json"
        Set-Content -Path $codeManifestPath -Value $codeManifest -Encoding UTF8
        $codeCreated = $true
    }
    
    return $codeCreated
}

function Remove-ManifestFiles {
    param($BrowserPath)
    
    $nmhDir = Join-Path $BrowserPath "NativeMessagingHosts"
    
    $desktopManifest = Join-Path $nmhDir "com.anthropic.claude_browser_extension.json"
    $codeManifest = Join-Path $nmhDir "com.anthropic.claude_code_browser_extension.json"
    
    if (Test-Path $desktopManifest) {
        Remove-Item $desktopManifest -Force
        Write-Success "Removed claude_browser_extension manifest"
    }
    
    if (Test-Path $codeManifest) {
        Remove-Item $codeManifest -Force
        Write-Success "Removed claude_code_browser_extension manifest"
    }
    
    # Remove directory if empty
    if ((Test-Path $nmhDir) -and ((Get-ChildItem $nmhDir | Measure-Object).Count -eq 0)) {
        Remove-Item $nmhDir -Force
        Write-Success "Removed empty NativeMessagingHosts directory"
    }
}

function Test-Installation {
    param($BrowserPath)
    
    $nmhDir = Join-Path $BrowserPath "NativeMessagingHosts"
    $success = $true
    
    $desktopManifest = Join-Path $nmhDir "com.anthropic.claude_browser_extension.json"
    $codeManifest = Join-Path $nmhDir "com.anthropic.claude_code_browser_extension.json"
    
    if (Test-Path $desktopManifest) {
        Write-Success "Claude Desktop manifest exists"
    } else {
        Write-Error "Claude Desktop manifest missing"
        $success = $false
    }
    
    if (Test-Path $codeManifest) {
        Write-Success "Claude Code manifest exists"
    } else {
        Write-Warning "Claude Code manifest missing (Claude Code may not be installed)"
    }
    
    return $success
}

function Show-Header {
    Write-Host ""
    Write-Host "===========================================================" -ForegroundColor Cyan
    Write-Host "  Claude Native Messaging Setup for Chromium Browsers" -ForegroundColor Cyan
    Write-Host "===========================================================" -ForegroundColor Cyan
    Write-Host ""
}

function Show-Help {
    Write-Host "Usage: .\setup.ps1 [OPTIONS]"
    Write-Host ""
    Write-Host "Options:"
    Write-Host "  -Uninstall      Remove Claude native messaging configuration"
    Write-Host "  -Path <PATH>    Specify custom browser User Data path"
    Write-Host "  -Help           Show this help message"
    exit 0
}

# Main script
if ($Help) {
    Show-Help
}

Show-Header

# Check Claude native host
$nativeHostPath = Get-ClaudeNativeHostPath
if (-not $nativeHostPath) {
    Write-Error "Claude Desktop not found. Please install Claude Desktop first."
    Write-Info "Download from: https://claude.ai/download"
    exit 1
}
Write-Success "Found Claude Desktop native host: $nativeHostPath"

$codeNativeHostPath = Get-ClaudeCodeNativeHostPath
if (Test-Path $codeNativeHostPath) {
    Write-Success "Found Claude Code native host: $codeNativeHostPath"
} else {
    Write-Warning "Claude Code native host not found (optional)"
}

Write-Host ""

# Handle custom path
if ($Path) {
    if (-not (Test-Path $Path)) {
        Write-Error "Specified path does not exist: $Path"
        exit 1
    }
    
    if ($Uninstall) {
        Write-Info "Uninstalling from: $Path"
        Remove-ManifestFiles -BrowserPath $Path
    } else {
        Write-Info "Installing to: $Path"
        New-ManifestFiles -BrowserPath $Path -NativeHostPath $nativeHostPath -CodeNativeHostPath $codeNativeHostPath
        Write-Host ""
        Test-Installation -BrowserPath $Path | Out-Null
    }
    
    Write-Host ""
    Write-Info "Please restart your browser for changes to take effect."
    exit 0
}

# Detect browsers
Write-Info "Scanning for Chromium-based browsers..."
Write-Host ""

$browsers = Get-InstalledBrowsers

if ($browsers.Count -eq 0) {
    Write-Error "No supported Chromium browsers found."
    Write-Info "You can specify a custom path with: .\setup.ps1 -Path 'C:\path\to\browser\User Data'"
    exit 1
}

# Display found browsers
Write-Host "Found browsers:"
Write-Host ""

$i = 1
foreach ($browser in $browsers) {
    $extensionStatus = if (Test-ExtensionInstalled -BrowserPath $browser.Path) {
        Write-Host "  $i) $($browser.Name) " -NoNewline
        Write-Host "[Extension installed]" -ForegroundColor Green
    } else {
        Write-Host "  $i) $($browser.Name) " -NoNewline
        Write-Host "[Extension not found]" -ForegroundColor Yellow
    }
    Write-Host "     $($browser.Path)" -ForegroundColor Cyan
    Write-Host ""
    $i++
}

# Prompt user for selection
$selection = Read-Host "Select browser(s) to configure (comma-separated, or 'all')"

if ([string]::IsNullOrWhiteSpace($selection)) {
    Write-Error "No selection made. Exiting."
    exit 1
}

$selectedIndices = @()
if ($selection -eq "all") {
    $selectedIndices = 1..$browsers.Count
} else {
    $selectedIndices = $selection -split ',' | ForEach-Object { $_.Trim() }
}

Write-Host ""

# Process selected browsers
foreach ($idx in $selectedIndices) {
    $index = [int]$idx
    
    if ($index -lt 1 -or $index -gt $browsers.Count) {
        Write-Warning "Invalid selection: $idx (skipping)"
        continue
    }
    
    $browser = $browsers[$index - 1]
    
    Write-Host "-----------------------------------------------------------"
    Write-Info "Processing: $($browser.Name)"
    
    if ($Uninstall) {
        Remove-ManifestFiles -BrowserPath $browser.Path
        Write-Success "Uninstalled from $($browser.Name)"
    } else {
        $codeCreated = New-ManifestFiles -BrowserPath $browser.Path -NativeHostPath $nativeHostPath -CodeNativeHostPath $codeNativeHostPath
        if ($codeCreated) {
            Write-Success "Created manifests for $($browser.Name)"
        } else {
            Write-Warning "Created Claude Desktop manifest only (Claude Code not installed)"
        }
        Test-Installation -BrowserPath $browser.Path | Out-Null
    }
    Write-Host ""
}

Write-Host "-----------------------------------------------------------"
Write-Host ""
Write-Success "Setup complete!"
Write-Host ""
Write-Info "Next steps:"
Write-Host "  1. Completely quit your browser (check Task Manager)"
Write-Host "  2. Restart the browser"
Write-Host "  3. Open the Claude extension in the side panel"
Write-Host "  4. For Claude Code: Run '/chrome' in your terminal"
Write-Host ""
