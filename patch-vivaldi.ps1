# Claude Extension Tab-Binding Patch for Vivaldi (Windows)
#
# Builds a patched, unpacked copy of the Claude extension for Chromium forks
# that ignore chrome.sidePanel.setOptions() - Vivaldi (VB-120826), Arc, and
# friends. Those browsers can only load the panel from a static URL, which
# leaves the panel with no target tab and makes every message fail with
# "No active tab".
#
# See docs/vivaldi-tab-binding.md for the full analysis.
#
# Usage: .\patch-vivaldi.ps1 [OPTIONS]
# Run .\patch-vivaldi.ps1 -Help for more information.

#Requires -Version 5.1

[CmdletBinding()]
param(
    [string]$Browser = "vivaldi",
    [string]$BrowserProfile = "Default",
    [string]$Source,
    [string]$Dest,
    [string]$ExtensionId = "fcoeoabgfenejglbffodgkkbkcdhcgfn",
    [switch]$Check,
    [switch]$Uninstall,
    [switch]$DryRun,
    [switch]$Quiet,
    [switch]$Version,
    [switch]$Help
)

# =============================================================================
# Constants
# =============================================================================

$script:ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$script:ScriptName = Split-Path -Leaf $MyInvocation.MyCommand.Path
$script:VersionFile = Join-Path $ScriptDir "VERSION"

# Name of the wrapper service worker written into the patched copy
$script:WrapperWorker = "tabbind.js"

# Metadata file recorded in the patched copy (used by -Check)
$script:PatchInfo = "patch-info.json"

# Query string the panel must be opened with (see docs/vivaldi-tab-binding.md)
$script:PanelQuery = "?mode=window&sessionId=vivaldi-panel"

