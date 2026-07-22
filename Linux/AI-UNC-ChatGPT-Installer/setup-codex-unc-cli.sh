#!/usr/bin/env bash
set -euo pipefail

DEFAULT_MODEL="gpt-5.6-sol"
INSTALLER_VERSION="2026.07.22.3"
INSTALLER_BUILD_DATE="2026-07-22"
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

unregister_temp_file() {
  local path_to_keep="$1"
  local path
  local remaining=()

  for path in "${TEMP_FILES[@]:-}"; do
    if [[ "$path" != "$path_to_keep" ]]; then
      remaining+=("$path")
    fi
  done
  TEMP_FILES=("${remaining[@]}")
}

trap cleanup_temp_files EXIT

CODEX_MODEL_DEPLOYMENTS=(
  "gpt-5.6-sol"
  "gpt-5.6-terra"
  "gpt-5.6-luna"
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
  "gpt-5.6-sol"
  "gpt-5.6-terra"
  "gpt-5.6-luna"
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

unique_timestamped_path() {
  local prefix="$1"
  local base="${prefix}.$(date +%Y%m%d_%H%M%S)"
  local candidate="$base"
  local suffix=1

  while [[ -e "$candidate" ]]; do
    candidate="${base}.${suffix}"
    suffix=$((suffix + 1))
  done

  printf "%s" "$candidate"
}

reasoning_description() {
  case "$1" in
    low) printf "Faster responses for straightforward tasks, with less time spent reasoning." ;;
    medium) printf "Recommended balance of speed and careful reasoning for most work." ;;
    high) printf "More careful reasoning for complex code changes and troubleshooting." ;;
    xhigh) printf "Deep reasoning for difficult tasks; responses may take longer." ;;
    max) printf "Maximum supported reasoning for the hardest tasks; expect the longest waits." ;;
    ultra) printf "Maximum reasoning with automatic task delegation for large, multi-step work." ;;
    *) printf "Uses model-supported reasoning." ;;
  esac
}

model_description() {
  case "$1" in
    gpt-5.6-sol) printf "Recommended default and latest frontier model for complex coding and long-running work." ;;
    gpt-5.6-terra) printf "Balanced model for everyday coding, debugging, and general work." ;;
    gpt-5.6-luna) printf "Fast, lightweight model for shorter coding tasks and quick edits." ;;
    gpt-5.5) printf "Frontier model for complex coding, research, and real-world work." ;;
    gpt-5.4) printf "Strong model for everyday coding and debugging." ;;
    gpt-5.4-mini) printf "Fast, lightweight model for straightforward coding tasks." ;;
    gpt-5.4-nano) printf "Small approved model for simple tasks and compatibility." ;;
    gpt-5.3-codex) printf "Coding-focused model for software development workflows." ;;
    gpt-5.2) printf "Model for professional work and long-running agent tasks." ;;
    gpt-5.1) printf "Earlier general-purpose GPT-5 model for existing workflows." ;;
    gpt-5) printf "Earlier GPT-5 model for general work and compatibility." ;;
    gpt-5-mini) printf "Earlier lightweight GPT-5 model for simple, quick tasks." ;;
    gpt-5-nano) printf "Small earlier GPT-5 model for basic, low-complexity tasks." ;;
    gpt-4.1) printf "Earlier general-purpose model for coding and instruction-following tasks." ;;
    gpt-4.1-mini) printf "Earlier lightweight general-purpose model for shorter tasks." ;;
    gpt-4.1-nano) printf "Small earlier model for basic, low-complexity tasks." ;;
    gpt-4o) printf "Earlier general-purpose model for text, coding, and multimodal workflows." ;;
    gpt-4o-mini) printf "Earlier lightweight model for shorter text and multimodal tasks." ;;
    o1) printf "Earlier deep-reasoning model for complex problems; uses model-default effort." ;;
    o1-preview) printf "Preview-era deep-reasoning model for compatibility with existing workflows." ;;
    o1-mini) printf "Earlier compact reasoning model for focused problems; uses model-default effort." ;;
    o3-mini) printf "Earlier compact reasoning model for coding, math, and logic tasks." ;;
    chat) printf "Compatibility alias for the gpt-4.1-mini chat deployment." ;;
    *) printf "Approved UNC model." ;;
  esac
}

