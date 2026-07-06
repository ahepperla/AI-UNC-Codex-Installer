#!/usr/bin/env bash
set -euo pipefail

MODEL="gpt-5.5"
REASONING_EFFORT="medium"
PROVIDER="azure"
BASE_URL="https://azureaiapi.cloud.unc.edu/openai/v1"
ENV_KEY="UNC_AZURE_API_KEY"
CODEX_INSTALL_URL="https://chatgpt.com/codex/install.sh"

MARKER_START="# >>> AI @ UNC Codex Installer >>>"
MARKER_END="# <<< AI @ UNC Codex Installer <<<"

shell_quote() {
  local value=${1//\'/\'\\\'\'}
  printf "'%s'" "$value"
}

ask_yes_no() {
  local prompt="$1"
  local default="$2"
  local answer

  while true; do
    read -r -p "$prompt" answer
    answer=${answer:-$default}
    case "$answer" in
      y|Y|yes|YES|Yes) return 0 ;;
      n|N|no|NO|No) return 1 ;;
      *) echo "Please answer y or n." ;;
    esac
  done
}

choose_reasoning_effort() {
  local answer

  echo "Reasoning effort controls how much time Codex spends thinking."
  echo "Options: minimal, low, medium, high, xhigh"

  while true; do
    read -r -p "Use medium reasoning effort? [Y/n or type another option] " answer
    answer=${answer:-y}
    case "$answer" in
      y|Y|yes|YES|Yes)
        REASONING_EFFORT="medium"
        return 0
        ;;
      n|N|no|NO|No)
        read -r -p "Choose reasoning effort [minimal/low/medium/high/xhigh]: " answer
        ;;
    esac

    case "$answer" in
      minimal|low|medium|high|xhigh)
        REASONING_EFFORT="$answer"
        return 0
        ;;
      *)
        echo "Please choose one of: minimal, low, medium, high, xhigh."
        ;;
    esac
  done
}

source_bashrc_for_this_session() {
  local bashrc="$HOME/.bashrc"
  local old_opts="$-"
  local old_pipefail="off"

  if [[ ! -f "$bashrc" ]]; then
    return 0
  fi

  if set -o | grep -q '^pipefail[[:space:]]*on'; then
    old_pipefail="on"
  fi

  set +u
  if source "$bashrc"; then
    echo "Loaded ~/.bashrc for this setup session."
  else
    echo "Could not load ~/.bashrc automatically. Open a new Bash session or run: source ~/.bashrc"
  fi

  case "$old_opts" in *e*) set -e ;; *) set +e ;; esac
  case "$old_opts" in *u*) set -u ;; *) set +u ;; esac
  if [[ "$old_pipefail" == "on" ]]; then
    set -o pipefail
  else
    set +o pipefail
  fi
}

write_bashrc_export() {
  local api_key="$1"
  local bashrc="$HOME/.bashrc"
  local temp_file

  temp_file="$(mktemp "${TMPDIR:-/tmp}/unc-codex-bashrc.XXXXXX")"
  touch "$bashrc"

  awk -v start="$MARKER_START" -v end="$MARKER_END" '
    $0 == start { skip = 1; next }
    $0 == end { skip = 0; next }
    skip != 1 { print }
  ' "$bashrc" > "$temp_file"

  {
    cat "$temp_file"
    printf "\n%s\n" "$MARKER_START"
    printf "export %s=%s\n" "$ENV_KEY" "$(shell_quote "$api_key")"
    printf "%s\n" "$MARKER_END"
  } > "$bashrc"

  rm -f "$temp_file"
}

write_codex_config() {
  local codex_home="${CODEX_HOME:-$HOME/.codex}"
  local config_file="$codex_home/config.toml"
  local backup_file

  mkdir -p "$codex_home"

  if [[ -f "$config_file" ]]; then
    backup_file="$config_file.backup.$(date +%Y%m%d_%H%M%S)"
    cp "$config_file" "$backup_file"
    echo "Backed up existing config:"
    echo "  $backup_file"
  fi

  cat > "$config_file" <<EOF
model = "$MODEL"
model_provider = "$PROVIDER"
model_reasoning_effort = "$REASONING_EFFORT"

[model_providers.$PROVIDER]
name = "Azure OpenAI"
base_url = "$BASE_URL"
env_key = "$ENV_KEY"
wire_api = "responses"
EOF

  echo "Wrote Codex config:"
  echo "  $config_file"
}

install_codex_cli_if_requested() {
  local codex_path=""
  local installer_script=""

  if command -v codex >/dev/null 2>&1; then
    codex_path="$(command -v codex)"
    echo "Codex CLI is already installed:"
    echo "  $codex_path"
    if ! ask_yes_no "Reinstall or update Codex CLI now? [y/N] " "n"; then
      return 0
    fi
  else
    if ! ask_yes_no "Install Codex CLI now? [Y/n] " "y"; then
      return 0
    fi
  fi

  if ! command -v curl >/dev/null 2>&1; then
    echo "curl was not found, so this script cannot download the Codex CLI installer."
    echo "Install Codex manually from: https://openai.com/codex/"
    return 1
  fi

  installer_script="$(mktemp "${TMPDIR:-/tmp}/codex-install.XXXXXX.sh")"
  if ! curl -fsSL "$CODEX_INSTALL_URL" -o "$installer_script"; then
    rm -f "$installer_script"
    echo "Could not download the Codex CLI installer."
    echo "If the cluster blocks downloads, install Codex manually from: https://openai.com/codex/"
    return 1
  fi

  echo "Installing Codex CLI. This may take a few minutes..."
  echo "The installer will not start Codex automatically."
  if CODEX_NON_INTERACTIVE=1 CI=1 sh "$installer_script"; then
    rm -f "$installer_script"
    echo "Codex CLI install finished."
    source_bashrc_for_this_session
    if command -v codex >/dev/null 2>&1; then
      echo "Codex CLI is available at:"
      echo "  $(command -v codex)"
    else
      echo "Codex CLI was installed, but it is not on PATH in this shell yet."
      echo "Open a new Bash session or check your cluster's shell startup files."
    fi
  else
    rm -f "$installer_script"
    source_bashrc_for_this_session
    if command -v codex >/dev/null 2>&1; then
      echo "Codex CLI is available at:"
      echo "  $(command -v codex)"
      echo "The installer returned a warning or nonzero status, but Codex CLI is installed."
      return 0
    fi

    echo "Codex CLI was not installed."
    echo "If the cluster blocks downloads, install Codex manually from: https://openai.com/codex/"
    return 1
  fi
}

main() {
  local api_key=""

  echo "AI @ UNC Codex setup for Linux/HPC"
  echo

  while [[ -z "$api_key" ]]; do
    read -r -s -p "Paste UNC Azure OpenAI API key: " api_key
    echo
    if [[ -z "$api_key" ]]; then
      echo "API key cannot be empty."
    fi
  done

  export "$ENV_KEY=$api_key"

  choose_reasoning_effort
  echo "Using reasoning effort: $REASONING_EFFORT"

  write_bashrc_export "$api_key"
  echo "Saved $ENV_KEY export in:"
  echo "  $HOME/.bashrc"
  source_bashrc_for_this_session

  if [[ "$(basename "${SHELL:-}")" != "bash" ]]; then
    echo "Note: your login shell appears to be $(basename "${SHELL:-unknown}"). This script updates ~/.bashrc only."
  fi

  write_codex_config

  echo
  install_codex_cli_if_requested || true

  echo
  echo "Done. Open a new Bash session or run:"
  echo "  source ~/.bashrc"
}

main "$@"
