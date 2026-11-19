#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEFAULT_GODOT_BIN="/Users/liuyunfeng/Library/Application Support/Steam/steamapps/common/Godot Engine/Godot.app/Contents/MacOS/Godot"
GODOT_BIN="${GODOT_BIN:-$DEFAULT_GODOT_BIN}"
USER_DATA_DIR="$PROJECT_DIR/.godot_user_data"
LOG_FILE="${GODOT_LOG_FILE:-$USER_DATA_DIR/godot-validation.log}"

mkdir -p "$USER_DATA_DIR/logs"

if [[ ! -x "$GODOT_BIN" ]]; then
	echo "Godot executable was not found or is not executable:" >&2
	echo "  $GODOT_BIN" >&2
	echo "Set GODOT_BIN=/path/to/Godot to override it." >&2
	exit 1
fi

echo "Project: $PROJECT_DIR"
echo "Godot:  $GODOT_BIN"
echo "Log:    $LOG_FILE"
echo

"$GODOT_BIN" --version
echo

"$GODOT_BIN" \
	--headless \
	--path "$PROJECT_DIR" \
	--log-file "$LOG_FILE" \
	--quit \
	"$@"

echo
echo "Godot headless validation finished."
