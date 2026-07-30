# AI @ UNC ChatGPT Installer for Windows 11

This is a native Windows application that configures ChatGPT Desktop and Codex CLI for UNC's managed Azure OpenAI endpoint. Users launch one graphical `.exe`; there is no launcher script, extraction step, or console window to keep open. The app is self-contained and does not require a separate .NET installation.

## How To Run

1. Download `AI-UNC-ChatGPT-Installer-Windows.exe`.
2. Double-click the downloaded file.
3. Paste the UNC Azure OpenAI API key.
4. Keep the recommended model and reasoning choices unless a different approved model is needed.
5. Click `Run Recommended Setup`.

The app warns before closing while work is active and waits for cancellation to finish cleanly. Troubleshooting and recovery actions are on the `Advanced Tools` tab.

## What It Does

- Detects the current `OpenAI.Codex` Windows package and the standalone Codex CLI.
- Respects `CODEX_HOME` when set; otherwise uses `%USERPROFILE%\.codex`.
- Uses `Documents\Codex` as the project parent when that existing folder is present; otherwise uses `Documents\ChatGPT`.
- Does not pass the project parent to ChatGPT Desktop, so setup does not create an empty project in the sidebar.
- Defaults to `gpt-5.6-sol` with `medium` reasoning.
- Shows novice-oriented descriptions for every approved model and reasoning choice.
- Writes an approved-model catalog when a compatible Codex CLI is available.
- Refreshes the config and model catalog after installing the CLI on a new computer.
- Backs up the current `config.toml` before the first setup write.
- Stores `UNC_AZURE_API_KEY` for the current Windows user in the normal setup path.
- Offers a restricted-per-user plaintext config fallback only for compatibility cases.
- Tests the UNC Responses API before reporting a verified setup.
- Saves logs, a setup receipt, and optional support reports without including the API key.
- Can reset installer-created configuration or uninstall the desktop app, CLI, and UNC setup.

## Application Installation

Desktop and CLI installation are independent. A successful ChatGPT Desktop install does not prevent the app from installing a missing CLI.

- Downloads OpenAI's official Microsoft web installer first.
- Validates the web installer's Authenticode trust and Microsoft signer before running it.
- Falls back to `winget` with the exact Microsoft Store product ID `9PLM9XGG6VKS`.
- Uses OpenAI's official Codex PowerShell installer as a hidden subprocess only when the standalone CLI is missing.
- Opens the stable official OpenAI download pages if automatic installation is blocked.
- Detects only the `OpenAI.Codex` package, not ChatGPT Classic or unrelated Start menu entries.

The main installer is a native GUI application. PowerShell is not used for its interface, configuration logic, endpoint testing, detection, logging, or desktop-app installation.

## Security

The installer does not provide UNC AI access by itself. It requires a valid UNC Azure OpenAI API key issued through UNC's existing authorization process, and the resulting ChatGPT/Codex configuration is not functional without that credential.

The app runs as the current user and does not request administrator access. It writes only the current user's Codex configuration and support files, stores the normal credential in that user's environment, verifies the downloaded Microsoft desktop installer before execution, and avoids placing the key in logs, reports, or process command lines. The tool automates steps a user could perform manually; it does not add a new service, background agent, or access path.

Internal production distribution should Authenticode-sign the final `.exe` with UNC's Windows code-signing certificate. Unsigned test builds may trigger a Microsoft Defender SmartScreen warning.

## Files And Settings

- Codex home: `CODEX_HOME`, otherwise `%USERPROFILE%\.codex`
- Config: `<Codex home>\config.toml`
- Support directory: `<Codex home>\unc`
- Workspace setting: `<Codex home>\unc\workspace-path.txt`
- Default project parent: `Documents\ChatGPT`, or existing `Documents\Codex`
- Credential: current user's `UNC_AZURE_API_KEY`

## Build

The source is in `Native`. Build the self-contained x64 executable with:

```powershell
dotnet publish .\Native\AIUNCChatGPTInstaller.csproj -c Release -r win-x64 --self-contained true -p:PublishSingleFile=true
```

The published application is:

```text
Native\bin\Release\net10.0-windows10.0.17763.0\win-x64\publish\AI-UNC-ChatGPT-Installer.exe
```

The x64 build runs on standard Windows 11 x64 computers and under x64 emulation on Windows 11 ARM64. A native ARM64 build can be produced by changing the runtime to `win-arm64`.
