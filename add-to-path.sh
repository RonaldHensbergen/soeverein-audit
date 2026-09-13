#!/usr/bin/env bash
# Symlinks all audit scripts in this repo into a bin directory (default:
# ~/.local/bin, override with the first argument) without the .sh
# extension, and ensures that directory is on PATH for future shells.
#
# Usage:
#   ./add-to-path.sh [bin-dir]
#
# After running, restart your shell (or `source` your shell rc file) and
# run e.g. `repo-audit`, `audit-cloud-sdk`, `audit-iac-lockin`, `audit-saas`,
# `audit-licenses` from anywhere.
set -uo pipefail

REPO_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
BIN_DIR="${1:-$HOME/.local/bin}"

SCRIPTS=(
  repo-audit.sh
  audit-cloud-sdk.sh
  audit-iac-lockin.sh
  audit-saas.sh
  audit-licenses.sh
)

mkdir -p "$BIN_DIR"

echo "Linking scripts into $BIN_DIR ..."
LINKED=()
for s in "${SCRIPTS[@]}"; do
  src="$REPO_DIR/$s"
  name="${s%.sh}"
  dest="$BIN_DIR/$name"

  if [ ! -f "$src" ]; then
    echo "  skip: $s (not found in $REPO_DIR)"
    continue
  fi

  chmod +x "$src"
  ln -sf "$src" "$dest"
  echo "  linked: $name -> $src"
  LINKED+=("$name")
done

# Make sure BIN_DIR is actually on PATH, now and in future shells.
case ":${PATH:-}:" in
  *":$BIN_DIR:"*)
    echo "$BIN_DIR is already on PATH."
    ;;
  *)
    SHELL_RC="$HOME/.profile"
    case "${SHELL:-}" in
      */zsh)  SHELL_RC="$HOME/.zshrc" ;;
      */bash) SHELL_RC="$HOME/.bashrc" ;;
    esac

    EXPORT_LINE="export PATH=\"$BIN_DIR:\$PATH\""
    if ! grep -Fqs "$EXPORT_LINE" "$SHELL_RC" 2>/dev/null; then
      {
        echo ""
        echo "# Added by soeverein-audit's add-to-path.sh"
        echo "$EXPORT_LINE"
      } >> "$SHELL_RC"
      echo "Added $BIN_DIR to PATH in $SHELL_RC."
    else
      echo "$BIN_DIR already configured in $SHELL_RC."
    fi
    echo "Restart your shell, or run: source $SHELL_RC"
    ;;
esac

echo
echo "Available commands (once PATH is updated):"
for name in "${LINKED[@]}"; do
  echo "  $name"
done
