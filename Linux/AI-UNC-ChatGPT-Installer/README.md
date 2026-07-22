# AI @ UNC ChatGPT Installer for Linux/HPC

This is the plain terminal setup path for Linux systems such as an HPC cluster. It configures the Codex CLI path because ChatGPT Desktop is not part of the Linux/HPC flow.

The script:

- Prompts for the UNC Azure OpenAI API key.
- Asks which approved Codex model to use. Press Enter for `gpt-5.6-sol`.
- Shows a short, task-oriented description for every selected model and reasoning choice.
- Uses `medium` reasoning for `gpt-5.6-sol`, the standard/default Codex effort, unless the user picks another value.
- Offers `low` through `ultra` for `gpt-5.6-sol` and `gpt-5.6-terra`, `low` through `max` for `gpt-5.6-luna`, and `low` through `xhigh` for the other currently verified reasoning models.
- Uses model-default reasoning for alternate models whose supported values are not currently verified.
- Writes `export UNC_AZURE_API_KEY=...` to `~/.bashrc`.
- Writes the UNC Codex config to `$CODEX_HOME/config.toml`, or `~/.codex/config.toml` when `CODEX_HOME` is not set.
- When Codex CLI and `python3` are available, writes `<Codex home>/unc/model-catalog.json` by filtering Codex's current model catalog and points `model_catalog_json` at it so Codex shows only approved UNC models.
- Preserves each current Codex catalog entry's supported reasoning levels, using installer fallbacks only for synthesized `gpt-5.6` entries.
- Adds approved `gpt-5.6` entries to the filtered catalog when the local Codex catalog has not caught up yet.
- Tests the UNC Responses API and only reports setup as verified when the selected model returns the expected confirmation.

Image, embedding, and audio deployments are intentionally not listed because they are not suitable Codex chat/code deployments.

If a config already exists, the script backs it up before writing the UNC config. On first setup, it appends one installer-marked API key block to an existing `~/.bashrc`; it does not replace the file. Updates and uninstall preserve the existing file object, permissions, links, and all content outside that marked block. The installer refuses to edit an incomplete or duplicated marker block. Symlink-backed dotfiles remain symlinks. The script exports the key directly for its current process instead of sourcing the user's full HPC shell configuration. It creates a private `~/.bashrc` only when the user does not already have one.

## Run

```bash
chmod +x setup-codex-unc-cli.sh
./setup-codex-unc-cli.sh
```

The current setup process receives the key directly. To refresh another shell later, open a new Bash session or run:

```bash
source ~/.bashrc
```

The script also asks whether to install Codex CLI before writing the Codex config, so a first run can generate the filtered model catalog when the install succeeds. It runs the installer in non-interactive mode so the installer itself does not start Codex mid-setup. After setup is complete, the script asks whether to start Codex from the configured shell. If the cluster blocks downloads from login nodes, skip the install step and install Codex using your cluster's preferred software process, then rerun this setup to add the filtered model catalog.

## Uninstall

Run the script and choose `Uninstall UNC ChatGPT/Codex setup`, or run:

```bash
./setup-codex-unc-cli.sh --uninstall
```

The uninstall path removes the marked `~/.bashrc` export block, restores the newest config backup when one exists, removes installer support files, and optionally removes `~/.local/bin/codex`. It does not delete workspace folders or user files.
