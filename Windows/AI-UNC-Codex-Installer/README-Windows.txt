AI @ UNC Codex Installer for Windows 11
=====================================

This is the lightweight Windows version of the UNC Codex setup tool.

How to run
----------
1. Extract the zip file.
2. Double-click "Run AI UNC Codex Installer.cmd".
3. Paste the UNC Azure OpenAI API key.
4. Click "Run Recommended Setup".

What it does
------------
- Detects Codex CLI and the Codex Windows app.
- Writes and tests the UNC config before starting a Codex install.
- Installs Codex with winget when available.
- Falls back to the official Codex PowerShell installer for CLI setup.
- Warns users before Codex install starts because it can take several minutes.
- Opens the Codex download page if automatic install cannot finish.
- Shows separate "Open Codex Desktop" and "Open Codex CLI" buttons only when
  those installs are detected.
- Creates Documents\Codex as the default Codex workspace.
- Lets advanced users choose a different workspace folder.
- Uses medium reasoning effort by default, with minimal, low, medium, high, and
  xhigh available from the visible reasoning dropdown.
- Saves UNC_AZURE_API_KEY as a user environment variable.
- Clears the visible API key box after config is written.
- Respects CODEX_HOME for Codex config/support files when it is available.
- Backs up and writes <Codex home>\config.toml.
- Tests the UNC Azure OpenAI Responses API endpoint.
- Can save a support report and reset the changes it made.
- Opens the Codex CLI from the configured workspace folder.
- Keeps troubleshooting tools under "Show Advanced Options" so most users only
  need the recommended setup button.

Notes
-----
- This is not a compiled Windows app. It is a PowerShell GUI, designed to be easy
  to inspect and rerun.
- The API key is stored in the current user's Windows environment because Codex
  reads the key through the config.toml env_key setting.
- Existing Codex config files are copied to config.toml.backup.<timestamp>
  before this tool writes a new one.
- If CODEX_HOME is not set, Codex home defaults to %USERPROFILE%\.codex.
- The selected workspace folder is remembered in <Codex home>\unc.
- Logs and receipts are written under <Codex home>\unc.