if (-not $Dest) {
    $Dest = Join-Path $env:USERPROFILE "claude-vivaldi-patched"
}
$Dest = $Dest.TrimEnd('\', '/')

# =============================================================================
# Output Functions
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
    Write-Host "  Claude Extension Tab-Binding Patch (Vivaldi / Arc)" -ForegroundColor Cyan
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

function Write-DryRunMessage {
    param([string]$Message)
    Write-Host "[DRY-RUN] " -ForegroundColor Yellow -NoNewline
    Write-Host $Message
}

function Show-Help {
    @"
Claude Extension Tab-Binding Patch v$(Get-ScriptVersion)

Builds a patched, unpacked copy of the Claude extension so that the side panel
can resolve a target tab in browsers that ignore chrome.sidePanel.setOptions().

Without this patch the panel renders but every message fails with
"No active tab" (see docs/vivaldi-tab-binding.md).

USAGE:
    .\$($script:ScriptName) [OPTIONS]

OPTIONS:
    -Browser NAME       Browser to read the store copy from.
                        One of: vivaldi, vivaldi-snapshot, brave, chrome,
                        chromium, edge (default: vivaldi)
    -BrowserProfile N   Browser profile directory (default: Default)
    -Source DIR         Read the unpatched extension from DIR instead of
                        auto-detecting. DIR is the versioned extension folder
                        containing manifest.json.
    -Dest DIR           Where to write the patched copy
                        (default: %USERPROFILE%\claude-vivaldi-patched)
    -ExtensionId ID     Extension ID to patch
                        (default: fcoeoabgfenejglbffodgkkbkcdhcgfn)
    -Check              Report whether the patched copy is up to date with the
                        installed store copy, then exit.
                        Exit 0 = up to date, 1 = stale or missing.
    -Uninstall          Remove the patched copy
    -DryRun             Show what would happen without writing anything
    -Quiet              Suppress non-error output
    -Help               Show this help
    -Version            Show version

EXAMPLES:
    # Patch the Vivaldi copy of the extension
    .\$($script:ScriptName)

    # Preview without writing
    .\$($script:ScriptName) -DryRun

    # Has the store copy updated since the last patch?
    .\$($script:ScriptName) -Check

    # Patch a copy installed in a non-default profile
    .\$($script:ScriptName) -BrowserProfile "Profile 1"

    # Remove the patched copy
    .\$($script:ScriptName) -Uninstall

AFTER PATCHING:
    The patched copy must be loaded manually - see the instructions the script
    prints on success, or the README section "Vivaldi: No active tab".
"@ | Write-Host
}

# =============================================================================
# Environment Detection
# =============================================================================

function Get-ExtensionsRoot {
    param([string]$BrowserName)

    $localAppData = $env:LOCALAPPDATA
    $base = switch ($BrowserName.ToLower()) {
        "vivaldi"          { Join-Path $localAppData "Vivaldi\User Data" }
        "vivaldi-snapshot" { Join-Path $localAppData "Vivaldi Snapshot\User Data" }
        "brave"            { Join-Path $localAppData "BraveSoftware\Brave-Browser\User Data" }
        "chrome"           { Join-Path $localAppData "Google\Chrome\User Data" }
        "chromium"         { Join-Path $localAppData "Chromium\User Data" }
        "edge"             { Join-Path $localAppData "Microsoft\Edge\User Data" }
        default            { $null }
    }

    if (-not $base) {
        Write-ErrorMessage "Unknown browser: $BrowserName"
        Write-InfoMessage "Use -Source DIR to point at the extension folder directly"
        return $null
    }

    return (Join-Path (Join-Path $base $BrowserProfile) "Extensions")
}

# Highest-versioned folder ("1.0.84_0") under an extension directory
function Get-LatestVersionDir {
    param([string]$ExtensionDir)

    $candidates = Get-ChildItem -Path $ExtensionDir -Directory -ErrorAction SilentlyContinue |
        Where-Object { Test-Path (Join-Path $_.FullName "manifest.json") }

    if (-not $candidates) { return $null }

    $best = $candidates | Sort-Object -Property @{ Expression = {
        $parts = $_.Name -split '[._]' | ForEach-Object { [int]($_ -replace '\D', '0') }
        while ($parts.Count -lt 4) { $parts += 0 }
        [long]"$($parts[0].ToString('00000'))$($parts[1].ToString('00000'))$($parts[2].ToString('00000'))$($parts[3].ToString('00000'))"
    } } | Select-Object -Last 1

    return $best.FullName
}

function Resolve-SourceDir {
    if ($Source) {
        if (-not (Test-Path (Join-Path $Source "manifest.json"))) {
            Write-ErrorMessage "No manifest.json in -Source directory: $Source"
            return $null
        }
        return $Source.TrimEnd('\', '/')
    }

    $extRoot = Get-ExtensionsRoot -BrowserName $Browser
    if (-not $extRoot) { return $null }

    $extDir = Join-Path $extRoot $ExtensionId
    if (-not (Test-Path $extDir)) {
        Write-ErrorMessage "Claude extension not found for $Browser (profile: $BrowserProfile)"
        Write-InfoMessage "Looked in: $extDir"
        Write-InfoMessage "Install the Claude extension from the Chrome Web Store first,"
        Write-InfoMessage "or pass -BrowserProfile / -Source to point at the right location."
        return $null
    }

    $latest = Get-LatestVersionDir -ExtensionDir $extDir
    if (-not $latest) {
        Write-ErrorMessage "No versioned extension folder with a manifest.json in $extDir"
        return $null
    }

    return $latest
}

# =============================================================================
# Patch Generation
# =============================================================================

# The wrapper service worker. MV3 allows exactly one service worker, so the
# wrapper imports the original untouched and appends listeners to it.
function Write-WrapperWorker {
    param([string]$DestFile, [string]$OriginalWorker)

    $content = @"
// Tab binding for the Claude extension in Chromium forks that ignore
// chrome.sidePanel.setOptions() - Vivaldi (VB-120826), Arc, and others.
//
// Generated by patch-vivaldi.ps1. Do not edit by hand; re-run the script
// after the store copy updates.
//
// Chrome gives the panel its tab through the panel URL
// (sidepanel.html?tabId=N). Browsers that ignore setOptions() can only load
// a static URL, so the panel falls back to reading chrome.storage.local
// "targetTabId" when opened with ?mode=window. Nothing in the stock worker
// keeps that key current outside the scheduled-task launcher, so it is either
// missing or stale and every send throws "No active tab".
//
// This wrapper loads the original worker unmodified and adds the listeners
// needed to keep "targetTabId" pointing at the active web tab.

import './$OriginalWorker';

const TARGET_TAB_ID = 'targetTabId';

const isWebTab = (tab) =>
  !!tab && typeof tab.url === 'string' && /^https?:/i.test(tab.url);

const bind = async (tabId) => {
  try {
    const stored = await chrome.storage.local.get(TARGET_TAB_ID);
    if (stored[TARGET_TAB_ID] === tabId) return;
    await chrome.storage.local.set({ [TARGET_TAB_ID]: tabId });
  } catch {
    // Storage can be unavailable while the worker is shutting down.
  }
};

const bindIfWebTab = async (tabId) => {
  try {
    const tab = await chrome.tabs.get(tabId);
    if (isWebTab(tab)) await bind(tabId);
  } catch {
    // Tab closed between the event and the lookup.
  }
};

// Used on worker wake and window focus, when there is no event tab to use.
const bindActiveTab = async () => {
  try {
    let [tab] = await chrome.tabs.query({ active: true, lastFocusedWindow: true });
    if (!isWebTab(tab)) {
      [tab] = (await chrome.tabs.query({ active: true })).filter(isWebTab);
    }
    if (isWebTab(tab)) await bind(tab.id);
  } catch {
    // No windows open yet.
  }
};

chrome.tabs.onActivated.addListener(({ tabId }) => {
  void bindIfWebTab(tabId);
});

chrome.tabs.onUpdated.addListener((tabId, changeInfo, tab) => {
  if (tab.active && (changeInfo.status === 'complete' || changeInfo.url)) {
    void bindIfWebTab(tabId);
  }
});

chrome.windows.onFocusChanged.addListener((windowId) => {
  if (windowId !== chrome.windows.WINDOW_ID_NONE) void bindActiveTab();
});

// Tab IDs are regenerated on browser restart, so re-bind on every cold start
// rather than waiting for the first tab switch.
chrome.runtime.onStartup.addListener(() => {
  void bindActiveTab();
});
chrome.runtime.onInstalled.addListener(() => {
  void bindActiveTab();
});

void bindActiveTab();
"@

    # UTF-8 without BOM - a BOM breaks module parsing in Chromium
    [System.IO.File]::WriteAllText($DestFile, $content, (New-Object System.Text.UTF8Encoding $false))
}

function Invoke-Patch {
    $sourceDir = Resolve-SourceDir
    if (-not $sourceDir) { return $false }

    $manifestPath = Join-Path $sourceDir "manifest.json"
    $manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json

    $extVersion = $manifest.version
    $originalWorker = $manifest.background.service_worker

    if (-not $originalWorker) {
        Write-ErrorMessage "manifest.json has no background.service_worker - nothing to wrap"
        Write-InfoMessage "Manifest: $manifestPath"
        return $false
    }

    if ($originalWorker -eq $script:WrapperWorker) {
        Write-ErrorMessage "Source is already patched (service_worker is $($script:WrapperWorker))"
        Write-InfoMessage "Point -Source at the unmodified store copy."
        return $false
    }

    Write-InfoMessage "Source:      $sourceDir"
    Write-InfoMessage "Version:     $extVersion"
    Write-InfoMessage "Worker:      $originalWorker"
    Write-InfoMessage "Destination: $Dest"
    Write-Host ""

    if ($DryRun) {
        Write-DryRunMessage "Would remove existing $Dest"
        Write-DryRunMessage "Would copy $sourceDir -> $Dest"
        Write-DryRunMessage "Would remove $Dest\_metadata"
        Write-DryRunMessage "Would write $Dest\$($script:WrapperWorker) importing ./$originalWorker"
        Write-DryRunMessage "Would set background.service_worker=$($script:WrapperWorker), background.type=module"
        Write-DryRunMessage "Would remove update_url from manifest.json"
        Write-DryRunMessage "Would write $Dest\$($script:PatchInfo)"
        Write-Host ""
        Write-InfoMessage "Dry run complete - nothing was written"
        return $true
    }

    if (Test-Path $Dest) {
        if (-not (Test-Path (Join-Path $Dest "manifest.json"))) {
            Write-ErrorMessage "Destination exists but does not look like an extension: $Dest"
            Write-InfoMessage "Refusing to delete it. Choose another -Dest or remove it yourself."
            return $false
        }
        Remove-Item -Path $Dest -Recurse -Force
    }

    $parent = Split-Path -Parent $Dest
    if ($parent -and -not (Test-Path $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }

    Copy-Item -Path $sourceDir -Destination $Dest -Recurse -Force
    Write-SuccessMessage "Copied extension"

    # _metadata holds Web Store signatures that do not apply to an unpacked copy
    $metadata = Join-Path $Dest "_metadata"
    if (Test-Path $metadata) { Remove-Item -Path $metadata -Recurse -Force }

    Write-WrapperWorker -DestFile (Join-Path $Dest $script:WrapperWorker) -OriginalWorker $originalWorker
    Write-SuccessMessage "Wrote $($script:WrapperWorker) (wraps $originalWorker)"

    $destManifestPath = Join-Path $Dest "manifest.json"
    $destManifest = Get-Content $destManifestPath -Raw | ConvertFrom-Json
    $destManifest.background.service_worker = $script:WrapperWorker
    if ($destManifest.background.PSObject.Properties.Name -contains "type") {
        $destManifest.background.type = "module"
    } else {
        $destManifest.background | Add-Member -MemberType NoteProperty -Name "type" -Value "module"
    }
    # Drop update_url so the browser never tries to auto-update an unpacked copy
    $destManifest.PSObject.Properties.Remove("update_url")
    $destManifest | ConvertTo-Json -Depth 100 |
        Set-Content -Path $destManifestPath -Encoding UTF8
    Write-SuccessMessage "Patched manifest.json"

    # "key" must survive so the unpacked copy keeps the same extension ID and
    # the native messaging manifests written by setup.ps1 keep matching it.
    if (-not $destManifest.key) {
        Write-WarningMessage "manifest.json has no `"key`" - the unpacked copy will get a different"
        Write-WarningMessage "extension ID, and native messaging will need to be re-registered."
    }

    $info = [ordered]@{
        extensionId      = $ExtensionId
        extensionVersion = $extVersion
        sourceDir        = $sourceDir
        browser          = $Browser
        profile          = $BrowserProfile
        patcherVersion   = Get-ScriptVersion
    }
    $info | ConvertTo-Json | Set-Content -Path (Join-Path $Dest $script:PatchInfo) -Encoding UTF8

    Write-Host ""
    Show-NextSteps
    return $true
}

function Show-NextSteps {
    if ($Quiet) { return }

    Write-Host "Patched copy ready: $Dest" -ForegroundColor Green
    Write-Host ""
    Write-Host "Remaining steps have to be done in the browser:"
    Write-Host ""
    Write-Host "  1. Open the browser's extensions page (vivaldi://extensions) and"
    Write-Host "     disable - do not remove - the Web Store copy of Claude."
    Write-Host "     Both copies claim ID $ExtensionId, so leaving the store"
    Write-Host "     copy enabled causes a duplicate-ID error. Keeping it installed but"
    Write-Host "     disabled lets it keep auto-updating as the source for re-patching."
    Write-Host ""
    Write-Host "  2. Turn on Developer mode, click Load unpacked, and select:"
    Write-Host "       $Dest"
    Write-Host ""
    Write-Host "  3. Add the panel with this URL - the query string is required:"
    Write-Host "       chrome-extension://$ExtensionId/sidepanel.html$($script:PanelQuery)" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "     In Vivaldi: click + in the sidebar (Add Web Panel) and paste it."
    Write-Host ""
    Write-Host "Verify from the extension's service worker console:"
    Write-Host ""
    Write-Host "    chrome.storage.local.get('targetTabId').then(console.log)"
    Write-Host ""
    Write-Host "The value should change as you switch tabs. The panel reads it once, when"
    Write-Host "the panel document loads, so reload the panel to re-bind it to the current tab."
    Write-Host ""
    Write-Host "Re-run this script after the store copy updates:"
    Write-Host ""
    Write-Host "    .\$($script:ScriptName) -Check    # is the patched copy stale?"
    Write-Host "    .\$($script:ScriptName)           # rebuild it"
}

# =============================================================================
# Check / Uninstall
# =============================================================================

function Invoke-Check {
    if (-not (Test-Path $Dest)) {
        Write-WarningMessage "No patched copy at $Dest"
        Write-InfoMessage "Run .\$($script:ScriptName) to create one"
        return $false
    }

    $patchedVersion = $null
    $infoPath = Join-Path $Dest $script:PatchInfo
    if (Test-Path $infoPath) {
        $patchedVersion = (Get-Content $infoPath -Raw | ConvertFrom-Json).extensionVersion
    }
    if (-not $patchedVersion) {
        $patchedVersion = (Get-Content (Join-Path $Dest "manifest.json") -Raw | ConvertFrom-Json).version
    }

    $sourceDir = Resolve-SourceDir
    if (-not $sourceDir) {
        Write-WarningMessage "Patched copy is version $patchedVersion, but the store copy could not be found"
        return $false
    }

    $storeVersion = (Get-Content (Join-Path $sourceDir "manifest.json") -Raw | ConvertFrom-Json).version

    Write-InfoMessage "Store copy:   $storeVersion  ($sourceDir)"
    Write-InfoMessage "Patched copy: $patchedVersion  ($Dest)"

    if ($storeVersion -and $storeVersion -eq $patchedVersion) {
        Write-SuccessMessage "Patched copy is up to date"
        return $true
    }

    Write-WarningMessage "Patched copy is stale - re-run .\$($script:ScriptName) to rebuild it"
    return $false
}

function Invoke-Uninstall {
    if (-not (Test-Path $Dest)) {
        Write-InfoMessage "Nothing to remove - no patched copy at $Dest"
        return $true
    }

    if (-not (Test-Path (Join-Path $Dest "manifest.json"))) {
        Write-ErrorMessage "Refusing to remove $Dest - it does not look like an extension"
        return $false
    }

    if ($DryRun) {
        Write-DryRunMessage "Would remove $Dest"
        return $true
    }

    Remove-Item -Path $Dest -Recurse -Force
    Write-SuccessMessage "Removed $Dest"
    Write-InfoMessage "Remember to remove the unpacked extension from the browser's"
    Write-InfoMessage "extensions page and re-enable the Web Store copy."
    return $true
}

# =============================================================================
# Main
# =============================================================================

function Invoke-Main {
    if ($Help) { Show-Help; exit 0 }
    if ($Version) { Get-ScriptVersion; exit 0 }

    if ($Check -and $Uninstall) {
        Write-ErrorMessage "-Check and -Uninstall are mutually exclusive"
        exit 1
    }

    if (-not $Check) { Write-Header }

    $ok = if ($Uninstall) { Invoke-Uninstall }
          elseif ($Check) { Invoke-Check }
          else { Invoke-Patch }

    if (-not $ok) { exit 1 }
}

Invoke-Main
