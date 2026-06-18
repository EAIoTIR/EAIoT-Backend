#!/usr/bin/env bash
# =============================================================================
# set_model.sh  —  Switch the active model (firmware + host default)
#
# Usage:
#   ./scripts/set_model.sh <MODEL_NAME>
#
# Updates:
#   • ONNX2C_MODEL in sw/src/app/models/model_wrapper.h
#   • DEFAULT_MODEL in mk/config.mk
# =============================================================================

set -euo pipefail

die()  { echo "[set_model] ERROR: $*" >&2; exit 1; }
info() { echo "[set_model] $*"; }

[ "$#" -eq 1 ] || die "Usage: $0 <MODEL_NAME>"
MODEL_NAME="$1"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

WRAPPER_H="$PROJECT_ROOT/sw/src/app/models/model_wrapper.h"
CONFIG_MK="$PROJECT_ROOT/mk/config.mk"

[ -f "$CONFIG_MK" ] || die "Not found: $CONFIG_MK"
[ -f "$WRAPPER_H" ] || die "model_wrapper.h not found — no models are registered. Use 'make add-model' first."

# Verify the model is registered
grep -q "\bMODEL_${MODEL_NAME}\b" "$WRAPPER_H" || \
    die "Model '$MODEL_NAME' is not registered. Run 'make list-models' to see available models."

# Switch ONNX2C_MODEL in model_wrapper.h
sed -i "s|^\( #define ONNX2C_MODEL\) .*|\1 MODEL_${MODEL_NAME}|" "$WRAPPER_H"
info "model_wrapper.h  →  ONNX2C_MODEL = MODEL_$MODEL_NAME"

# Switch DEFAULT_MODEL in config.mk
if grep -q "^DEFAULT_MODEL\s*:=" "$CONFIG_MK"; then
    sed -i "s|^DEFAULT_MODEL\s*:=.*|DEFAULT_MODEL        := $MODEL_NAME|" "$CONFIG_MK"
    info "mk/config.mk     →  DEFAULT_MODEL = $MODEL_NAME"
else
    info "WARNING: DEFAULT_MODEL line not found in mk/config.mk — add it manually."
fi

info ""
info "✓  Active model is now '$MODEL_NAME'."
info "   Run 'make sw' to rebuild firmware with the new model."