show_selected_model_description() {
  printf "Selected model: %s\n" "$MODEL"
  printf "  %s\n" "$(model_description "$MODEL")"
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
  echo "  Press Enter for gpt-5.6-sol."
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
      show_selected_model_description
      return 0
    fi

    for index in "${!CODEX_MODEL_DEPLOYMENTS[@]}"; do
      if [[ "$answer" == "${CODEX_MODEL_DEPLOYMENTS[$index]}" ]]; then
        MODEL="$answer"
        show_selected_model_description
        return 0
      fi
    done

    echo "Choose a number from 1 to ${#CODEX_MODEL_DEPLOYMENTS[@]}, or type an approved deployment name."
  done
}

choose_reasoning_effort() {
  local answer
  local option
  local matched
  local -a options=()

  echo "Reasoning effort controls how much time Codex spends thinking."

  case "$MODEL" in
    gpt-5.6-sol|gpt-5.6-terra)
      options=(low medium high xhigh max ultra)
      ;;
    gpt-5.6-luna)
      options=(low medium high xhigh max)
      ;;
    gpt-5.5|gpt-5.4|gpt-5.4-mini|gpt-5.3-codex|gpt-5.2)
      options=(low medium high xhigh)
      ;;
    *)
      REASONING_EFFORT=""
      echo "Reasoning effort: model default for $MODEL."
      echo "This script does not write unsupported reasoning options for alternate models."
      return 0
      ;;
  esac

  echo "Reasoning options:"
  for option in "${options[@]}"; do
    printf "  %-6s %s\n" "$option" "$(reasoning_description "$option")"
  done

  while true; do
    read -r -p "Use medium reasoning effort? [Y/n or type another option] " answer
    answer=${answer:-y}
    case "$answer" in
      y|Y|yes|YES|Yes)
        REASONING_EFFORT="medium"
        return 0
        ;;
      n|N|no|NO|No)
        read -r -p "Choose reasoning effort: " answer
        ;;
    esac

    matched=false
    for option in "${options[@]}"; do
      if [[ "$answer" == "$option" ]]; then
        REASONING_EFFORT="$answer"
        matched=true
        break
      fi
    done
    if [[ "$matched" == true ]]; then
        return 0
    fi

    echo "Please choose one of: ${options[*]}."
  done
}

write_bashrc_export() {
  local api_key="$1"
  local bashrc="$HOME/.bashrc"
  local bashrc_target="$bashrc"
  local temp_file

  if [[ -L "$bashrc" ]]; then
    if ! bashrc_target="$(readlink -f "$bashrc")" || [[ -z "$bashrc_target" ]]; then
      echo "Could not resolve the ~/.bashrc symlink target."
      return 1
    fi
  fi
  if [[ ! -e "$bashrc_target" ]]; then
    (umask 077; : > "$bashrc_target")
  fi

  if ! grep -Fqx "$MARKER_START" "$bashrc_target" &&
     ! grep -Fqx "$MARKER_END" "$bashrc_target"; then
    {
      if [[ -s "$bashrc_target" ]]; then
        printf "\n"
      fi
      printf "%s\n" "$MARKER_START"
      printf "export %s=%s\n" "$ENV_KEY" "$(shell_quote "$api_key")"
      printf "%s\n" "$MARKER_END"
    } >> "$bashrc_target"
    return 0
  fi

  temp_file="$(mktemp "${TMPDIR:-/tmp}/unc-codex-bashrc.XXXXXX")"
  register_temp_file "$temp_file"

  if ! strip_bashrc_export "$bashrc_target" > "$temp_file"; then
    echo "The existing installer block in ~/.bashrc is incomplete or duplicated."
    echo "No changes were made. Remove or repair the marked block, then rerun setup."
    return 1
  fi

  {
    printf "\n%s\n" "$MARKER_START"
    printf "export %s=%s\n" "$ENV_KEY" "$(shell_quote "$api_key")"
    printf "%s\n" "$MARKER_END"
  } >> "$temp_file"

  overwrite_bashrc_contents "$temp_file" "$bashrc_target"
  rm -f "$temp_file"
}

