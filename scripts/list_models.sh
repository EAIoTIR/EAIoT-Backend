#!/usr/bin/env bash
# =============================================================================
# list_models.sh  —  Show all registered models and which one is active
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

WRAPPER_H="$PROJECT_ROOT/sw/src/app/models/model_wrapper.h"
CONFIG_MK="$PROJECT_ROOT/mk/config.mk"

echo ""

if [ ! -f "$WRAPPER_H" ]; then
    echo "  No models are registered yet."
    echo ""
    echo "  Use 'make add-model MODEL_C=<file> MODEL_NAME=<NAME> INPUT_BIN=<file>' to add one."
    echo ""
    exit 0
fi

ACTIVE=$(grep -oP '(?<= #define ONNX2C_MODEL MODEL_)\S+' "$WRAPPER_H" 2>/dev/null || true)
DEFAULT=$(grep -oP '(?<=^DEFAULT_MODEL\s{0,20}:=\s{0,10})\S+' "$CONFIG_MK" 2>/dev/null || true)

MODEL_LINES=$(grep -P '^ #define MODEL_\S+ \d+' "$WRAPPER_H" || true)

if [ -z "$MODEL_LINES" ]; then
    echo "  No models are registered yet."
    echo ""
    echo "  Use 'make add-model MODEL_C=<file> MODEL_NAME=<NAME> INPUT_BIN=<file>' to add one."
    echo ""
    exit 0
fi

echo "  Registered models:"
echo "  ─────────────────────────────────────────"
while IFS= read -r line; do
    NAME=$(echo "$line" | grep -oP '(?<=#define MODEL_)\S+')
    IDX=$(echo  "$line" | grep -oP '\d+$')
    MARKER=""
    [ "$NAME" = "$ACTIVE"  ] && MARKER="${MARKER} ◀ active (firmware)"
    [ "$NAME" = "$DEFAULT" ] && MARKER="${MARKER} ★ default (host)"
    printf "  [%d]  %-24s%s\n" "$IDX" "$NAME" "$MARKER"
done <<< "$MODEL_LINES"
echo "  ─────────────────────────────────────────"
echo ""
echo "  To switch:  make set-model MODEL_NAME=<NAME>"
echo "  To add:     make add-model MODEL_C=<file> MODEL_NAME=<NAME> INPUT_BIN=<file>"
echo "  To remove:  make del-model MODEL_NAME=<NAME>"
echo ""
