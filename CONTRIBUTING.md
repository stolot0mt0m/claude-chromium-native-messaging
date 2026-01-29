# Contributing to Claude Chromium Native Messaging

Thank you for your interest in contributing! This document provides guidelines and instructions for contributing to this project.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [Development Setup](#development-setup)
- [Making Changes](#making-changes)
- [Testing](#testing)
- [Submitting Changes](#submitting-changes)
- [Style Guidelines](#style-guidelines)
- [Adding Browser Support](#adding-browser-support)

## Code of Conduct

Please be respectful and constructive in all interactions. We welcome contributors of all skill levels.

## Getting Started

1. Fork the repository
2. Clone your fork:
   ```bash
   git clone https://github.com/YOUR_USERNAME/claude-chromium-native-messaging.git
   cd claude-chromium-native-messaging
   ```
3. Create a feature branch:
   ```bash
   git checkout -b feature/your-feature-name
   ```

## Development Setup

### Prerequisites

- **Bash 4.0+** (macOS users: `brew install bash`)
- **PowerShell 5.1+** (for Windows script development)
- **ShellCheck** for Bash linting: `brew install shellcheck` or `apt install shellcheck`
- **jq** for JSON validation: `brew install jq` or `apt install jq`

### Verify Setup

```bash
# Check Bash version
bash --version

# Check ShellCheck
shellcheck --version

# Validate browser config
jq . config/browsers.json
```

## Making Changes

### Project Structure

```
claude-chromium-native-messaging/
├── config/
│   └── browsers.json      # Shared browser configuration
├── scripts/
│   └── lib/               # Shared libraries (future)
├── tests/
│   ├── test_setup.sh      # Bash test suite
│   └── test_setup.ps1     # PowerShell test suite
├── docs/
│   └── manual-setup.md    # Manual setup guide
├── setup.sh               # Main Bash script
├── setup.ps1              # Main PowerShell script
├── CHANGELOG.md           # Version history
├── CONTRIBUTING.md        # This file
├── VERSION                # Current version
└── README.md              # Project documentation
```

### Key Files

- **config/browsers.json**: Single source of truth for browser paths. Both scripts read from this file.
- **setup.sh**: macOS/Linux setup script
- **setup.ps1**: Windows setup script

## Testing

### Running Tests

**Bash:**
```bash
./tests/test_setup.sh
```

**PowerShell:**
```powershell
.\tests\test_setup.ps1
```

### Test Coverage

Tests should cover:
- OS detection
- Browser detection
- Extension detection
- Manifest creation
- Backup functionality
- Uninstall functionality
- Input validation

### Writing Tests

Follow the existing test patterns:

```bash
# Bash test example
test_function_name() {
    local result
    result=$(function_to_test "input")
    assert_equals "expected" "$result" "Description of test"
}
```

```powershell
# PowerShell test example
function Test-FunctionName {
    $result = FunctionToTest -Input "value"
    Assert-Equals -Expected "expected" -Actual $result -Message "Description"
}
```

## Submitting Changes

### Before Submitting

1. **Run linters:**
   ```bash
   shellcheck setup.sh tests/test_setup.sh
   ```

2. **Run tests:**
   ```bash
   ./tests/test_setup.sh
   ```

3. **Test manually** on your platform

4. **Update documentation** if needed

5. **Update CHANGELOG.md** with your changes

### Pull Request Process

1. Update the `CHANGELOG.md` with your changes under `[Unreleased]`
2. Ensure all tests pass
3. Create a pull request with:
   - Clear title describing the change
   - Description of what and why
   - Any testing done
   - Screenshots if UI-related

### Commit Messages

Follow conventional commits:

```
type(scope): description

[optional body]

[optional footer]
```

Types:
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes (formatting, etc.)
- `refactor`: Code refactoring
- `test`: Adding or updating tests
- `chore`: Maintenance tasks

Examples:
```
feat(browsers): add support for Waterfox browser
fix(macos): handle spaces in browser paths correctly
docs(readme): update installation instructions
```

## Style Guidelines

### Bash

- Use `shellcheck` and fix all warnings
- Use `[[ ]]` for conditionals (not `[ ]`)
- Quote all variables: `"$variable"`
- Use `local` for function variables
- Use meaningful variable names
- Add comments for complex logic

```bash
# Good
local browser_path="$1"
if [[ -d "$browser_path" ]]; then
    process_browser "$browser_path"
fi

# Bad
p=$1
if [ -d $p ]; then
    process $p
fi
```

### PowerShell

- Use approved verbs for function names
- Use PascalCase for function names
- Use proper parameter declarations
- Include error handling with try/catch

```powershell
# Good
function Get-BrowserPath {
    param(
        [Parameter(Mandatory)]
        [string]$BrowserName
    )
    # ...
}

# Bad
function getpath($name) {
    # ...
}
```

### JSON

- Use 2-space indentation
- Include descriptions for complex fields
- Validate with `jq` before committing

## Adding Browser Support

To add support for a new browser:

### 1. Update browsers.json

Add an entry to `config/browsers.json`:

```json
{
  "name": "New Browser",
  "paths": {
    "macos": "NewBrowser/Data",
    "linux": "new-browser",
    "windows": "NewBrowser\\User Data"
  }
}
```

Use `null` for unsupported platforms:

```json
{
  "name": "macOS Only Browser",
  "paths": {
    "macos": "MacOnlyBrowser",
    "linux": null,
    "windows": null
  }
}
```

### 2. Test the Configuration

1. Install the browser on your system
2. Install the Claude extension in that browser
3. Run the setup script with `--dry-run`
4. Verify the paths are detected correctly
5. Run actual setup and test functionality

### 3. Update Documentation

- Add the browser to the supported browsers table in `README.md`
- Update `CHANGELOG.md`

### 4. Submit PR

Include in your PR:
- Browser name and version tested
- Platform(s) tested on
- Screenshot of successful extension connection (if possible)

## Questions?

Open an issue with the `question` label or start a discussion in the GitHub Discussions tab.

## Recognition

Contributors will be recognized in the README and release notes. Thank you for helping improve this project!
