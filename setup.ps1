# Claude Native Messaging Setup for Chromium Browsers (Windows)
# This script configures Native Messaging Host for Claude extension
# in alternative Chromium-based browsers.
#
# Usage: .\setup.ps1 [OPTIONS]
# Run .\setup.ps1 -Help for more information.

#Requires -Version 5.1

[CmdletBinding()]
param(
    [switch]$Uninstall,
    [string]$Path,
    [switch]$DryRun,
    [switch]$Verbose,
    [switch]$Quiet,
    [switch]$Backup,
    [switch]$Version,
    [switch]$Help
)

# =============================================================================
# Constants
# =============================================================================

$script:ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$script:VersionFile = Join-Path $ScriptDir "VERSION"
$script:ConfigFile = Join-Path $ScriptDir "config\browsers.json"

# Extension IDs with descriptions
$script:CLAUDE_OFFICIAL_EXTENSION_ID = "fcoeoabgfenejglbffodgkkbkcdhcgfn"
$script:CLAUDE_DEV_EXTENSION_ID = "dihbgbndebgnbjfmelmegjepbnkhlgni"
$script:CLAUDE_STAGING_EXTENSION_ID = "dngcpimnedloihjnnfngkgjoidhnaolf"

# All allowed extension origins (official first)
$script:CLAUDE_EXTENSION_ORIGINS = @(
    "chrome-extension://$CLAUDE_OFFICIAL_EXTENSION_ID/",
    "chrome-extension://$CLAUDE_DEV_EXTENSION_ID/",
    "chrome-extension://$CLAUDE_STAGING_EXTENSION_ID/"
)

# =============================================================================
# Output Functions (renamed to avoid conflicts with built-in cmdlets)
# =============================================================================

function Get-ScriptVersion {
    if (Test-Path $script:VersionFile) {
        return (Get-Content $script:VersionFile -Raw).Trim()
    }
    return "unknown"
}

function Write-Header {
    if ($Quiet) { return }
    Write-Host ""
    Write-Host "===========================================================" -ForegroundColor Cyan
    Write-Host "  Claude Native Messaging Setup for Chromium Browsers" -ForegroundColor Cyan
    Write-Host "  Version: $(Get-ScriptVersion)" -ForegroundColor Cyan
    Write-Host "===========================================================" -ForegroundColor Cyan
    Write-Host ""
}

function Write-SuccessMessage {
    param([string]$Message)
    if ($Quiet) { return }
    Write-Host "OK " -ForegroundColor Green -NoNewline
    Write-Host $Message
}

function Write-ErrorMessage {
    param([string]$Message)
    Write-Host "X " -ForegroundColor Red -NoNewline
    Write-Host $Message
}

function Write-WarningMessage {
    param([string]$Message)
    if ($Quiet) { return }
    Write-Host "! " -ForegroundColor Yellow -NoNewline
    Write-Host $Message
}

function Write-InfoMessage {
    param([string]$Message)
    if ($Quiet) { return }
    Write-Host "i " -ForegroundColor Cyan -NoNewline
    Write-Host $Message
}

function Write-VerboseMessage {
    param([string]$Message)
    if ($Verbose) {
        Write-Host "  -> " -ForegroundColor DarkGray -NoNewline
        Write-Host $Message -ForegroundColor DarkGray
    }
}

function Write-DryRunMessage {
    param([string]$Message)
    Write-Host "[DRY-RUN] " -ForegroundColor Yellow -NoNewline
    Write-Host $Message
}

# =============================================================================
# Validation Functions
# =============================================================================

