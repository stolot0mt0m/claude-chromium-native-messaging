# Test suite for Claude Native Messaging Setup (PowerShell)
# Run with: .\tests\test_setup.ps1

#Requires -Version 5.1

$ErrorActionPreference = "Stop"

# =============================================================================
# Test Framework
# =============================================================================

$script:ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$script:ProjectDir = Split-Path -Parent $ScriptDir
$script:SetupScript = Join-Path $ProjectDir "setup.ps1"
$script:ConfigFile = Join-Path $ProjectDir "config\browsers.json"

# Test counters
$script:TestsRun = 0
$script:TestsPassed = 0
$script:TestsFailed = 0

# Temp directory for test artifacts
$script:TestTmpDir = $null

# =============================================================================
# Test Utilities
# =============================================================================

function Initialize-TestEnvironment {
    $script:TestTmpDir = Join-Path $env:TEMP "claude-test-$(Get-Random)"
    New-Item -ItemType Directory -Path $script:TestTmpDir -Force | Out-Null
    Write-Host "Test environment: $script:TestTmpDir"
}

function Remove-TestEnvironment {
    if ($script:TestTmpDir -and (Test-Path $script:TestTmpDir)) {
        Remove-Item -Path $script:TestTmpDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

function Assert-Equals {
    param(
        [Parameter(Mandatory)]$Expected,
        [Parameter(Mandatory)]$Actual,
        [string]$Message = "Values should be equal"
    )

    $script:TestsRun++

    if ($Expected -eq $Actual) {
        $script:TestsPassed++
        Write-Host "PASS: $Message" -ForegroundColor Green
        return $true
    }
    else {
        $script:TestsFailed++
        Write-Host "FAIL: $Message" -ForegroundColor Red
        Write-Host "  Expected: '$Expected'"
        Write-Host "  Actual:   '$Actual'"
        return $false
    }
}

function Assert-NotEmpty {
    param(
        [Parameter(Mandatory)]$Value,
        [string]$Message = "Value should not be empty"
    )

    $script:TestsRun++

    if (-not [string]::IsNullOrWhiteSpace($Value)) {
        $script:TestsPassed++
        Write-Host "PASS: $Message" -ForegroundColor Green
        return $true
    }
    else {
        $script:TestsFailed++
        Write-Host "FAIL: $Message (value was empty)" -ForegroundColor Red
        return $false
    }
}

function Assert-FileExists {
    param(
        [Parameter(Mandatory)][string]$Path,
        [string]$Message = "File should exist"
    )

    $script:TestsRun++

    if (Test-Path $Path -PathType Leaf) {
        $script:TestsPassed++
        Write-Host "PASS: $Message" -ForegroundColor Green
        return $true
    }
    else {
        $script:TestsFailed++
        Write-Host "FAIL: $Message (file does not exist: $Path)" -ForegroundColor Red
        return $false
    }
}

function Assert-DirectoryExists {
    param(
        [Parameter(Mandatory)][string]$Path,
        [string]$Message = "Directory should exist"
    )

    $script:TestsRun++

    if (Test-Path $Path -PathType Container) {
        $script:TestsPassed++
        Write-Host "PASS: $Message" -ForegroundColor Green
        return $true
    }
    else {
        $script:TestsFailed++
        Write-Host "FAIL: $Message (directory does not exist: $Path)" -ForegroundColor Red
        return $false
    }
}

function Assert-Contains {
    param(
        [Parameter(Mandatory)][string]$Haystack,
        [Parameter(Mandatory)][string]$Needle,
        [string]$Message = "String should contain substring"
    )

    $script:TestsRun++

    if ($Haystack.Contains($Needle)) {
        $script:TestsPassed++
        Write-Host "PASS: $Message" -ForegroundColor Green
        return $true
    }
    else {
        $script:TestsFailed++
        Write-Host "FAIL: $Message" -ForegroundColor Red
        Write-Host "  Looking for: '$Needle'"
        return $false
    }
}

# =============================================================================
# Unit Tests
# =============================================================================

function Test-VersionFileExists {
    Write-Host "`n=== Test: VERSION file exists ===" -ForegroundColor Cyan
    $versionFile = Join-Path $script:ProjectDir "VERSION"
    Assert-FileExists -Path $versionFile -Message "VERSION file should exist"
}

function Test-ConfigFileExists {
    Write-Host "`n=== Test: Config file exists ===" -ForegroundColor Cyan
    Assert-FileExists -Path $script:ConfigFile -Message "browsers.json should exist"
}

function Test-ConfigFileValidJson {
    Write-Host "`n=== Test: Config file is valid JSON ===" -ForegroundColor Cyan

    $script:TestsRun++

    try {
        $content = Get-Content $script:ConfigFile -Raw
        $null = $content | ConvertFrom-Json
        $script:TestsPassed++
        Write-Host "PASS: browsers.json is valid JSON" -ForegroundColor Green
    }
    catch {
        $script:TestsFailed++
        Write-Host "FAIL: browsers.json is not valid JSON - $_" -ForegroundColor Red
    }
}

function Test-ConfigHasBrowsers {
    Write-Host "`n=== Test: Config contains browsers ===" -ForegroundColor Cyan

    try {
        $config = Get-Content $script:ConfigFile -Raw | ConvertFrom-Json
        $browserCount = $config.browsers.Count

        $script:TestsRun++
        if ($browserCount -gt 0) {
            $script:TestsPassed++
            Write-Host "PASS: Config contains $browserCount browsers" -ForegroundColor Green
        }
        else {
            $script:TestsFailed++
            Write-Host "FAIL: Config has no browsers" -ForegroundColor Red
        }
    }
    catch {
        $script:TestsRun++
        $script:TestsFailed++
        Write-Host "FAIL: Could not parse config - $_" -ForegroundColor Red
    }
}

function Test-ConfigBrowsersHaveRequiredFields {
    Write-Host "`n=== Test: Browsers have required fields ===" -ForegroundColor Cyan

    try {
        $config = Get-Content $script:ConfigFile -Raw | ConvertFrom-Json
        $invalidCount = 0

        foreach ($browser in $config.browsers) {
            if (-not $browser.name -or -not $browser.paths) {
                $invalidCount++
            }
        }

        $script:TestsRun++
        if ($invalidCount -eq 0) {
            $script:TestsPassed++
            Write-Host "PASS: All browsers have required fields (name, paths)" -ForegroundColor Green
        }
        else {
            $script:TestsFailed++
            Write-Host "FAIL: $invalidCount browsers missing required fields" -ForegroundColor Red
        }
    }
    catch {
        $script:TestsRun++
        $script:TestsFailed++
        Write-Host "FAIL: Could not parse config - $_" -ForegroundColor Red
    }
}

function Test-SetupScriptExists {
    Write-Host "`n=== Test: Setup script exists ===" -ForegroundColor Cyan
    Assert-FileExists -Path $script:SetupScript -Message "setup.ps1 should exist"
}

function Test-SetupHelpOption {
    Write-Host "`n=== Test: Setup script -Help option ===" -ForegroundColor Cyan

    $output = & powershell -NoProfile -ExecutionPolicy Bypass -File $script:SetupScript -Help 2>&1
    $outputString = $output -join "`n"

    Assert-Contains -Haystack $outputString -Needle "USAGE" -Message "Help output should contain USAGE"
    Assert-Contains -Haystack $outputString -Needle "-Uninstall" -Message "Help output should mention -Uninstall"
    Assert-Contains -Haystack $outputString -Needle "-DryRun" -Message "Help output should mention -DryRun"
    Assert-Contains -Haystack $outputString -Needle "-Backup" -Message "Help output should mention -Backup"
}

function Test-SetupVersionOption {
    Write-Host "`n=== Test: Setup script -Version option ===" -ForegroundColor Cyan

    $output = & powershell -NoProfile -ExecutionPolicy Bypass -File $script:SetupScript -Version 2>&1
    $outputString = $output -join "`n"

    Assert-Contains -Haystack $outputString -Needle "Claude Native Messaging Setup" -Message "Version output should contain script name"
}

function Test-ExtensionIdsConsistent {
    Write-Host "`n=== Test: Extension IDs are consistent ===" -ForegroundColor Cyan

    $officialId = "fcoeoabgfenejglbffodgkkbkcdhcgfn"

    # Check in setup.ps1
    $psContent = Get-Content $script:SetupScript -Raw
    $psMatch = [regex]::Match($psContent, 'CLAUDE_OFFICIAL_EXTENSION_ID\s*=\s*"([^"]+)"')
    $psId = if ($psMatch.Success) { $psMatch.Groups[1].Value } else { "" }

    # Check in config
    $config = Get-Content $script:ConfigFile -Raw | ConvertFrom-Json
    $configId = $config.extension_ids.official.id

    Assert-Equals -Expected $officialId -Actual $psId -Message "PowerShell script should have correct official extension ID"
    Assert-Equals -Expected $officialId -Actual $configId -Message "Config should have correct official extension ID"
}

function Test-BuiltinBrowserConfigsExist {
    Write-Host "`n=== Test: Built-in browser configs exist in script ===" -ForegroundColor Cyan

    $psContent = Get-Content $script:SetupScript -Raw

    $script:TestsRun++
    if ($psContent -match 'BUILTIN_BROWSER_CONFIGS') {
        $script:TestsPassed++
        Write-Host "PASS: Built-in browser configs found in setup.ps1" -ForegroundColor Green
    }
    else {
        $script:TestsFailed++
        Write-Host "FAIL: Built-in browser configs not found in setup.ps1" -ForegroundColor Red
    }
}

# =============================================================================
# Integration Tests
# =============================================================================

function Test-JsonConfigHasWindowsPaths {
    Write-Host "`n=== Test: JSON config has Windows paths ===" -ForegroundColor Cyan

    try {
        $config = Get-Content $script:ConfigFile -Raw | ConvertFrom-Json
        $withWindowsPaths = 0
        $total = $config.browsers.Count

        foreach ($browser in $config.browsers) {
            if ($browser.paths.windows) {
                $withWindowsPaths++
            }
        }

        $script:TestsRun++
        if ($withWindowsPaths -gt 0) {
            $script:TestsPassed++
            Write-Host "PASS: $withWindowsPaths of $total browsers have Windows paths" -ForegroundColor Green
        }
        else {
            $script:TestsFailed++
            Write-Host "FAIL: No browsers have Windows paths" -ForegroundColor Red
        }
    }
    catch {
        $script:TestsRun++
        $script:TestsFailed++
        Write-Host "FAIL: Could not parse config - $_" -ForegroundColor Red
    }
}

function Test-AllPlatformsHavePaths {
    Write-Host "`n=== Test: Browsers have paths for multiple platforms ===" -ForegroundColor Cyan

    try {
        $config = Get-Content $script:ConfigFile -Raw | ConvertFrom-Json
        $platforms = @{
            macos = 0
            linux = 0
            windows = 0
        }

        foreach ($browser in $config.browsers) {
            if ($browser.paths.macos) { $platforms.macos++ }
            if ($browser.paths.linux) { $platforms.linux++ }
            if ($browser.paths.windows) { $platforms.windows++ }
        }

        Write-Host "  macOS paths: $($platforms.macos)"
        Write-Host "  Linux paths: $($platforms.linux)"
        Write-Host "  Windows paths: $($platforms.windows)"

        $script:TestsRun++
        if ($platforms.macos -gt 0 -and $platforms.linux -gt 0 -and $platforms.windows -gt 0) {
            $script:TestsPassed++
            Write-Host "PASS: All platforms have browser paths" -ForegroundColor Green
        }
        else {
            $script:TestsFailed++
            Write-Host "FAIL: Some platforms missing browser paths" -ForegroundColor Red
        }
    }
    catch {
        $script:TestsRun++
        $script:TestsFailed++
        Write-Host "FAIL: Could not parse config - $_" -ForegroundColor Red
    }
}

# =============================================================================
# Main Test Runner
# =============================================================================

function Invoke-Tests {
    Write-Host "===========================================================" -ForegroundColor Cyan
    Write-Host "  Claude Native Messaging Setup - Test Suite (PowerShell)" -ForegroundColor Cyan
    Write-Host "===========================================================" -ForegroundColor Cyan
    Write-Host ""

    # Run unit tests
    Write-Host "Running Unit Tests..." -ForegroundColor Cyan
    Test-VersionFileExists
    Test-ConfigFileExists
    Test-ConfigFileValidJson
    Test-ConfigHasBrowsers
    Test-ConfigBrowsersHaveRequiredFields
    Test-SetupScriptExists
    Test-SetupHelpOption
    Test-SetupVersionOption
    Test-ExtensionIdsConsistent
    Test-BuiltinBrowserConfigsExist

    # Run integration tests
    Write-Host "`nRunning Integration Tests..." -ForegroundColor Cyan
    Test-JsonConfigHasWindowsPaths
    Test-AllPlatformsHavePaths

    # Print summary
    Write-Host ""
    Write-Host "===========================================================" -ForegroundColor Cyan
    Write-Host "Tests run: $script:TestsRun"
    Write-Host "Passed: $script:TestsPassed" -ForegroundColor Green
    Write-Host "Failed: $script:TestsFailed" -ForegroundColor Red
    Write-Host "===========================================================" -ForegroundColor Cyan

    if ($script:TestsFailed -gt 0) {
        exit 1
    }
}

# Run tests
Invoke-Tests
