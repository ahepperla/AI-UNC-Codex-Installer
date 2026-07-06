# AI @ UNC Codex Installer for Linux/HPC

This is the plain terminal setup path for Linux systems such as an HPC cluster.

It does three things:

- Prompts for the UNC Azure OpenAI API key.
- Writes `export UNC_AZURE_API_KEY=...` to `~/.bashrc`.
- Writes the UNC Codex config to `$CODEX_HOME/config.toml`, or `~/.codex/config.toml` when `CODEX_HOME` is not set.

If a config already exists, the script backs it up before writing the UNC config.

## Run

```bash
chmod +x setup-codex-unc-cli.sh
./setup-codex-unc-cli.sh
```

After setup, open a new Bash session or run:

```bash
source ~/.bashrc
```

The script also asks whether to install Codex CLI. If the cluster blocks downloads from login nodes, skip that step and install Codex using your cluster's preferred software process.
