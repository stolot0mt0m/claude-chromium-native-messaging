# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed
- **Linux: Replaced Direct API Mode with Claude Code CLI integration**
  - Linux now uses Claude Code CLI's native messaging host (`~/.claude/chrome/chrome-native-host`) instead of a custom Node.js API host
  - `install-linux.sh` simplified: no longer requires Node.js build, npm, or API key — just verifies Claude Code is installed and copies manifests to additional browser directories
  - `uninstall-linux.sh` simplified: only removes manifests, no config/API key cleanup needed
  - Removed TypeScript source files (`src/`) and build toolchain — no longer needed
  - Updated `setup.sh` to remove `get_linux_api_host_path()` and Direct API Mode fallback
  - Linux prerequisite changed from "Node.js 18+ and Claude API key" to "Claude Code CLI"
- Updated documentation: README, `docs/linux-setup.md`, and `docs/linux-porting-analysis.md` rewritten to reflect Claude Code CLI approach

### Removed
- `src/api-client.ts` — Direct Claude API client (no longer needed)
- `src/config.ts` — API key configuration management (no longer needed)
- `src/host.ts` — Custom native messaging host entry point (no longer needed)
- `src/passthrough.ts` — Claude Desktop binary passthrough (no longer needed)
- `src/protocol.ts` — Chrome Native Messaging protocol implementation (no longer needed)
- `tsconfig.json` — TypeScript configuration (no longer needed)
- `package.json` build scripts and TypeScript devDependencies

### Fixed
- PowerShell `-Verbose` parameter conflict: removed explicit `[switch]$Verbose` declaration that clashed with the common parameter provided by `[CmdletBinding()]`; `Write-VerboseMessage` now checks `$VerbosePreference` instead
- Claude Desktop installed via Windows Store (MSIX) is now detected automatically (#7)

## [1.2.0] - 2026-02-22

### Added
- Google Chrome Canary, Beta, and Dev channel support with correct data directory paths per platform
- FAQ section in README covering browser detection, Chrome Canary setup, and custom paths
- Detailed custom browser path documentation with per-platform examples
- Expanded troubleshooting for "browser not detected" with root cause explanation

### Changed
- Browser detection now validates that data directories contain Chromium profile markers (Default/, Local State, Preferences) before reporting a browser as installed

### Fixed
- Chrome Canary now detected automatically on macOS (`Google/Chrome Canary`), Linux (`google-chrome-unstable`), and Windows (`Google\Chrome SxS\User Data`)
- Custom browser paths now properly validated via filesystem checks (absolute path, directory exists, readable)
- Browser detection no longer reports non-existent browsers — empty or marker-less directories are skipped

## [1.1.0] - 2026-01-28

### Added
- Shared browser configuration file (`config/browsers.json`) for consistency between scripts
- `--dry-run` / `-n` option to preview changes without making them
- `--verbose` / `-v` option for detailed output
- `--quiet` / `-q` option for minimal output
- `--backup` / `-b` option to create backups before overwriting manifests
- `--version` option to display version information
- Automatic backup creation before overwriting existing manifests
- Input validation for custom paths (prevents path traversal)
- Bash version check (requires 4.0+ for macOS users)
- Support for additional Claude Desktop installation paths:
  - Snap packages on Linux
  - Flatpak installations on Linux
- Test suite for both Bash and PowerShell scripts
- `CONTRIBUTING.md` with development guidelines
- `VERSION` file for version tracking

### Changed
- Refactored browser configuration to use shared JSON file
- Improved error handling with proper exit codes
- PowerShell functions renamed to avoid conflicts with built-in cmdlets
- Better cross-platform path handling
- Atomic manifest creation (uses temp files first)
- Consistent extension ID ordering (official ID first)

### Fixed
- `mapfile` compatibility issue on macOS (Bash 3.2)
- PowerShell `Write-Error` function overriding built-in cmdlet
- Silent failures when glob patterns don't match
- Missing browsers in PowerShell script (Arc, Orion, Falkon, Colibri)
- Missing Google Chrome in Bash script

### Security
- Added path validation to prevent directory traversal attacks
- Manifest files are created with proper permissions (644)
- Confirmation prompt before overwriting existing files

## [1.0.0] - 2026-01-27

### Added
- Initial release
- Support for 25+ Chromium-based browsers
- macOS and Linux support via Bash script
- Windows support via PowerShell script
- Interactive browser selection
- Claude Desktop and Claude Code manifest creation
- Uninstall functionality
- Custom path support
- Manual setup documentation

[1.2.0]: https://github.com/stolot0mt0m/claude-chromium-native-messaging/compare/v1.1.0...v1.2.0
[1.1.0]: https://github.com/stolot0mt0m/claude-chromium-native-messaging/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/stolot0mt0m/claude-chromium-native-messaging/releases/tag/v1.0.0
