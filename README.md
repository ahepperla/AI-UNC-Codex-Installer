# AI @ UNC ChatGPT Installer

This repository contains the Mac, Windows, and Linux/HPC installers for setting up ChatGPT Desktop and Codex CLI with UNC's Azure OpenAI-compatible endpoint.

The goal is simple: a novice user should be able to paste the UNC API key, run the recommended setup, and end with ChatGPT/Codex configured for UNC. The installers back up existing config files before writing anything new.

## Repository Layout

```text
Mac/
  AI-UNC-ChatGPT-Installer/
    README.md
    AI-UNC-ChatGPT-Installer.xcodeproj
    AI-UNC-ChatGPT-Installer/
Windows/
  AI-UNC-ChatGPT-Installer/
    README.md
    AI-UNC-ChatGPT-Installer.ps1
    Run AI UNC ChatGPT Installer.cmd
Linux/
  AI-UNC-ChatGPT-Installer/
    README.md
    setup-codex-unc-cli.sh
```

The platform folders use the same `AI-UNC-ChatGPT-Installer` naming scheme. The Mac app is a native SwiftUI project, the Windows installer is a PowerShell GUI, and the Linux version is a plain Bash script for terminal-only environments.

## Quick Start

### Mac

Download `AI-UNC-ChatGPT-Installer-AppleSilicon.zip` from Releases. Unzip it, open `AI @ UNC ChatGPT Installer.app`, paste the UNC Azure OpenAI API key, and click `Run Recommended Setup`.

The Mac release is for Apple Silicon Macs. Developers who want to build from source can open `Mac/AI-UNC-ChatGPT-Installer/AI-UNC-ChatGPT-Installer.xcodeproj`.

### Windows

Download `AI-UNC-ChatGPT-Installer-Windows.zip` from Releases. Unzip it, double-click `Run AI UNC ChatGPT Installer.cmd`, paste the UNC Azure OpenAI API key, and click `Run Recommended Setup`.

### Linux/HPC

Download `AI-UNC-ChatGPT-Installer-Linux-HPC.zip` from Releases. Unzip it on the cluster, then run:

```bash
chmod +x setup-codex-unc-cli.sh
./setup-codex-unc-cli.sh
```

The script prompts for the UNC Azure OpenAI API key, lets the user keep the recommended model defaults, writes the Codex config, updates `~/.bashrc`, and then asks whether to install Codex CLI.

## What The Installers Do

- Respect `CODEX_HOME` when it is set.
- Use the platform default Codex home when `CODEX_HOME` is not set.
- Set `Documents/ChatGPT` as the default project parent path for new Mac/Windows installs without creating a ChatGPT Desktop project.
- Use `Documents/Codex` when it already exists, otherwise `Documents/ChatGPT`; these are parent folders, not automatic ChatGPT Desktop projects.
- Remove the old empty `Documents/Codex/ChatGPT` project folder if a previous installer run created it and it has no files.
- Let advanced users choose a different project parent folder.
- Default to `gpt-5.6-sol` with `medium` reasoning, the standard/default Codex effort.
- Show a short, task-oriented description for every model and reasoning choice.
- On Mac and Windows, offer `low`, `medium`, `high`, `xhigh`, and `ultra` for `gpt-5.6-sol` and `gpt-5.6-terra`; offer `low` through `xhigh` for `gpt-5.6-luna` and the other currently verified reasoning models.
- Keep `max` out of the desktop installer because ChatGPT Desktop hides it by default. The generated catalog still preserves `max`, and the Linux/CLI installer still offers it where supported.
- Offer only approved Codex text/code deployments. Image, embedding, and audio deployments are intentionally excluded.
- Omit `model_reasoning_effort` for alternate models unless their supported values are known.
- Keep one active approved model in `config.toml` and, when Codex is available, write a filtered `model_catalog_json` generated from Codex's current model catalog so Codex does not show unsupported OpenAI models.
- Preserve each current Codex catalog entry's supported reasoning levels, using installer fallbacks only for synthesized `gpt-5.6` entries.
- Add approved `gpt-5.6` entries to the filtered catalog when the local Codex catalog has not caught up yet.
- Back up an existing `config.toml` before writing the UNC config.
- Test the UNC Responses API endpoint before marking setup complete.
- On Linux/HPC, append one marked API key block without replacing an existing `~/.bashrc`; reruns preserve its file identity, metadata, links, and all content outside that block.
- Offer ChatGPT Desktop and Codex CLI install or launch actions only after configuration succeeds.
- Open ChatGPT Desktop by default after setup without sending a workspace path, so a new install does not get an automatic project entry.
- Keep setup receipts and support diagnostics for troubleshooting.
- Record the installer version/build date in receipts and support diagnostics.
- Reset or uninstall installer-created settings without deleting project parent folders or user files.

## Security

The API key is not written to `config.toml` in the normal setup path.

- Mac stores the key in macOS Keychain and points Codex at `UNC_AZURE_API_KEY`.
- Windows stores `UNC_AZURE_API_KEY` in the current user's environment because Codex reads it through the `config.toml` `env_key` setting.

The Mac app has a plaintext fallback for support cases, but it should not be the default.

## Distribution

Do not commit local builds, zips, or DerivedData output to the repository. Use GitHub Releases or an internal UNC channel for packaged test builds.

Current local package names:

```text
AI-UNC-ChatGPT-Installer-AppleSilicon.zip
AI-UNC-ChatGPT-Installer-Windows.zip
AI-UNC-ChatGPT-Installer-Linux-HPC.zip
```

For wider Mac distribution, sign and notarize the app with an Apple Developer ID certificate. The app should not be sandboxed unless it is redesigned, because setup writes to the Codex home directory, LaunchAgents, and Keychain.

## Platform Docs

- [Mac installer notes](Mac/AI-UNC-ChatGPT-Installer/README.md)
- [Windows installer notes](Windows/AI-UNC-ChatGPT-Installer/README.md)
- [Linux/HPC installer notes](Linux/AI-UNC-ChatGPT-Installer/README.md)
