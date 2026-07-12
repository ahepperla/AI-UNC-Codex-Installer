# AI @ UNC ChatGPT Installer for Windows 11

This is the Windows version of the UNC ChatGPT setup tool. It is a PowerShell GUI, not a compiled Windows app, and it configures Codex under the hood.

## How To Run

1. Extract the zip file.
2. Double-click `Run AI UNC ChatGPT Installer.cmd`.
3. Paste the UNC Azure OpenAI API key.
4. Click `Run Recommended Setup`.

Most users should only need the recommended setup button. Troubleshooting and reset tools are under `Show Advanced Options`.

## What It Does

- Detects Codex CLI and the ChatGPT/Codex Windows app.
- Respects `CODEX_HOME` when it is set.
- Uses `%USERPROFILE%\.codex` when `CODEX_HOME` is not set.
- Creates `Documents\ChatGPT` as the default workspace for new installs.
- Keeps using `Documents\Codex` when that workspace folder already exists.
- Lets advanced users choose a different workspace folder.
- Defaults to `gpt-5.5` with `medium` reasoning.
- Offers only approved Codex text/code deployments. Image, embedding, and audio deployments are intentionally excluded.
- Omits `model_reasoning_effort` for alternate models unless their supported values are known.
- Writes and tests the UNC config before offering ChatGPT Desktop or Codex CLI install/open actions.
- Backs up the existing `<Codex home>\config.toml`.
- Saves `UNC_AZURE_API_KEY` as a user environment variable.
- Clears the visible API key box after config is written.
- Tests the UNC Azure OpenAI Responses API endpoint.
- Saves logs and receipts under `<Codex home>\unc`.
- Records the installer version/build date in receipts and support reports.
- Can save a support report and reset the changes it made.

## ChatGPT And Codex Installation

After the UNC config succeeds, the installer can help install ChatGPT Desktop or Codex CLI.

- Uses `winget` when available, starting with the Microsoft Store package for ChatGPT Desktop.
- Falls back to the official Codex PowerShell installer for CLI setup.
- Opens the ChatGPT Desktop and Codex CLI download pages if automatic install cannot finish.
- Warns the user before install starts because it can take several minutes.
- Shows `Open ChatGPT Desktop` only when the desktop app is detected.
- Shows `Open Codex CLI` only when the CLI is detected.

## Files And Settings

- Codex home: `CODEX_HOME` when set, otherwise `%USERPROFILE%\.codex`
- Config: `<Codex home>\config.toml`
- Support directory: `<Codex home>\unc`
- Workspace setting: `<Codex home>\unc\workspace-path.txt`
- Default workspace: `Documents\ChatGPT`, unless `Documents\Codex` already exists
- API key: current user's `UNC_AZURE_API_KEY` environment variable

Existing Codex config files are copied to `config.toml.backup.<timestamp>` before this tool writes a new one.

## Notes

- The GUI is plain on purpose. It is meant to be easy to inspect and rerun.
- Users may need to open a new Terminal after setup so Windows picks up the updated environment variable.
- If install fails, use the log text in the app or save a support report from Advanced Options.
- Reset removes installer-created environment/config changes but does not delete the workspace folder or user files.
