# AI @ UNC Codex Installer

This repository contains the Mac, Windows, and Linux/HPC installers for setting up OpenAI Codex with UNC's Azure OpenAI-compatible endpoint.

The goal is simple: a novice user should be able to paste the UNC API key, run the recommended setup, and end with a working Codex config. The installers back up existing config files before writing anything new.

## Repository Layout

```text
Mac/
  AI-UNC-Codex-Installer/
    README.md
    AI-UNC-Codex-Installer.xcodeproj
    AI-UNC-Codex-Installer/
Windows/
  AI-UNC-Codex-Installer/
    README.md
    AI-UNC-Codex-Installer.ps1
    Run AI UNC Codex Installer.cmd
Linux/
  AI-UNC-Codex-Installer/
    README.md
    setup-codex-unc-cli.sh
```

The platform folders use the same `AI-UNC-Codex-Installer` naming scheme. The Mac app is a native SwiftUI project, the Windows installer is a PowerShell GUI, and the Linux version is a plain Bash script for terminal-only environments.

## Quick Start

### Mac

Download `AI-UNC-Codex-Installer-AppleSilicon.zip` from Releases. Unzip it, open `AI @ UNC Codex Installer.app`, paste the UNC Azure OpenAI API key, and click `Run Recommended Setup`.

The Mac release is for Apple Silicon Macs. Developers who want to build from source can open `Mac/AI-UNC-Codex-Installer/AI-UNC-Codex-Installer.xcodeproj`.

### Windows

Download `AI-UNC-Codex-Installer-Windows.zip` from Releases. Unzip it, double-click `Run AI UNC Codex Installer.cmd`, paste the UNC Azure OpenAI API key, and click `Run Recommended Setup`.

### Linux/HPC

Download `AI-UNC-Codex-Installer-Linux-HPC.zip` from Releases. Unzip it on the cluster, then run:

```bash
chmod +x setup-codex-unc-cli.sh
./setup-codex-unc-cli.sh
```

The script prompts for the UNC Azure OpenAI API key, lets the user keep the recommended model defaults, writes the Codex config, updates `~/.bashrc`, and then asks whether to install Codex CLI.

## What The Installers Do

- Respect `CODEX_HOME` when it is set.
- Use the platform default Codex home when `CODEX_HOME` is not set.
- Create `Documents/Codex` as the default workspace.
- Let advanced users choose a different workspace folder.
- Default to `gpt-5.5` with `medium` reasoning.
- Offer only approved Codex text/code deployments. Image, embedding, and audio deployments are intentionally excluded.
- Omit `model_reasoning_effort` for alternate models unless their supported values are known.
- Back up an existing `config.toml` before writing the UNC config.
- Test the UNC Responses API endpoint before marking setup complete.
- Offer Codex install or launch actions only after configuration succeeds.
- Keep setup receipts and support diagnostics for troubleshooting.

## Security

The API key is not written to `config.toml` in the normal setup path.

- Mac stores the key in macOS Keychain and points Codex at `UNC_AZURE_API_KEY`.
- Windows stores `UNC_AZURE_API_KEY` in the current user's environment because Codex reads it through the `config.toml` `env_key` setting.

The Mac app has a plaintext fallback for support cases, but it should not be the default.

## Distribution

Do not commit local builds, zips, or DerivedData output to the repository. Use GitHub Releases or an internal UNC channel for packaged test builds.

Current local package names:

```text
AI-UNC-Codex-Installer-AppleSilicon.zip
AI-UNC-Codex-Installer-Windows.zip
AI-UNC-Codex-Installer-Linux-HPC.zip
```

For wider Mac distribution, sign and notarize the app with an Apple Developer ID certificate. The app should not be sandboxed unless it is redesigned, because setup writes to the Codex home directory, LaunchAgents, and Keychain.

## Platform Docs

- [Mac installer notes](Mac/AI-UNC-Codex-Installer/README.md)
- [Windows installer notes](Windows/AI-UNC-Codex-Installer/README.md)
- [Linux/HPC installer notes](Linux/AI-UNC-Codex-Installer/README.md)
