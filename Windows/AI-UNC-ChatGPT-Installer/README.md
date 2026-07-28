# AI @ UNC ChatGPT Installer for Windows 11

This is the Windows version of the UNC ChatGPT setup tool. It is a PowerShell GUI, not a compiled Windows app, and it configures Codex under the hood.

## How To Run

1. Extract the zip file.
2. Double-click `Run AI UNC ChatGPT Installer.cmd`.
3. Paste the UNC Azure OpenAI API key.
4. Click `Run Recommended Setup`.

Most users should only need the recommended setup button. Troubleshooting and reset tools are under `Show Advanced Tools`.

## What It Does

- Detects Codex CLI and the ChatGPT/Codex Windows app.
- Respects `CODEX_HOME` when it is set.
- Uses `%USERPROFILE%\.codex` when `CODEX_HOME` is not set.
- Sets `Documents\ChatGPT` as the default project parent path for new installs without creating a ChatGPT Desktop project.
- Uses `Documents\Codex` when it already exists, otherwise `Documents\ChatGPT`; these are parent folders, not automatic ChatGPT Desktop projects.
- Removes the old empty `Documents\Codex\ChatGPT` project folder if a previous installer run created it and it has no files.
- Lets advanced users choose a different project parent folder.
- Defaults to `gpt-5.6-sol` with `medium` reasoning, the standard/default Codex effort.
- Shows a short, task-oriented description for every model and reasoning choice.
- Offers `low`, `medium`, `high`, `xhigh`, and `ultra` for `gpt-5.6-sol` and `gpt-5.6-terra`; offers `low` through `xhigh` for `gpt-5.6-luna` and the other currently verified reasoning models.
- Keeps `max` out of the installer because ChatGPT Desktop hides it by default, while preserving `max` in the generated catalog where the model supports it.
- Offers only approved Codex text/code deployments. Image, embedding, and audio deployments are intentionally excluded.
- Omits `model_reasoning_effort` for alternate models unless their supported values are known.
- When Codex CLI is available, writes `<Codex home>\unc\model-catalog.json` by filtering Codex's current model catalog and points `model_catalog_json` at it so Codex shows only approved UNC models.
- Preserves each current Codex catalog entry's supported reasoning levels, using installer fallbacks only for synthesized `gpt-5.6` entries.
- Adds approved `gpt-5.6` entries to the filtered catalog when the local Codex catalog has not caught up yet.
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

- Uses `winget` with OpenAI's exact Microsoft Store product ID for the new ChatGPT desktop app that includes Codex.
- Falls back to the official Codex PowerShell installer for CLI setup.
- Does not treat ChatGPT Classic as the Codex-capable desktop app.
- Opens OpenAI's stable official download page if desktop installation is blocked or cannot finish, with a note that managed computers may require Software Center or IT approval.
- Warns the user before install starts because it can take several minutes.
- Shows `Open ChatGPT Desktop` only when the desktop app is detected.
- Shows `Open Codex CLI` only when the CLI is detected.
- Opens ChatGPT Desktop by default after setup without sending a workspace path, so a new install does not get an automatic project entry.

## Files And Settings

- Codex home: `CODEX_HOME` when set, otherwise `%USERPROFILE%\.codex`
- Config: `<Codex home>\config.toml`
- Support directory: `<Codex home>\unc`
- Workspace setting: `<Codex home>\unc\workspace-path.txt`
- Default parent folder: `Documents\ChatGPT`, or `Documents\Codex` when `Documents\Codex` already exists
- API key: current user's `UNC_AZURE_API_KEY` environment variable

Existing Codex config files are copied to `config.toml.backup.<timestamp>` before this tool writes a new one.

## Notes

- The GUI is plain on purpose. It is meant to be easy to inspect and rerun.
- Users may need to open a new Terminal after setup so Windows picks up the updated environment variable.
- If install fails, use the log text in the app or save a support report from Advanced Tools.
- Reset removes installer-created environment/config changes but does not delete project parent folders or user files.
- Advanced Tools includes uninstall actions for ChatGPT Desktop, Codex CLI, and all UNC-specific setup. Uninstall UNC Setup restores or removes the active Codex config and removes installer support files, but leaves project parent folders and user files alone.
