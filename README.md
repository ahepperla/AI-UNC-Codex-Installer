# AI @ UNC Codex Installer

AI @ UNC Codex Installer contains Mac and Windows setup tools for configuring OpenAI Codex to use the UNC Azure OpenAI-compatible endpoint.

Version 1 focuses on Codex. The Mac app code is organized around an `AIToolConfigurator` protocol so future tools such as Continue, Aider, Roo Code, Cline, and OpenAI SDK projects can be added without turning the app into a Codex-only utility.

## Repository Layout

```text
Mac/
  AI-UNC-Codex-Installer/
    AI-UNC-Codex-Installer.xcodeproj
    AI-UNC-Codex-Installer/
Windows/
  AI-UNC-Codex-Installer/
    AI-UNC-Codex-Installer.ps1
    Run AI UNC Codex Installer.cmd
    README-Windows.txt
```

The Mac and Windows installers use the same platform-folder pattern and the same `AI-UNC-Codex-Installer` project naming scheme.

## What The Installers Do

- Detect the Codex CLI and Codex desktop app in common platform locations.
- Respect `CODEX_HOME` for Codex config/support files when it is available; otherwise use the platform default Codex home.
- Create `Documents/Codex` as the default Codex workspace, with an advanced option to choose a different folder.
- Use `medium` reasoning effort by default, with a visible dropdown for `minimal`, `low`, `medium`, `high`, or `xhigh`.
- Prompt for a UNC Azure OpenAI API key.
- Store the API key securely for each platform: macOS Keychain on Mac and the current user's environment on Windows.
- Back up any existing `<Codex home>/config.toml` before writing a fresh config.
- Test `https://azureaiapi.cloud.unc.edu/openai/v1/responses` with the Responses API.
- Offer Codex installation only after UNC configuration succeeds.
- Show a setup receipt with config path, backup path, endpoint test time, and detected Codex install details.
- Open Codex from the configured workspace folder when possible.
- Provide troubleshooting actions, reset tools, and copyable diagnostics.

Mac-only behavior includes creating `~/Library/LaunchAgents/edu.unc.codex.env.plist`, creating `<Codex home>/unc/load_unc_codex_env.sh`, opening Mail with a support report, installing the Apple Silicon Codex desktop app from the official DMG, opening the Codex CLI with `UNC_AZURE_API_KEY` loaded directly from Keychain for that Terminal session, and optionally moving the installer app to Trash after successful setup.

## Build In Xcode

1. Open `Mac/AI-UNC-Codex-Installer/AI-UNC-Codex-Installer.xcodeproj`.
2. Select the `AI @ UNC Codex Installer` scheme.
3. Choose a local signing identity if Xcode asks. The project defaults to ad-hoc signing for local development.
4. Build and run.

The app targets macOS 14 or newer and uses SwiftUI, Security.framework, Foundation, and AppKit.

## Run Windows Installer

1. Open `Windows/AI-UNC-Codex-Installer`.
2. Double-click `Run AI UNC Codex Installer.cmd`.
3. Paste the UNC Azure OpenAI API key.
4. Click `Run Recommended Setup`.

The Windows installer is a PowerShell GUI for Windows 11. It is intentionally inspectable and does not require a compiled Windows app package.

## Run Mac App Locally

Run the app from Xcode. During setup, use the first-launch wizard:

1. Welcome
2. Configure API key
3. Backup old config
4. Write new config
5. Test connection
6. Finish

Setup is not marked complete unless the endpoint test succeeds. The app finishes UNC configuration first; the final screen then gives aligned Desktop App, CLI, and Workspace actions. Users can install the Apple Silicon Codex desktop app from the DMG, install the Codex CLI, open Codex Desktop when the desktop app is detected, open Codex CLI when the CLI is detected, or open the workspace folder.

Before starting a Codex install, the app warns users that the install can take a few minutes and that they should keep AI @ UNC Codex Installer open. The desktop app installer downloads `https://persistent.oaistatic.com/codex-app-prod/Codex.dmg`, mounts it, copies `Codex.app` into `/Applications` when writable or `~/Applications` otherwise, and unmounts the disk image. If the direct DMG link fails, the app opens the official Codex page instead.

