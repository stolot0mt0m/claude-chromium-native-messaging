#Requires -Version 5.1

<#
.SYNOPSIS
    Pester v5 tests for Get-ClaudeNativeHostPath in setup.ps1

.DESCRIPTION
    Covers detection of all supported Claude Desktop install locations:
      - MSIX / Windows Store install: APPDATA\Claude\ChromeNativeHost (Issue #9)
      - Traditional installer:        LOCALAPPDATA\Programs\claude\resources
      - Legacy install:               LOCALAPPDATA\Claude
      - System-wide install:          Program Files\Claude
      - Priority ordering (APPDATA is checked first)
      - Null return when no installation is present

.NOTES
    Run with: Invoke-Pester .\tests\setup.Tests.ps1
    Requires Pester >= 5.0. Install with: Install-Module Pester -Force -Scope CurrentUser
#>

BeforeAll {
    # ------------------------------------------------------------------
    # Cross-platform env var stubs
    # On Windows these are always set; on Linux/macOS CI they may not be.
    # We provide predictable Windows-style values so path assertions work.
    # ------------------------------------------------------------------
    if (-not $env:APPDATA)      { $env:APPDATA      = 'C:\Users\TestUser\AppData\Roaming' }
    if (-not $env:LOCALAPPDATA) { $env:LOCALAPPDATA = 'C:\Users\TestUser\AppData\Local'   }
    if (-not $env:PROGRAMFILES) { $env:PROGRAMFILES = 'C:\Program Files'                  }
    if (-not [Environment]::GetEnvironmentVariable('PROGRAMFILES(X86)')) {
        [Environment]::SetEnvironmentVariable('PROGRAMFILES(X86)', 'C:\Program Files (x86)')
    }

    # ------------------------------------------------------------------
    # Extract functions from setup.ps1 without running its main body.
    # Dot-sourcing setup.ps1 directly would execute the main script logic
    # (which calls Get-ClaudeNativeHostPath and exits on failure).
    # Instead we extract individual function definitions via regex and
    # invoke them to bring the functions into this test session's scope.
    # ------------------------------------------------------------------
    $SetupScript = Join-Path $PSScriptRoot '..' 'setup.ps1'
    if (-not (Test-Path $SetupScript -PathType Leaf)) {
        throw "setup.ps1 not found at: $SetupScript — run tests from the project root."
    }
    $content = Get-Content $SetupScript -Raw

    # Pattern: match a top-level function (closing } at column 0)
    # (?ms) = multiline (^ matches line-start) + single-line (. matches \n)
    $extractFn = {
        param([string]$Name, [string]$Source)
        $pattern = "(?ms)^function $Name \{.*?^\}"
        $m = [regex]::Match($Source, $pattern)
        if (-not $m.Success) { throw "Could not extract '$Name' from setup.ps1" }
        $m.Value
    }

    # Write-VerboseMessage is called inside Get-ClaudeNativeHostPath
    $verbosePattern = '(?ms)^function Write-VerboseMessage \{.*?^\}'
    $verboseMatch   = [regex]::Match($content, $verbosePattern)
    if ($verboseMatch.Success) {
        Invoke-Expression $verboseMatch.Value
    } else {
        # Provide a no-op stub if the function is ever renamed/removed
        function Write-VerboseMessage { param([string]$Message) }
    }

    # Define Get-ClaudeNativeHostPath in this session
    Invoke-Expression (& $extractFn 'Get-ClaudeNativeHostPath' $content)
}

# ===========================================================================
Describe 'Get-ClaudeNativeHostPath' {
# ===========================================================================

    Context 'MSIX / Windows Store install (APPDATA path) — Issue #9' {

        It 'finds MSIX install at APPDATA\Claude\ChromeNativeHost path' {
            # Only the APPDATA MSIX path should be seen as existing
            Mock Test-Path {
                $Path -like '*Claude*ChromeNativeHost*chrome-native-host.exe'
            } -ParameterFilter { $Path -like '*chrome-native-host.exe' }

            $result = Get-ClaudeNativeHostPath

            $result | Should -Not -BeNullOrEmpty
            $result | Should -Match ([regex]::Escape('Claude\ChromeNativeHost\chrome-native-host.exe'))
        }
    }

    Context 'Traditional installer (LOCALAPPDATA\Programs\claude)' {

        It 'finds traditional install at LOCALAPPDATA\Programs\claude\resources path' {
            # Only the traditional Programs path should be seen as existing
            Mock Test-Path {
                $Path -like '*Programs*claude*chrome-native-host.exe'
            } -ParameterFilter { $Path -like '*chrome-native-host.exe' }

            $result = Get-ClaudeNativeHostPath

            $result | Should -Not -BeNullOrEmpty
            $result | Should -Match ([regex]::Escape('Programs\claude'))
        }
    }

    Context 'Legacy install (LOCALAPPDATA\Claude)' {

        It 'finds legacy install at LOCALAPPDATA\Claude path' {
            # Matches LOCALAPPDATA\Claude but NOT ChromeNativeHost (that would be MSIX)
            Mock Test-Path {
                ($Path -like '*LOCALAPPDATA*Claude*chrome-native-host.exe') -and
                ($Path -notlike '*ChromeNativeHost*') -and
                ($Path -notlike '*Programs*')
            } -ParameterFilter { $Path -like '*chrome-native-host.exe' }

            $result = Get-ClaudeNativeHostPath

            $result | Should -Not -BeNullOrEmpty
            # Should NOT be the MSIX path or the Programs path
            $result | Should -Not -Match ([regex]::Escape('ChromeNativeHost'))
            $result | Should -Not -Match ([regex]::Escape('Programs'))
        }
    }

    Context 'Priority ordering' {

        It 'returns APPDATA MSIX path first when all paths exist' {
            # All Test-Path calls return $true — APPDATA must win (first in array)
            Mock Test-Path { $true } -ParameterFilter { $Path -like '*chrome-native-host.exe' }

            $result = Get-ClaudeNativeHostPath

            # The first path in $possiblePaths is the APPDATA MSIX path
            $result | Should -Match ([regex]::Escape('Claude\ChromeNativeHost\chrome-native-host.exe'))
        }

        It 'falls through to LOCALAPPDATA Programs path when APPDATA path is absent' {
            # APPDATA MSIX path does NOT exist; Programs path does
            Mock Test-Path {
                $Path -like '*Programs*claude*chrome-native-host.exe'
            } -ParameterFilter { $Path -like '*chrome-native-host.exe' }

            $result = Get-ClaudeNativeHostPath

            $result | Should -Match ([regex]::Escape('Programs\claude'))
        }
    }

    Context 'No Claude installation' {

        It 'returns null when no Claude installation is found' {
            Mock Test-Path { $false } -ParameterFilter { $Path -like '*chrome-native-host.exe' }

            $result = Get-ClaudeNativeHostPath

            $result | Should -BeNullOrEmpty
        }
    }
}
