#!/usr/bin/env bash
set -euo pipefail

DEFAULT_MODEL="gpt-5.5"
INSTALLER_VERSION="2026.07.12"
INSTALLER_BUILD_DATE="2026-07-12"
MODEL="$DEFAULT_MODEL"
REASONING_EFFORT="medium"
PROVIDER="azure"
BASE_URL="https://azureaiapi.cloud.unc.edu/openai/v1"
ENV_KEY="UNC_AZURE_API_KEY"
CODEX_INSTALL_URL="https://chatgpt.com/codex/install.sh"

MARKER_START="# >>> AI @ UNC ChatGPT Installer >>>"
MARKER_END="# <<< AI @ UNC ChatGPT Installer <<<"
TEMP_FILES=()

cleanup_temp_files() {
  local path
  for path in "${TEMP_FILES[@]:-}"; do
    if [[ -n "$path" ]]; then
      rm -f "$path"
    fi
  done
}

register_temp_file() {
  TEMP_FILES+=("$1")
}

trap cleanup_temp_files EXIT

CODEX_MODEL_DEPLOYMENTS=(
  "gpt-5.5"
  "gpt-5.4"
  "gpt-5.4-mini"
  "gpt-5.4-nano"
  "gpt-5.3-codex"
  "gpt-5.2"
  "gpt-5.1"
  "gpt-5"
  "gpt-5-mini"
  "gpt-5-nano"
  "gpt-4.1"
  "gpt-4.1-mini"
  "gpt-4.1-nano"
  "gpt-4o"
  "gpt-4o-mini"
  "o1"
  "o1-preview"
  "o1-mini"
  "o3-mini"
  "chat"
)

CODEX_MODEL_LABELS=(
  "gpt-5.5"
  "gpt-5.4"
  "gpt-5.4-mini"
  "gpt-5.4-nano"
  "gpt-5.3-codex"
  "gpt-5.2"
  "gpt-5.1"
  "gpt-5"
  "gpt-5-mini"
  "gpt-5-nano"
  "gpt-4.1"
  "gpt-4.1-mini"
  "gpt-4.1-nano"
  "gpt-4o"
  "gpt-4o-mini"
  "o1"
  "o1-preview"
  "o1-mini"
  "o3-mini"
  "chat (gpt-4.1-mini)"
)