remove_bashrc_export() {
  local bashrc="$HOME/.bashrc"
  local bashrc_target="$bashrc"
  local temp_file

  if [[ ! -f "$bashrc" ]]; then
    echo "No ~/.bashrc file was found."
    return 0
  fi

  if [[ -L "$bashrc" ]]; then
    if ! bashrc_target="$(readlink -f "$bashrc")" || [[ -z "$bashrc_target" ]]; then
      echo "Could not resolve the ~/.bashrc symlink target."
      return 1
    fi
  fi

  if ! grep -Fqx "$MARKER_START" "$bashrc_target" &&
     ! grep -Fqx "$MARKER_END" "$bashrc_target"; then
    echo "No installer-managed API key block was found in ~/.bashrc."
    return 0
  fi

  temp_file="$(mktemp "${TMPDIR:-/tmp}/unc-codex-bashrc.XXXXXX")"
  register_temp_file "$temp_file"

  if ! strip_bashrc_export "$bashrc_target" > "$temp_file"; then
    echo "The installer block in ~/.bashrc is incomplete or duplicated."
    echo "No changes were made. Remove or repair the marked block manually."
    return 1
  fi

  overwrite_bashrc_contents "$temp_file" "$bashrc_target"
  rm -f "$temp_file"
  unset "$ENV_KEY" || true
  echo "Removed $ENV_KEY export block from ~/.bashrc."
}

strip_bashrc_export() {
  local bashrc_target="$1"

  awk -v start="$MARKER_START" -v end="$MARKER_END" '
    $0 == start {
      if (inside || found) {
        invalid = 1
        exit
      }
      inside = 1
      found = 1
      next
    }
    $0 == end {
      if (!inside) {
        invalid = 1
        exit
      }
      inside = 0
      next
    }
    !inside { print }
    END {
      if (invalid || inside || !found) {
        exit 2
      }
    }
  ' "$bashrc_target"
}

