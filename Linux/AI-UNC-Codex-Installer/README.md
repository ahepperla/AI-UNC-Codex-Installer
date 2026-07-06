# AI @ UNC Codex Installer for Linux/HPC

This is the plain terminal setup path for Linux systems such as an HPC cluster.

It does three things:

- Prompts for the UNC Azure OpenAI API key.
- Asks whether to use the default `medium` reasoning effort.
- Writes `export UNC_AZURE_API_KEY=...` to `~/.bashrc`.
- Writes the UNC Codex config to `$CODEX_HOME/config.toml`, or `~/.codex/config.toml` when `CODEX_HOME` is not set.

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

The script also asks whether to install Codex CLI. It runs the installer in non-interactive mode so the installer itself does not start Codex mid-setup. After setup is complete, the script asks whether to start Codex from the configured shell. If the cluster blocks downloads from login nodes, skip the install step and install Codex using your cluster's preferred software process.
