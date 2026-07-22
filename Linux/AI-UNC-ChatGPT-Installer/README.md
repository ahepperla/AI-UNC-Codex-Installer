# AI @ UNC ChatGPT Installer for Linux/HPC

This is the plain terminal setup path for Linux systems such as an HPC cluster. It configures the Codex CLI path because ChatGPT Desktop is not part of the Linux/HPC flow.

The script:

- Prompts for the UNC Azure OpenAI API key.
- Asks which approved Codex model to use. Press Enter for `gpt-5.6-sol`.
- Uses `medium` reasoning for `gpt-5.6-sol`, the standard/default Codex effort, unless the user picks another value.
- Offers `low`, `medium`, `high`, `xhigh`, and `max` reasoning for the approved `gpt-5.6` models.
- Uses model-default reasoning for other alternate models and leaves `model_reasoning_effort` out of the config unless their supported values are known.
- Writes `export UNC_AZURE_API_KEY=...` to `~/.bashrc`.
- Writes the UNC Codex config to `$CODEX_HOME/config.toml`, or `~/.codex/config.toml` when `CODEX_HOME` is not set.
- When Codex CLI and `python3` are available, writes `<Codex home>/unc/model-catalog.json` by filtering Codex's current model catalog and points `model_catalog_json` at it so Codex shows only approved UNC models.
- Adds approved `gpt-5.6` entries to the filtered catalog when the local Codex catalog has not caught up yet.

Image, embedding, and audio deployments are intentionally not listed because they are not suitable Codex chat/code deployments.

If a config already exists, the script backs it up before writing the UNC config. After updating `~/.bashrc`, the script loads it for the current setup session so the API key is available before the optional Codex CLI install runs.

## Run

```bash
chmod +x setup-codex-unc-cli.sh
./setup-codex-unc-cli.sh
```

The script tries to load `~/.bashrc` automatically. If your cluster shell startup files block that, open a new Bash session or run:

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
