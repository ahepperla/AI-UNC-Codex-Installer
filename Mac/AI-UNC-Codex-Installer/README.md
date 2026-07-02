# AI @ UNC Codex Installer for Mac

This is the macOS version of the UNC Codex setup tool. It is a native SwiftUI app for macOS 14 or newer.

## Build And Run

1. Open `AI-UNC-Codex-Installer.xcodeproj`.
2. Select the `AI @ UNC Codex Installer` scheme.
3. Choose a local signing identity if Xcode asks.
4. Build and run.

The project uses SwiftUI, Security.framework, Foundation, and AppKit. Local development builds use ad-hoc signing.

## Setup Flow

The first-run flow is:

1. Welcome
2. Configure API key
3. Back up old config
4. Write new config
5. Test connection
6. Finish

Setup is not marked complete unless the endpoint test succeeds. Codex installation options appear only after the UNC config is written and tested.

## What The App Changes

- Respects `CODEX_HOME` when that environment variable is visible to the app.
- Uses `~/.codex` when `CODEX_HOME` is not set.
- Creates `~/Documents/Codex` as the default workspace.
- Saves a custom workspace path when the user changes it.
- Stores the API key in macOS Keychain by default.
- Backs up the existing `<Codex home>/config.toml`.
- Writes a fresh Codex config with `env_key = "UNC_AZURE_API_KEY"`.
- Uses `medium` reasoning effort by default.
- Creates `~/Library/LaunchAgents/edu.unc.codex.env.plist`.
- Creates `<Codex home>/unc/load_unc_codex_env.sh`.
- Tests `https://azureaiapi.cloud.unc.edu/openai/v1/responses`.
- Saves a setup receipt and diagnostics under `<Codex home>/unc`.

## Codex Installation

The app finishes UNC configuration first. The final screen then offers Codex actions.

- Install Codex Desktop for Apple Silicon.
- Install or reinstall Codex CLI.
- Open Codex Desktop when it is detected.
- Open Codex CLI when it is detected.
- Open the configured workspace folder.

The desktop installer downloads the Codex DMG, mounts it, copies `Codex.app` into `/Applications` when possible or `~/Applications` otherwise, and unmounts the disk image. If the direct DMG download fails, the app opens the official Codex page instead.

Before a Codex install starts, the app warns the user that it can take a few minutes and that the installer should stay open.

## Finish Behavior

The finish screen has a dedicated `Finish` button. By default, clicking it opens Codex Desktop if it is installed, tries to move the installer app to Trash, and quits.

If macOS blocks the cleanup because the app is running from a read-only or translocated location, setup still finishes and the app quits cleanly. Users can uncheck the finish options to keep the dashboard open.

## Security Notes

Default setup keeps the API key out of `config.toml`.

- Keychain service: `UNC_AZURE_API_KEY`
- Account: current macOS username
- Codex config setting: `env_key = "UNC_AZURE_API_KEY"`

The app includes an advanced plaintext fallback:

```toml
experimental_bearer_token = "<USER_KEY>"
```

Use that only for support cases where Keychain or LaunchAgent behavior cannot work.

## LaunchAgent Behavior

The LaunchAgent is installed at:

```text
~/Library/LaunchAgents/edu.unc.codex.env.plist
```

It runs:

```text
<Codex home>/unc/load_unc_codex_env.sh
```

The helper script reads the key from Keychain and runs:

```sh
/bin/launchctl setenv UNC_AZURE_API_KEY "$KEY"
```

Terminal windows that were already open before setup may not inherit the new environment. When the app opens Codex CLI, it reads the Keychain item directly for that Terminal session and exports `UNC_AZURE_API_KEY` before starting Codex.

## Troubleshooting

- If Codex is not detected, use the desktop download button or install Codex manually from the final screen.
- If Homebrew installation fails, expand `Install Details` and read the command output.
- If Keychain storage fails, confirm the user is in a normal macOS login session.
- If the LaunchAgent is not loaded, use the dashboard reload action.
- If the endpoint test fails with authentication, replace the API key.
- If the endpoint test fails with model or endpoint errors, confirm the UNC deployment supports `gpt-5.5` and the Responses API.

## Reset Options

`Reset Codex Config` backs up the current config before writing the recommended UNC config again.

`Reset Everything` is for support cases. It backs up the current config, restores a selected backup, deletes the Keychain item, unloads and removes the LaunchAgent, removes the helper script, and clears the GUI login environment variable.

Reset Everything requires the user to select a config backup to restore.

## Distribution

For a small pilot, archive the app in Xcode and distribute the signed `.app` through an internal UNC channel.

For broader Mac distribution, sign and notarize with an Apple Developer ID certificate, then ship a DMG or managed software package. Do not enable App Sandbox unless the app is redesigned with a privileged helper or managed deployment profile.