overwrite_bashrc_contents() {
  local source_file="$1"
  local bashrc_target="$2"
  local original_file

  original_file="$(mktemp "${TMPDIR:-/tmp}/unc-codex-bashrc-original.XXXXXX")"
  register_temp_file "$original_file"
  cat "$bashrc_target" > "$original_file"

  if ! cat "$source_file" > "$bashrc_target" ||
     ! cmp -s "$source_file" "$bashrc_target"; then
    echo "Could not safely update ~/.bashrc; restoring its original contents."
    if ! cat "$original_file" > "$bashrc_target" ||
       ! cmp -s "$original_file" "$bashrc_target"; then
      unregister_temp_file "$original_file"
      echo "Automatic restoration failed. The original contents remain in:"
      echo "  $original_file"
      return 1
    fi
    return 1
  fi

  rm -f "$original_file"
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
reasoning_by_slug = {
    "gpt-5.6-sol": ["low", "medium", "high", "xhigh", "max", "ultra"],
    "gpt-5.6-terra": ["low", "medium", "high", "xhigh", "max", "ultra"],
    "gpt-5.6-luna": ["low", "medium", "high", "xhigh", "max"],
    "gpt-5.5": ["low", "medium", "high", "xhigh"],
    "gpt-5.4": ["low", "medium", "high", "xhigh"],
    "gpt-5.4-mini": ["low", "medium", "high", "xhigh"],
    "gpt-5.3-codex": ["low", "medium", "high", "xhigh"],
    "gpt-5.2": ["low", "medium", "high", "xhigh"],
}
reasoning_descriptions = {
    "low": "Faster responses with lighter reasoning for straightforward tasks",
    "medium": "Recommended balance of speed and reasoning depth for most work",
    "high": "More careful reasoning for complex code changes and troubleshooting",
    "xhigh": "Deep reasoning for difficult tasks, with longer response times",
    "max": "Maximum supported reasoning for the hardest tasks",
    "ultra": "Maximum reasoning with automatic task delegation for large, multi-step work",
}
model_descriptions = {
    "gpt-5.6-sol": "Recommended default and latest frontier model for complex coding and long-running work.",
    "gpt-5.6-terra": "Balanced model for everyday coding, debugging, and general work.",
    "gpt-5.6-luna": "Fast, lightweight model for shorter coding tasks and quick edits.",
    "gpt-5.5": "Frontier model for complex coding, research, and real-world work.",
    "gpt-5.4": "Strong model for everyday coding and debugging.",
    "gpt-5.4-mini": "Fast, lightweight model for straightforward coding tasks.",
    "gpt-5.4-nano": "Small approved model for simple tasks and compatibility.",
    "gpt-5.3-codex": "Coding-focused model for software development workflows.",
    "gpt-5.2": "Model for professional work and long-running agent tasks.",
    "gpt-5.1": "Earlier general-purpose GPT-5 model for existing workflows.",
    "gpt-5": "Earlier GPT-5 model for general work and compatibility.",
    "gpt-5-mini": "Earlier lightweight GPT-5 model for simple, quick tasks.",
    "gpt-5-nano": "Small earlier GPT-5 model for basic, low-complexity tasks.",
    "gpt-4.1": "Earlier general-purpose model for coding and instruction-following tasks.",
    "gpt-4.1-mini": "Earlier lightweight general-purpose model for shorter tasks.",
    "gpt-4.1-nano": "Small earlier model for basic, low-complexity tasks.",
    "gpt-4o": "Earlier general-purpose model for text, coding, and multimodal workflows.",
    "gpt-4o-mini": "Earlier lightweight model for shorter text and multimodal tasks.",
    "o1": "Earlier deep-reasoning model for complex problems; uses model-default effort.",
    "o1-preview": "Preview-era deep-reasoning model for compatibility with existing workflows.",
    "o1-mini": "Earlier compact reasoning model for focused problems; uses model-default effort.",
    "o3-mini": "Earlier compact reasoning model for coding, math, and logic tasks.",
    "chat": "Compatibility alias for the gpt-4.1-mini chat deployment.",
}

with open(raw_catalog_path, "r", encoding="utf-8") as catalog_file:
    catalog = json.load(catalog_file)
models = catalog.get("models")
if not isinstance(models, list):
    raise SystemExit("Codex catalog did not include a models list.")

current_models_by_slug = {}
for model in models:
    if not isinstance(model, dict):
        continue
    slug = model.get("slug")
    if isinstance(slug, str) and slug not in current_models_by_slug:
        current_models_by_slug[slug] = model

synthesis_template = current_models_by_slug.get("gpt-5.5") or (models[0] if models else None)
filtered_models = []
for slug in deployments:
    is_synthesized = False
    if slug in current_models_by_slug:
        model = current_models_by_slug[slug]
    elif slug.startswith("gpt-5.6-") and isinstance(synthesis_template, dict):
        model = synthesis_template
        is_synthesized = True
    else:
        continue

    entry = dict(model)
    entry["slug"] = slug
    entry["display_name"] = approved_labels[slug]
    entry["description"] = model_descriptions.get(slug, "Approved UNC model.")
    entry["priority"] = len(filtered_models)
    reasoning_levels = reasoning_by_slug.get(slug, [])
    if reasoning_levels:
        entry["default_reasoning_level"] = "medium"
        if is_synthesized or not isinstance(entry.get("supported_reasoning_levels"), list):
            entry["supported_reasoning_levels"] = [
                {"effort": effort, "description": reasoning_descriptions[effort]}
                for effort in reasoning_levels
            ]
    if is_synthesized:
        entry.pop("availability_nux", None)
        entry.pop("upgrade", None)
    filtered_models.append(entry)

if not filtered_models:
    raise SystemExit("No approved UNC models were present in the Codex catalog.")
if any(
    not isinstance(model.get("default_reasoning_level"), str)
    or not isinstance(model.get("supported_reasoning_levels"), list)
    for model in filtered_models
):
    raise SystemExit("Filtered model catalog was missing required reasoning fields.")

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
    backup_file="$(unique_timestamped_path "$config_file.backup")"
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
    removed_file="$(unique_timestamped_path "$config_file.removed")"
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
    if [[ -d "$HOME/.local/bin" && ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
      export PATH="$HOME/.local/bin:$PATH"
    fi
    if command -v codex >/dev/null 2>&1; then
      echo "Codex CLI is available at:"
      echo "  $(command -v codex)"
    else
      echo "Codex CLI was installed, but it is not on PATH in this shell yet."
      echo "Open a new Bash session or check your cluster's shell startup files."
    fi
  else
    rm -f "$installer_script"
    if [[ -d "$HOME/.local/bin" && ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
      export PATH="$HOME/.local/bin:$PATH"
    fi
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

test_unc_endpoint() {
  local api_key="$1"
  local response_file
  local payload
  local http_status

  if ! command -v curl >/dev/null 2>&1; then
    echo "Connection test could not run because curl was not found."
    return 1
  fi

  response_file="$(mktemp "${TMPDIR:-/tmp}/unc-codex-endpoint.XXXXXX")"
  register_temp_file "$response_file"
  payload="$(printf '{"model":"%s","input":"Reply exactly: UNC Codex setup OK","store":false,"background":false}' "$MODEL")"

  echo "Testing the UNC Responses endpoint with $MODEL..."
  if ! http_status="$(curl \
    --silent \
    --show-error \
    --max-time 30 \
    --output "$response_file" \
    --write-out '%{http_code}' \
    --request POST \
    --header "Authorization: Bearer $api_key" \
    --header 'Content-Type: application/json' \
    --data "$payload" \
    "$BASE_URL/responses")"; then
    echo "Connection test failed before an HTTP response was received."
    rm -f "$response_file"
    return 1
  fi

  if [[ "$http_status" =~ ^2[0-9][0-9]$ ]] &&
     grep -Fq 'UNC Codex setup OK' "$response_file"; then
    echo "Connection test succeeded (HTTP $http_status)."
    rm -f "$response_file"
    return 0
  fi

  case "$http_status" in
    401|403) echo "Connection test failed: authentication was rejected (HTTP $http_status)." ;;
    404) echo "Connection test failed: the endpoint or model was not found (HTTP 404)." ;;
    429) echo "Connection test failed: the endpoint rate limit was reached (HTTP 429)." ;;
    5??) echo "Connection test failed: the UNC endpoint returned a server error (HTTP $http_status)." ;;
    2??) echo "Connection test failed: the response did not contain the expected confirmation text." ;;
    *) echo "Connection test failed with HTTP $http_status." ;;
  esac

  rm -f "$response_file"
  return 1
}