function Test-ValidPath {
    param([string]$InputPath)

    try {
        $resolvedPath = [System.IO.Path]::GetFullPath($InputPath)

        # Security check: path must be within user directories
        $localAppData = $env:LOCALAPPDATA
        $userProfile = $env:USERPROFILE
        $programFiles = $env:PROGRAMFILES
        $programFilesX86 = ${env:PROGRAMFILES(X86)}

        $validPrefixes = @($localAppData, $userProfile, $programFiles, $programFilesX86, $env:TEMP)
        $isValid = $false

        foreach ($prefix in $validPrefixes) {
            if ($prefix -and $resolvedPath.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) {
                $isValid = $true
                break
            }
        }

        if (-not $isValid) {
            Write-ErrorMessage "Path must be within user or program directories: $resolvedPath"
            return $null
        }

        return $resolvedPath
    }
    catch {
        Write-ErrorMessage "Invalid path: $InputPath"
        return $null
    }
}

# =============================================================================
# Claude Path Detection
# =============================================================================

function Get-ClaudeNativeHostPath {
    $possiblePaths = @(
        "$env:LOCALAPPDATA\Programs\claude\resources\chrome-native-host.exe",
        "$env:LOCALAPPDATA\Claude\chrome-native-host.exe",
        "$env:PROGRAMFILES\Claude\chrome-native-host.exe",
        "${env:PROGRAMFILES(x86)}\Claude\chrome-native-host.exe"
    )

    foreach ($p in $possiblePaths) {
        if (Test-Path $p) {
            Write-VerboseMessage "Found Claude Desktop at: $p"
            return $p
        }
    }
    return $null
}

function Get-ClaudeCodeNativeHostPath {
    return "$env:USERPROFILE\.claude\chrome\chrome-native-host.exe"
}

# =============================================================================
# Browser Configuration
# =============================================================================

# Built-in browser configurations (used when JSON config not available)
$script:BUILTIN_BROWSER_CONFIGS = @(
    @{ Name = "Brave"; Path = "BraveSoftware\Brave-Browser\User Data" },
    @{ Name = "Arc"; Path = "Arc\User Data" },
    @{ Name = "Vivaldi"; Path = "Vivaldi\User Data" },
    @{ Name = "Microsoft Edge"; Path = "Microsoft\Edge\User Data" },
    @{ Name = "Chromium"; Path = "Chromium\User Data" },
    @{ Name = "Google Chrome"; Path = "Google\Chrome\User Data" },
    @{ Name = "Google Chrome Canary"; Path = "Google\Chrome SxS\User Data" },
    @{ Name = "Google Chrome Beta"; Path = "Google\Chrome Beta\User Data" },
    @{ Name = "Google Chrome Dev"; Path = "Google\Chrome Dev\User Data" },
    @{ Name = "Opera"; Path = "Opera Software\Opera Stable" },
    @{ Name = "Opera GX"; Path = "Opera Software\Opera GX Stable" },
    @{ Name = "Genspark"; Path = "GensparkSoftware\Genspark-Browser\User Data" },
    @{ Name = "Sidekick"; Path = "Sidekick\User Data" },
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
    @{ Name = "Ungoogled Chromium"; Path = "Chromium\User Data" },
    @{ Name = "Helium"; Path = "imput\Helium\User Data" },
    @{ Name = "Cent Browser"; Path = "CentBrowser\User Data" },
    @{ Name = "Maxthon"; Path = "Maxthon\User Data" },
    @{ Name = "Iridium"; Path = "Iridium\User Data" }
)

function Get-BrowserConfigsFromJson {
    if (-not (Test-Path $script:ConfigFile)) {
        Write-VerboseMessage "Config file not found: $script:ConfigFile"
        return $null
    }

    try {
        $config = Get-Content $script:ConfigFile -Raw | ConvertFrom-Json
        $browsers = @()

        foreach ($browser in $config.browsers) {
            if ($browser.paths.windows) {
                $browsers += @{
                    Name = $browser.name
                    Path = $browser.paths.windows
                }
            }
        }

        Write-VerboseMessage "Loaded $($browsers.Count) browser configs from JSON"
        return $browsers
    }
    catch {
        Write-VerboseMessage "Failed to parse JSON config: $_"
        return $null
    }
}

