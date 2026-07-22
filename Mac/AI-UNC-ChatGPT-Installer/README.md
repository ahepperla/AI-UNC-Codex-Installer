# AI @ UNC ChatGPT Installer for Mac

This is the macOS version of the UNC ChatGPT setup tool. It is a native SwiftUI app for macOS 14 or newer, and it configures Codex under the hood.

## Run The Release

Download `AI-UNC-ChatGPT-Installer-AppleSilicon.zip` from Releases, unzip it, and open `AI @ UNC ChatGPT Installer.app`.

## Build From Source

1. Open `AI-UNC-ChatGPT-Installer.xcodeproj`.
2. Select the `AI @ UNC ChatGPT Installer` scheme.
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

Setup is not marked complete unless the endpoint test succeeds. ChatGPT Desktop and Codex CLI installation options appear only after the UNC config is written and tested.

## What The App Changes

- Respects `CODEX_HOME` when that environment variable is visible to the app.
- Uses `~/.codex` when `CODEX_HOME` is not set.
- Sets `~/Documents/ChatGPT` as the default project parent path for new installs without creating a ChatGPT Desktop project.
- Uses `~/Documents/Codex` when it already exists, otherwise `~/Documents/ChatGPT`; these are parent folders, not automatic ChatGPT Desktop projects.
- Removes the old empty `~/Documents/Codex/ChatGPT` project folder if a previous installer run created it and it has no files.
- Saves a custom project parent path when the user changes it.
- Stores the API key in macOS Keychain by default.
- Backs up the existing `<Codex home>/config.toml`.
- Writes a fresh Codex config with `env_key = "UNC_AZURE_API_KEY"`.
- Defaults to `gpt-5.6-sol` with `medium` reasoning, the standard/default Codex effort.
- Shows a short, task-oriented description for every model and reasoning choice.
- Offers `low`, `medium`, `high`, `xhigh`, and `ultra` for `gpt-5.6-sol` and `gpt-5.6-terra`; offers `low` through `xhigh` for `gpt-5.6-luna` and the other currently verified reasoning models.
- Keeps `max` out of the installer because ChatGPT Desktop hides it by default, while preserving `max` in the generated catalog where the model supports it.
- Offers only approved Codex text/code deployments. Image, embedding, and audio deployments are intentionally excluded.
- Omits `model_reasoning_effort` for alternate models unless their supported values are known.
- When Codex is available, writes `<Codex home>/unc/model-catalog.json` by filtering Codex's current model catalog and points `model_catalog_json` at it so Codex shows only approved UNC models.
- Preserves each current Codex catalog entry's supported reasoning levels, using installer fallbacks only for synthesized `gpt-5.6` entries.
- Adds approved `gpt-5.6` entries to the filtered catalog when the local Codex catalog has not caught up yet.
- Creates `~/Library/LaunchAgents/edu.unc.codex.env.plist`.
- Creates `<Codex home>/unc/load_unc_codex_env.sh`.
- Tests `https://azureaiapi.cloud.unc.edu/openai/v1/responses`.
- Saves a setup receipt and diagnostics under `<Codex home>/unc`.
- Records the installer version/build date in receipts and diagnostics.

## ChatGPT And Codex Installation

The app finishes UNC configuration first. The final screen then offers ChatGPT Desktop and Codex CLI actions.

- Install ChatGPT Desktop for Apple Silicon.
- Install or reinstall Codex CLI.
- Open ChatGPT Desktop when it is detected.
- Open Codex CLI when it is detected.
- Open the configured project parent folder.

The desktop installer downloads the ChatGPT DMG, mounts it, copies `ChatGPT.app` into `/Applications` when possible or `~/Applications` otherwise, and unmounts the disk image. If the direct DMG download fails, the app opens the official ChatGPT download page instead.

The CLI installer uses the standalone Codex shell installer and prevents Codex from launching in the middle of setup.

Before a ChatGPT Desktop or Codex CLI install starts, the app warns the user that it can take a few minutes and that the installer should stay open.

## Finish Behavior

The finish screen has a dedicated `Finish` button. By default, clicking it tries to move the installer app to Trash, opens ChatGPT Desktop, and does not send a workspace path to the app, so a new desktop install does not get an automatic project entry.

Users can turn off the ChatGPT Desktop launch checkbox, open ChatGPT Desktop from the finish screen, or open the configured project parent folder when they want to add a project. If macOS blocks cleanup because the app is running from a read-only or translocated location, setup still finishes and the app quits cleanly.

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

During setup, the app seeds the current GUI environment directly from the key the user just entered. On later loads, the helper script reads the key from Keychain only if the environment variable is not already set, then runs:

```sh
/bin/launchctl setenv UNC_AZURE_API_KEY "$KEY"
```

Terminal windows that were already open before setup may not inherit the new environment. When the app opens Codex CLI, it reads the Keychain item directly for that Terminal session and exports `UNC_AZURE_API_KEY` before starting Codex.

## Troubleshooting

- If ChatGPT Desktop or Codex CLI is not detected, use the desktop download button or install Codex CLI manually from the final screen.
- If Codex CLI installation fails, expand `Install Details` and read the command output.
- If Keychain storage fails, confirm the user is in a normal macOS login session.
- If the LaunchAgent is not loaded, use the dashboard reload action.
- If the endpoint test fails with authentication, replace the API key.
- If the endpoint test fails with model or endpoint errors, confirm the selected UNC deployment supports the Responses API.

## Reset Options

`Reset Codex Config` backs up the current config before writing the recommended UNC config again.

`Reset Everything` is for support cases. It backs up the current config, restores a selected backup, deletes the Keychain item, unloads and removes the LaunchAgent, removes the helper script, and clears the GUI login environment variable.

`Uninstall Desktop`, `Uninstall CLI`, and `Uninstall All` are dashboard actions for removal. Uninstall All removes UNC credentials, LaunchAgent files, installer support files, and restores or removes the active Codex config. It also tries to remove ChatGPT Desktop and Codex CLI from safe known install locations.

Reset does not delete project parent folders or user files.

Reset Everything requires the user to select a config backup to restore.

## Distribution

For a small pilot, archive the app in Xcode and distribute the signed `.app` through an internal UNC channel.

For broader Mac distribution, sign and notarize with an Apple Developer ID certificate, then ship a DMG or managed software package. Do not enable App Sandbox unless the app is redesigned with a privileged helper or managed deployment profile.