start_codex_if_requested() {
  local codex_path=""
  local status=0

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
  local endpoint_verified=0

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

  if [[ "$(basename "${SHELL:-}")" != "bash" ]]; then
    echo "Note: your login shell appears to be $(basename "${SHELL:-unknown}"). This script updates ~/.bashrc only."
  fi

  echo
  install_codex_cli_if_requested || true

  write_codex_config

  if test_unc_endpoint "$api_key"; then
    endpoint_verified=1
  fi

  echo
  if [[ "$endpoint_verified" -eq 1 ]]; then
    echo "Setup complete and verified."
  else
    echo "Configuration was saved, but setup could not be verified."
  fi
  echo "What happened:"
  echo "  API key export saved in ~/.bashrc"
  echo "  Codex config written under ${CODEX_HOME:-$HOME/.codex}"
  echo "  Model: $MODEL"
  if [[ -n "$REASONING_EFFORT" ]]; then
    echo "  Reasoning effort: $REASONING_EFFORT"
  else
    echo "  Reasoning effort: model default"
  fi
  if [[ "$endpoint_verified" -eq 1 ]]; then
    echo "  Endpoint test: succeeded"
  else
    echo "  Endpoint test: failed or unavailable"
    echo
    echo "Check the API key, network access, and selected model, then rerun setup."
    return 1
  fi

  start_codex_if_requested

  echo
  echo "Done. To refresh another shell later, run:"
  echo "  source ~/.bashrc"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