The default Codex workspace is `~/Documents/Codex`. Users can change this from Advanced Options on the first screen; the chosen path is remembered for future launches. The default reasoning effort is `medium`; users can leave it selected or choose any supported reasoning effort before setup writes `config.toml`.

The Codex config directory follows `CODEX_HOME` when that environment variable is visible to the app. If `CODEX_HOME` is not set, the app uses `~/.codex`. When opening Codex from the installer, the app passes the same `CODEX_HOME` value to Codex so it reads the config that was written.

The finish screen has a dedicated `Finish` button. By default, clicking it opens the Codex desktop app if it is installed, tries to move the installer app to Trash, and quits after successful setup. If macOS is running the app from a read-only/translocated location and Trash cleanup is blocked, setup still finishes and the app quits cleanly. Users can uncheck those finish options to keep the dashboard open for troubleshooting.

For unsigned pilot builds, macOS may block first launch. Right-click the app, choose `Open`, then confirm the prompt.

## Internal Distribution

For a small internal pilot, archive the Mac app in Xcode and distribute the signed `.app` through an internal UNC channel. For broader Mac distribution, sign and notarize with an Apple Developer ID certificate, then ship a `.dmg` or managed software package.

For Windows pilots, zip the `Windows/AI-UNC-Codex-Installer` folder and share the zip through an internal UNC channel. Users should extract the zip before running `Run AI UNC Codex Installer.cmd`.

Current local test package names:

```text
AI @ UNC Codex Installer-test.zip
AI-UNC-Codex-Installer-Windows.zip
```

Because this utility writes to the Codex home directory, `~/Library/LaunchAgents`, and Keychain, do not enable App Sandbox unless the app is redesigned with a privileged helper or managed deployment profile.

## Security Model

On Mac, the default mode stores the API key in macOS Keychain:

- Keychain service: `UNC_AZURE_API_KEY`
- Account: current macOS username
- Codex config uses `env_key = "UNC_AZURE_API_KEY"`
- The API key is not written to `config.toml`
- Diagnostics only report whether the key exists

On Windows, the installer stores `UNC_AZURE_API_KEY` in the current user's environment because Codex reads it through the `config.toml` `env_key` setting.

The Mac app has an advanced fallback that can write:

```toml
experimental_bearer_token = "<USER_KEY>"
```

That fallback stores the API key in plaintext and should only be used when Keychain or LaunchAgent behavior cannot satisfy a support scenario.

## Mac LaunchAgent Behavior

The LaunchAgent is installed at:

```text
~/Library/LaunchAgents/edu.unc.codex.env.plist
```

It runs:

```text
<Codex home>/unc/load_unc_codex_env.sh
```

The helper script reads the API key from Keychain and runs:

```sh
/bin/launchctl setenv UNC_AZURE_API_KEY "$KEY"
```

The dashboard can reload the LaunchAgent and verifies both loaded state and whether `launchctl getenv UNC_AZURE_API_KEY` returns a value.

Interactive Terminal sessions that were already open before setup may not inherit `launchctl setenv` changes. When the installer opens the Codex CLI, it reads the Keychain item in that Terminal command, exports `UNC_AZURE_API_KEY` for that session, then starts Codex without printing the API key.

## Troubleshooting

- If Codex is not detected, use the app's desktop download button, install Codex manually, and return to the detection step.
- If Homebrew installation fails, expand `Install Details` in the app to read the command output.
- If Keychain storage fails, confirm the user is running in a normal macOS login session.
- If the LaunchAgent is not loaded, use the dashboard's reload button.
- If the endpoint test fails with authentication, replace the API key.
- If the endpoint test fails with model or endpoint errors, confirm the UNC deployment supports `gpt-5.5` and the Responses API.

## Reset Configuration

Use the dashboard's `Reset Codex Config` action. It backs up the current config before writing the recommended UNC config again. The app never deletes an existing config without creating a backup first.

Use `Reset Everything` when support needs to undo the installer changes. It:

- Backs up the current `<Codex home>/config.toml`.
- Restores a selected `config.toml.backup.*` file.
- Deletes the `UNC_AZURE_API_KEY` Keychain item.
- Unloads and removes the LaunchAgent plist.
- Removes the helper script.
- Clears the GUI login environment variable with `launchctl unsetenv`.

Reset Everything requires selecting a backup to restore.
