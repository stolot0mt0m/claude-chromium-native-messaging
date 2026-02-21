# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