function Test-BrowserInstallation {
    param([string]$BrowserPath, [string]$Name)

    if (-not (Test-Path $BrowserPath)) {
        Write-VerboseMessage "Skipped ${Name}: directory does not exist ($BrowserPath)"
        return $false
    }

    $contents = Get-ChildItem -Path $BrowserPath -ErrorAction SilentlyContinue
    if (-not $contents -or $contents.Count -eq 0) {
        Write-VerboseMessage "Skipped ${Name}: directory is empty ($BrowserPath)"
        return $false
    }

    # Check for Chromium profile markers
    $defaultDir = Join-Path $BrowserPath "Default"
    $prefsFile = Join-Path $BrowserPath "Preferences"
    $localState = Join-Path $BrowserPath "Local State"

    if ((Test-Path $defaultDir) -or (Test-Path $prefsFile) -or (Test-Path $localState)) {
        return $true
    }

    # Check for numbered profiles (Profile 1, Profile 2, etc.)
    $profiles = Get-ChildItem -Path $BrowserPath -Directory -Filter "Profile*" -ErrorAction SilentlyContinue
    if ($profiles -and $profiles.Count -gt 0) {
        return $true
    }

    Write-VerboseMessage "Skipped ${Name}: no browser profile data found ($BrowserPath)"
    return $false
}

function Get-InstalledBrowsers {
    $basePath = $env:LOCALAPPDATA
    $detected = @()
    # Track seen paths to deduplicate browsers sharing the same data directory
    # (e.g., Chromium, SRWare Iron, Ungoogled Chromium all use Chromium\User Data on Windows)
    $seenPaths = @()

    # Try to load from JSON config first
    $browserConfigs = Get-BrowserConfigsFromJson
    if (-not $browserConfigs) {
        Write-VerboseMessage "Using built-in browser configurations"
        $browserConfigs = $script:BUILTIN_BROWSER_CONFIGS
    }

    foreach ($browser in $browserConfigs) {
        $browserPath = Join-Path $basePath $browser.Path
        if (Test-BrowserInstallation -BrowserPath $browserPath -Name $browser.Name) {
            # Skip if another browser already claimed this path
            if ($seenPaths -contains $browserPath) {
                Write-VerboseMessage "Skipped $($browser.Name): path already claimed by another browser ($browserPath)"
                continue
            }

            $seenPaths += $browserPath
            $detected += @{
                Name = $browser.Name
                Path = $browserPath
            }
            Write-VerboseMessage "Found: $($browser.Name) at $browserPath"
        }
    }

    return $detected
}

# =============================================================================
# Extension Detection
# =============================================================================

function Test-ExtensionInstalled {
    param([string]$BrowserPath)

    $extensionPath = Join-Path $BrowserPath "Default\Extensions\$script:CLAUDE_OFFICIAL_EXTENSION_ID"
    if (Test-Path $extensionPath) {
        return $true
    }

    # Check other profiles
    $profiles = Get-ChildItem -Path $BrowserPath -Directory -Filter "Profile*" -ErrorAction SilentlyContinue
    foreach ($profile in $profiles) {
        $extPath = Join-Path $profile.FullName "Extensions\$script:CLAUDE_OFFICIAL_EXTENSION_ID"
        if (Test-Path $extPath) {
            return $true
        }
    }

    return $false
}

# =============================================================================
# Backup Functions
# =============================================================================

function New-BackupFile {
    param([string]$FilePath)

    if (-not (Test-Path $FilePath)) {
        return $true
    }

    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $backupPath = "$FilePath.backup.$timestamp"

    if ($DryRun) {
        Write-DryRunMessage "Would create backup: $backupPath"
        return $true
    }

    try {
        Copy-Item -Path $FilePath -Destination $backupPath -ErrorAction Stop
        Write-VerboseMessage "Created backup: $backupPath"
        return $true
    }
    catch {
        Write-ErrorMessage "Failed to create backup: $backupPath"
        return $false
    }
}

# =============================================================================
# Manifest Creation
# =============================================================================