shell_quote() {
  local value=${1//\'/\'\\\'\'}
  printf "'%s'" "$value"
}

toml_escape() {
  local value="$1"
  value=${value//\\/\\\\}
  value=${value//\"/\\\"}
  printf "%s" "$value"
}

json_escape() {
  local value="$1"
  value=${value//\\/\\\\}
  value=${value//\"/\\\"}
  value=${value//$'\n'/\\n}
  printf "%s" "$value"
}

reasoning_description() {
  case "$1" in
    minimal) printf "Fastest responses for very small edits." ;;
    low) printf "Faster responses for straightforward tasks." ;;
    medium) printf "Balanced default for most UNC Codex work." ;;
    high) printf "More careful reasoning for complex changes." ;;
    xhigh) printf "Most thorough reasoning, with slower responses." ;;
    *) printf "Uses model-supported reasoning." ;;
  esac
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

choose_model() {
  local answer
  local index

  echo "Codex model:"
  echo "  Press Enter for gpt-5.5."
  echo "  Image, embedding, and audio deployments are intentionally not listed."
  echo

  for index in "${!CODEX_MODEL_DEPLOYMENTS[@]}"; do
    printf "  %2d) %s\n" "$((index + 1))" "${CODEX_MODEL_LABELS[$index]}"
  done

  while true; do
    read -r -p "Choose model [1]: " answer
    answer=${answer:-1}

    if [[ "$answer" =~ ^[0-9]+$ ]] && (( answer >= 1 && answer <= ${#CODEX_MODEL_DEPLOYMENTS[@]} )); then
      MODEL="${CODEX_MODEL_DEPLOYMENTS[$((answer - 1))]}"
      return 0
    fi

    for index in "${!CODEX_MODEL_DEPLOYMENTS[@]}"; do
      if [[ "$answer" == "${CODEX_MODEL_DEPLOYMENTS[$index]}" ]]; then
        MODEL="$answer"
        return 0
      fi
    done

    echo "Choose a number from 1 to ${#CODEX_MODEL_DEPLOYMENTS[@]}, or type an approved deployment name."
  done
}

choose_reasoning_effort() {
  local answer

  if [[ "$MODEL" != "$DEFAULT_MODEL" ]]; then
    REASONING_EFFORT=""
    echo "Reasoning effort: model default for $MODEL."
    echo "This script does not write unsupported reasoning options for alternate models."
    return 0
  fi

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
  local new_bashrc

  temp_file="$(mktemp "${TMPDIR:-/tmp}/unc-codex-bashrc.XXXXXX")"
  new_bashrc="$(mktemp "$(dirname "$bashrc")/.bashrc.unc-chatgpt.XXXXXX")"
  register_temp_file "$temp_file"
  register_temp_file "$new_bashrc"
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
  } > "$new_bashrc"

  chmod --reference="$bashrc" "$new_bashrc" 2>/dev/null || true
  mv "$new_bashrc" "$bashrc"
  rm -f "$temp_file"
}

remove_bashrc_export() {
  local bashrc="$HOME/.bashrc"
  local temp_file
  local new_bashrc

  if [[ ! -f "$bashrc" ]]; then
    echo "No ~/.bashrc file was found."
    return 0
  fi

  temp_file="$(mktemp "${TMPDIR:-/tmp}/unc-codex-bashrc.XXXXXX")"
  new_bashrc="$(mktemp "$(dirname "$bashrc")/.bashrc.unc-chatgpt.XXXXXX")"
  register_temp_file "$temp_file"
  register_temp_file "$new_bashrc"

  awk -v start="$MARKER_START" -v end="$MARKER_END" '
    $0 == start { skip = 1; next }
    $0 == end { skip = 0; next }
    skip != 1 { print }
  ' "$bashrc" > "$temp_file"

  cat "$temp_file" > "$new_bashrc"
  chmod --reference="$bashrc" "$new_bashrc" 2>/dev/null || true
  mv "$new_bashrc" "$bashrc"
  rm -f "$temp_file"
  unset "$ENV_KEY" || true
  echo "Removed $ENV_KEY export block from ~/.bashrc."
}

write_model_catalog() {
  local codex_home="$1"
  local support_dir="$codex_home/unc"
  local catalog_file="$support_dir/model-catalog.json"
  local codex_path=""
  local temp_codex_home=""
  local raw_catalog
  local temp_catalog

  if ! command -v codex >/dev/null 2>&1; then
    echo "Codex CLI was not found, so the model picker restriction was skipped."
    return 1
  fi

  if ! command -v python3 >/dev/null 2>&1; then
    echo "python3 was not found, so the model picker restriction was skipped."
    return 1
  fi

  mkdir -p "$support_dir"
  codex_path="$(command -v codex)"
  temp_codex_home="$(mktemp -d "${TMPDIR:-/tmp}/ai-unc-codex-home.XXXXXX")"
  raw_catalog="$(mktemp "$support_dir/.codex-models.XXXXXX")"
  temp_catalog="$(mktemp "$support_dir/.model-catalog.XXXXXX")"
  register_temp_file "$raw_catalog"
  register_temp_file "$temp_catalog"

  if ! CODEX_HOME="$temp_codex_home" "$codex_path" debug models > "$raw_catalog"; then
    rm -rf "$temp_codex_home"
    rm -f "$raw_catalog" "$temp_catalog"
    echo "Codex did not return a model catalog, so the model picker restriction was skipped."
    return 1
  fi

  if ! python3 - "$raw_catalog" "$DEFAULT_MODEL" "${CODEX_MODEL_DEPLOYMENTS[@]}" -- "${CODEX_MODEL_LABELS[@]}" > "$temp_catalog" <<'PY'
import datetime
import json
import sys

raw_catalog_path = sys.argv[1]
args = sys.argv[2:]
default_model = args[0]
separator = args.index("--")
deployments = args[1:separator]
labels = args[separator + 1:]
approved_labels = dict(zip(deployments, labels))

with open(raw_catalog_path, "r", encoding="utf-8") as catalog_file:
    catalog = json.load(catalog_file)
models = catalog.get("models")
if not isinstance(models, list):
    raise SystemExit("Codex catalog did not include a models list.")

filtered_models = []
for model in models:
    if not isinstance(model, dict):
        continue
    slug = model.get("slug")
    if slug not in approved_labels:
        continue

    entry = dict(model)
    entry["display_name"] = slug if slug == default_model else approved_labels[slug]
    entry["description"] = (
        "Recommended UNC model for ChatGPT/Codex work."
        if slug == default_model
        else "Approved UNC ChatGPT/Codex model."
    )
    entry["priority"] = len(filtered_models)
    filtered_models.append(entry)

if not filtered_models:
    raise SystemExit("No approved UNC models were present in the Codex catalog.")

catalog["fetched_at"] = datetime.datetime.now(datetime.timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")
catalog["models"] = filtered_models
catalog["source"] = "AI @ UNC ChatGPT Installer filtered from Codex catalog"
json.dump(catalog, sys.stdout, indent=2, sort_keys=True)
sys.stdout.write("\n")
PY
  then
    rm -rf "$temp_codex_home"
    rm -f "$raw_catalog" "$temp_catalog"
    echo "Codex did not return a usable model catalog, so the model picker restriction was skipped."
    return 1
  fi

  rm -rf "$temp_codex_home"
  rm -f "$raw_catalog"

  mv "$temp_catalog" "$catalog_file"
  echo "Wrote UNC model catalog:"
  echo "  $catalog_file"
  return 0
}

write_codex_config() {
  local codex_home="${CODEX_HOME:-$HOME/.codex}"
  local config_file="$codex_home/config.toml"
  local catalog_file="$codex_home/unc/model-catalog.json"
  local catalog_written=0
  local temp_config
  local backup_file

  mkdir -p "$codex_home"
  if write_model_catalog "$codex_home"; then
    catalog_written=1
  fi
  temp_config="$(mktemp "$codex_home/.config.toml.unc-chatgpt.XXXXXX")"
  register_temp_file "$temp_config"

  if [[ -f "$config_file" ]]; then
    backup_file="$config_file.backup.$(date +%Y%m%d_%H%M%S)"
    cp "$config_file" "$backup_file"
    echo "Backed up existing config:"
    echo "  $backup_file"
  fi

  {
    printf 'model = "%s"\n' "$MODEL"
    printf 'model_provider = "%s"\n' "$PROVIDER"
    if [[ -n "$REASONING_EFFORT" ]]; then
      printf 'model_reasoning_effort = "%s"\n' "$REASONING_EFFORT"
    fi
    if [[ "$catalog_written" -eq 1 ]]; then
      printf 'model_catalog_json = "%s"\n' "$(toml_escape "$catalog_file")"
    fi
    printf '\n[model_providers.%s]\n' "$PROVIDER"
    printf 'name = "Azure OpenAI"\n'
    printf 'base_url = "%s"\n' "$BASE_URL"
    printf 'env_key = "%s"\n' "$ENV_KEY"
    printf 'wire_api = "responses"\n'
  } > "$temp_config"

  if [[ -f "$config_file" ]]; then
    chmod --reference="$config_file" "$temp_config" 2>/dev/null || true
  fi
  mv "$temp_config" "$config_file"

  echo "Wrote Codex config:"
  echo "  $config_file"
}

restore_or_remove_config_for_uninstall() {
  local codex_home="${CODEX_HOME:-$HOME/.codex}"
  local config_file="$codex_home/config.toml"
  local original_backup=""
  local removed_file

  mkdir -p "$codex_home"
  original_backup="$(find "$codex_home" -maxdepth 1 -type f -name 'config.toml.backup.*' -print 2>/dev/null | sort | head -n 1 || true)"
  if [[ -n "$original_backup" ]]; then
    cp "$original_backup" "$config_file"
    echo "Restored Codex config from:"
    echo "  $original_backup"
    return 0
  fi

  if [[ -f "$config_file" ]]; then
    removed_file="$config_file.removed.$(date +%Y%m%d_%H%M%S)"
    mv "$config_file" "$removed_file"
    echo "No prior config backup was found. Moved current config to:"
    echo "  $removed_file"
  else
    echo "No Codex config was present."
  fi
}

uninstall_codex_cli_if_requested() {
  local codex_path=""
  local safe_path="$HOME/.local/bin/codex"

  if ! command -v codex >/dev/null 2>&1; then
    echo "Codex CLI was not detected."
    return 0
  fi

  codex_path="$(command -v codex)"
  echo "Codex CLI detected:"
  echo "  $codex_path"
  if [[ "$codex_path" != "$safe_path" ]]; then
    echo "This script only removes the standalone user-local install at:"
    echo "  $safe_path"
    echo "Use the package manager that installed this CLI to uninstall it."
    return 0
  fi

  if ask_yes_no "Remove Codex CLI from ~/.local/bin? [y/N] " "n"; then
    rm -f "$safe_path"
    echo "Removed Codex CLI from:"
    echo "  $safe_path"
  fi
}

uninstall_unc_setup() {
  local codex_home="${CODEX_HOME:-$HOME/.codex}"
  local support_dir="$codex_home/unc"

  echo "This will remove UNC ChatGPT/Codex shell/config setup for this user."
  echo "Workspace folders and user files are not deleted."
  if ! ask_yes_no "Continue with uninstall? [y/N] " "n"; then
    return 0
  fi

  remove_bashrc_export
  restore_or_remove_config_for_uninstall

  if [[ -d "$support_dir" ]]; then
    rm -rf "$support_dir"
    echo "Removed installer support files:"
    echo "  $support_dir"
  fi

  uninstall_codex_cli_if_requested

  echo
  echo "UNC ChatGPT/Codex uninstall complete."
  echo "Open a new Bash session or run:"
  echo "  source ~/.bashrc"
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
  register_temp_file "$installer_script"
  if ! curl -fsSL "$CODEX_INSTALL_URL" -o "$installer_script"; then
    rm -f "$installer_script"
    echo "Could not download the Codex CLI installer."
    echo "If the cluster blocks downloads, install Codex manually from: https://openai.com/codex/"
    return 1
  fi

  echo "Installing Codex CLI. This may take a few minutes..."
  echo "The installer will not start Codex automatically."
  if printf 'n\n' | CODEX_NON_INTERACTIVE=1 CI=1 sh "$installer_script"; then
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

start_codex_if_requested() {
  local codex_path=""
  local status=0

  source_bashrc_for_this_session

  if ! command -v codex >/dev/null 2>&1; then
    return 0
  fi

  codex_path="$(command -v codex)"
  if ! ask_yes_no "Start Codex now? [y/N] " "n"; then
    return 0
  fi

  echo "Starting Codex:"
  echo "  $codex_path"
  echo "When you exit Codex, you will return to this shell."

  set +e
  "$codex_path"
  status=$?
  set -e

  if [[ "$status" -eq 0 ]]; then
    echo "Codex closed."
  else
    echo "Codex exited with status $status."
    echo "Setup is still complete. Try opening a new Bash session and running: codex"
  fi
}

main() {
  local api_key=""
  local action=""

  echo "AI @ UNC ChatGPT setup for Linux/HPC"
  echo "Installer $INSTALLER_VERSION ($INSTALLER_BUILD_DATE)"
  echo

  if [[ "${1:-}" == "--uninstall" ]]; then
    uninstall_unc_setup
    return 0
  fi

  echo "Choose action:"
  echo "  1) Set up or update UNC ChatGPT/Codex config"
  echo "  2) Uninstall UNC ChatGPT/Codex setup"
  read -r -p "Action [1]: " action
  action=${action:-1}
  if [[ "$action" == "2" ]]; then
    uninstall_unc_setup
    return 0
  fi

  while [[ -z "$api_key" ]]; do
    read -r -s -p "Paste UNC Azure OpenAI API key: " api_key
    echo
    if [[ -z "$api_key" ]]; then
      echo "API key cannot be empty."
    fi
  done

  export "$ENV_KEY=$api_key"

  choose_model
  echo "Using model: $MODEL"
  choose_reasoning_effort
  if [[ -n "$REASONING_EFFORT" ]]; then
    echo "Using reasoning effort: $REASONING_EFFORT"
  else
    echo "Using reasoning effort: model default"
  fi

  write_bashrc_export "$api_key"
  echo "Saved $ENV_KEY export in:"
  echo "  $HOME/.bashrc"
  source_bashrc_for_this_session

  if [[ "$(basename "${SHELL:-}")" != "bash" ]]; then
    echo "Note: your login shell appears to be $(basename "${SHELL:-unknown}"). This script updates ~/.bashrc only."
  fi

  echo
  install_codex_cli_if_requested || true

  write_codex_config

  echo
  echo "Setup complete."
  echo "What happened:"
  echo "  API key export saved in ~/.bashrc"
  echo "  Codex config written under ${CODEX_HOME:-$HOME/.codex}"
  echo "  Model: $MODEL"
  if [[ -n "$REASONING_EFFORT" ]]; then
    echo "  Reasoning effort: $REASONING_EFFORT"
  else
    echo "  Reasoning effort: model default"
  fi
  start_codex_if_requested

  echo
  echo "Done. To refresh another shell later, run:"
  echo "  source ~/.bashrc"
}

main "$@"