function New-ManifestFiles {
    param(
        [string]$BrowserPath,
        [string]$NativeHostPath,
        [string]$CodeNativeHostPath
    )

    $nmhDir = Join-Path $BrowserPath "NativeMessagingHosts"
    $desktopManifest = Join-Path $nmhDir "com.anthropic.claude_browser_extension.json"
    $codeManifest = Join-Path $nmhDir "com.anthropic.claude_code_browser_extension.json"

    # Check for existing files and prompt for overwrite
    if ((Test-Path $desktopManifest) -and (-not $Backup) -and (-not $DryRun)) {
        Write-WarningMessage "Manifest already exists: $desktopManifest"
        $response = Read-Host "Overwrite? [y/N]"
        if ($response -notmatch '^[Yy]') {
            Write-InfoMessage "Skipped (use -Backup to auto-backup existing files)"
            return 1
        }
    }

    # Create backups if requested
    if ($Backup) {
        New-BackupFile -FilePath $desktopManifest | Out-Null
        New-BackupFile -FilePath $codeManifest | Out-Null
    }

    # Build allowed_origins JSON array
    $originsJson = ($script:CLAUDE_EXTENSION_ORIGINS | ForEach-Object { "`"$_`"" }) -join ",`n    "

    # Escape backslashes for JSON
    $escapedNativeHostPath = $NativeHostPath -replace '\\', '\\\\'

    # Claude Desktop manifest content
    $desktopContent = @"
{
  "name": "com.anthropic.claude_browser_extension",
  "description": "Claude Browser Extension Native Host",
  "path": "$escapedNativeHostPath",
  "type": "stdio",
  "allowed_origins": [
    $originsJson
  ]
}
"@

    if ($DryRun) {
        Write-DryRunMessage "Would create directory: $nmhDir"
        Write-DryRunMessage "Would create file: $desktopManifest"

        if (Test-Path $CodeNativeHostPath) {
            Write-DryRunMessage "Would create file: $codeManifest"
        }
        return 0
    }

    # Create directory
    try {
        if (-not (Test-Path $nmhDir)) {
            New-Item -ItemType Directory -Path $nmhDir -Force -ErrorAction Stop | Out-Null
        }
    }
    catch {
        Write-ErrorMessage "Failed to create directory: $nmhDir"
        return 1
    }

    # Write desktop manifest
    try {
        Set-Content -Path $desktopManifest -Value $desktopContent -Encoding UTF8 -ErrorAction Stop
    }
    catch {
        Write-ErrorMessage "Failed to create manifest: $desktopManifest - $_"
        return 1
    }

    # Create Claude Code manifest (only if Claude Code native host exists)
    $codeCreated = $false
    if (Test-Path $CodeNativeHostPath) {
        $escapedCodePath = $CodeNativeHostPath -replace '\\', '\\\\'

        $codeContent = @"
{
  "name": "com.anthropic.claude_code_browser_extension",
  "description": "Claude Code Browser Extension Native Host",
  "path": "$escapedCodePath",
  "type": "stdio",
  "allowed_origins": [
    "chrome-extension://$script:CLAUDE_OFFICIAL_EXTENSION_ID/"
  ]
}
"@

        try {
            Set-Content -Path $codeManifest -Value $codeContent -Encoding UTF8 -ErrorAction Stop
            $codeCreated = $true
        }
        catch {
            Write-ErrorMessage "Failed to create manifest: $codeManifest - $_"
        }
    }

    if ($codeCreated) {
        return 0
    }
    else {
        return 2  # Partial success (desktop only)
    }
}

# =============================================================================
# Uninstall Function
# =============================================================================

function Remove-ManifestFiles {
    param([string]$BrowserPath)

    $nmhDir = Join-Path $BrowserPath "NativeMessagingHosts"
    $desktopManifest = Join-Path $nmhDir "com.anthropic.claude_browser_extension.json"
    $codeManifest = Join-Path $nmhDir "com.anthropic.claude_code_browser_extension.json"

    if ($DryRun) {
        if (Test-Path $desktopManifest) {
            Write-DryRunMessage "Would remove: $desktopManifest"
        }
        if (Test-Path $codeManifest) {
            Write-DryRunMessage "Would remove: $codeManifest"
        }
        return
    }

    if (Test-Path $desktopManifest) {
        if ($Backup) {
            New-BackupFile -FilePath $desktopManifest | Out-Null
        }
        Remove-Item $desktopManifest -Force
        Write-SuccessMessage "Removed claude_browser_extension manifest"
    }

    if (Test-Path $codeManifest) {
        if ($Backup) {
            New-BackupFile -FilePath $codeManifest | Out-Null
        }
        Remove-Item $codeManifest -Force
        Write-SuccessMessage "Removed claude_code_browser_extension manifest"
    }

    # Remove directory if empty
    if ((Test-Path $nmhDir) -and ((Get-ChildItem $nmhDir | Measure-Object).Count -eq 0)) {
        Remove-Item $nmhDir -Force
        Write-SuccessMessage "Removed empty NativeMessagingHosts directory"
    }
}

# =============================================================================
# Verification
# =============================================================================

function Test-Installation {
    param([string]$BrowserPath)

    $nmhDir = Join-Path $BrowserPath "NativeMessagingHosts"
    $success = $true

    if ($DryRun) {
        Write-DryRunMessage "Would verify installation in: $nmhDir"
        return $true
    }

    $desktopManifest = Join-Path $nmhDir "com.anthropic.claude_browser_extension.json"
    $codeManifest = Join-Path $nmhDir "com.anthropic.claude_code_browser_extension.json"

    if (Test-Path $desktopManifest) {
        Write-SuccessMessage "Claude Desktop manifest exists"
    }
    else {
        Write-ErrorMessage "Claude Desktop manifest missing"
        $success = $false
    }

    if (Test-Path $codeManifest) {
        Write-SuccessMessage "Claude Code manifest exists"
    }
    else {
        Write-WarningMessage "Claude Code manifest missing (Claude Code may not be installed)"
    }

    return $success
}

# =============================================================================
# Help and Version
# =============================================================================

function Show-HelpMessage {
    $helpText = @"
Claude Native Messaging Setup for Chromium Browsers (Windows)

USAGE:
    .\setup.ps1 [OPTIONS]

OPTIONS:
    -Uninstall      Remove Claude native messaging configuration
    -Path <PATH>    Specify custom browser User Data path
    -DryRun         Show what would be done without making changes
    -Verbose        Enable verbose output
    -Quiet          Suppress non-error output
    -Backup         Create backups before overwriting existing files
    -Version        Show version information
    -Help           Show this help message

EXAMPLES:
    # Interactive setup
    .\setup.ps1

    # Preview changes without making them
    .\setup.ps1 -DryRun

    # Setup with automatic backups
    .\setup.ps1 -Backup

    # Setup for a custom browser path
    .\setup.ps1 -Path "C:\path\to\browser\User Data"

    # Uninstall with verbose output
    .\setup.ps1 -Uninstall -Verbose

SUPPORTED BROWSERS:
    Brave, Arc, Vivaldi, Microsoft Edge, Chromium, Google Chrome,
    Google Chrome Canary, Opera, Opera GX, Genspark, Sidekick,
    Yandex, Naver Whale, and many more Chromium-based browsers.

For more information, see: https://github.com/stolot0mt0m/claude-chromium-native-messaging
"@
    Write-Host $helpText
}

function Show-VersionMessage {
    Write-Host "Claude Native Messaging Setup v$(Get-ScriptVersion)"
}

# =============================================================================
# Main Script
# =============================================================================

# Handle help and version first
if ($Help) {
    Show-HelpMessage
    exit 0
}

if ($Version) {
    Show-VersionMessage
    exit 0
}

Write-Header

if ($DryRun) {
    Write-WarningMessage "DRY-RUN MODE: No changes will be made"
    Write-Host ""
}

# Check Claude native host
$nativeHostPath = Get-ClaudeNativeHostPath
if (-not $nativeHostPath) {
    Write-ErrorMessage "Claude Desktop not found. Please install Claude Desktop first."
    Write-InfoMessage "Download from: https://claude.ai/download"
    exit 1
}
Write-SuccessMessage "Found Claude Desktop native host: $nativeHostPath"

$codeNativeHostPath = Get-ClaudeCodeNativeHostPath
if (Test-Path $codeNativeHostPath) {
    Write-SuccessMessage "Found Claude Code native host: $codeNativeHostPath"
}
else {
    Write-WarningMessage "Claude Code native host not found (optional)"
}

Write-Host ""

# Handle custom path
if ($Path) {
    $validatedPath = Test-ValidPath -InputPath $Path
    if (-not $validatedPath) {
        exit 1
    }

    if (-not (Test-Path $validatedPath)) {
        Write-ErrorMessage "Specified path does not exist: $validatedPath"
        exit 1
    }

    if ($Uninstall) {
        Write-InfoMessage "Uninstalling from: $validatedPath"
        Remove-ManifestFiles -BrowserPath $validatedPath
    }
    else {
        Write-InfoMessage "Installing to: $validatedPath"
        $result = New-ManifestFiles -BrowserPath $validatedPath -NativeHostPath $nativeHostPath -CodeNativeHostPath $codeNativeHostPath
        Write-Host ""
        Test-Installation -BrowserPath $validatedPath | Out-Null
    }

    Write-Host ""
    Write-InfoMessage "Please restart your browser for changes to take effect."
    exit 0
}

# Detect browsers
Write-InfoMessage "Scanning for Chromium-based browsers..."
Write-Host ""

$browsers = Get-InstalledBrowsers

if ($browsers.Count -eq 0) {
    Write-ErrorMessage "No supported Chromium browsers found."
    Write-InfoMessage "You can specify a custom path with: .\setup.ps1 -Path 'C:\path\to\browser\User Data'"
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
    }
    else {
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
    Write-ErrorMessage "No selection made. Exiting."
    exit 1
}

$selectedIndices = @()
if ($selection -eq "all") {
    $selectedIndices = 1..$browsers.Count
}
else {
    $selectedIndices = $selection -split ',' | ForEach-Object { $_.Trim() }
}

Write-Host ""

# Process selected browsers
foreach ($idx in $selectedIndices) {
    try {
        $index = [int]$idx
    }
    catch {
        Write-WarningMessage "Invalid selection: $idx (skipping)"
        continue
    }

    if ($index -lt 1 -or $index -gt $browsers.Count) {
        Write-WarningMessage "Invalid selection: $idx (skipping)"
        continue
    }

    $browser = $browsers[$index - 1]

    Write-Host "-----------------------------------------------------------"
    Write-InfoMessage "Processing: $($browser.Name)"

    if ($Uninstall) {
        Remove-ManifestFiles -BrowserPath $browser.Path
        Write-SuccessMessage "Uninstalled from $($browser.Name)"
    }
    else {
        $result = New-ManifestFiles -BrowserPath $browser.Path -NativeHostPath $nativeHostPath -CodeNativeHostPath $codeNativeHostPath

        switch ($result) {
            0 { Write-SuccessMessage "Created all manifests for $($browser.Name)" }
            1 { Write-WarningMessage "Skipped $($browser.Name)" }
            2 { Write-WarningMessage "Created Claude Desktop manifest only (Claude Code not installed)" }
        }

        if ($result -ne 1) {
            Test-Installation -BrowserPath $browser.Path | Out-Null
        }
    }
    Write-Host ""
}

Write-Host "-----------------------------------------------------------"
Write-Host ""
Write-SuccessMessage "Setup complete!"
Write-Host ""
Write-InfoMessage "Next steps:"
Write-Host "  1. Completely quit your browser (check Task Manager)"
Write-Host "  2. Restart the browser"
Write-Host "  3. Open the Claude extension in the side panel"
Write-Host "  4. For Claude Code: Run '/chrome' in your terminal"
Write-Host ""
