#!/usr/bin/env bash
# =============================================================================
# del_model.sh  —  Remove a registered model from the EAIoT framework
#
# Usage:
#   ./scripts/del_model.sh <MODEL_NAME>
#
# If the deleted model was the active one, switches to the first remaining
# model automatically.  If it was the LAST model, the wrapper files are
# removed entirely so the project returns to a clean empty state.
# =============================================================================

set -euo pipefail

die()  { echo "[del_model] ERROR: $*" >&2; exit 1; }
info() { echo "[del_model] $*"; }
warn() { echo "[del_model] WARNING: $*"; }

[ "$#" -eq 1 ] || die "Usage: $0 <MODEL_NAME>"
MODEL_NAME="$1"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

WRAPPER_H="$PROJECT_ROOT/sw/src/app/models/model_wrapper.h"
WRAPPER_C="$PROJECT_ROOT/sw/src/app/models/model_wrapper.c"
MODELS_DIR="$PROJECT_ROOT/sw/src/app/models"
HOST_INPUTS="$PROJECT_ROOT/host/inputs"
HOST_OUTPUTS="$PROJECT_ROOT/host/outputs"
CONFIG_MK="$PROJECT_ROOT/mk/config.mk"

[ -f "$CONFIG_MK" ] || die "Expected file not found: $CONFIG_MK"
[ -f "$WRAPPER_H" ] || die "model_wrapper.h not found — no models are registered."
[ -f "$WRAPPER_C" ] || die "model_wrapper.c not found — no models are registered."

# Verify model is registered
grep -q "\bMODEL_${MODEL_NAME}\b" "$WRAPPER_H" || \
    die "Model '$MODEL_NAME' is not registered. Run 'make list-models' to see available models."

# Count remaining models
REGISTERED_MODELS=$(grep -oP '(?<= #define MODEL_)\S+(?= \d)' "$WRAPPER_H")
MODEL_COUNT=$(echo "$REGISTERED_MODELS" | grep -c .)

# Check if this is the currently active model
CURRENT_ACTIVE=$(grep -oP '(?<= #define ONNX2C_MODEL MODEL_)\S+' "$WRAPPER_H")
IS_ACTIVE=0
[ "$CURRENT_ACTIVE" = "$MODEL_NAME" ] && IS_ACTIVE=1

# -----------------------------------------------------------------------
# 1. Remove the model C source directory
# -----------------------------------------------------------------------
if [ -d "$MODELS_DIR/$MODEL_NAME" ]; then
    rm -rf "$MODELS_DIR/$MODEL_NAME"
    info "Removed sw/src/app/models/$MODEL_NAME/"
else
    warn "Source directory not found: $MODELS_DIR/$MODEL_NAME  (skipping)"
fi

# -----------------------------------------------------------------------
# 2. Remove host directories
# -----------------------------------------------------------------------
for DIR in "$HOST_INPUTS/$MODEL_NAME" "$HOST_OUTPUTS/$MODEL_NAME"; do
    if [ -d "$DIR" ]; then
        rm -rf "$DIR"
        info "Removed $DIR"
    else
        warn "Not found: $DIR  (skipping)"
    fi
done

# -----------------------------------------------------------------------
# 3a. LAST model — remove wrapper files entirely and clear DEFAULT_MODEL
# -----------------------------------------------------------------------
if [ "$MODEL_COUNT" -eq 1 ]; then
    rm -f "$WRAPPER_H" "$WRAPPER_C"
    info "Removed model_wrapper.h and model_wrapper.c  (no models remaining)"

    if grep -q "^DEFAULT_MODEL\s*:=" "$CONFIG_MK"; then
        sed -i "s|^DEFAULT_MODEL\s*:=.*|DEFAULT_MODEL        :=|" "$CONFIG_MK"
        info "mk/config.mk  →  DEFAULT_MODEL cleared"
    fi

    info ""
    info "✓  Model '$MODEL_NAME' removed.  No models are registered."
    info "   Use 'make add-model' to register a new model."
    exit 0
fi

# -----------------------------------------------------------------------
# 3b. More models remain — update wrapper files
# -----------------------------------------------------------------------

# Remove the define line and renumber remaining indices
python3 - "$WRAPPER_H" "$MODEL_NAME" << 'PYEOF'
import sys, re

path = sys.argv[1]
name = sys.argv[2]

text = open(path).read()

# Remove the define line for this model
text = re.sub(rf' #define MODEL_{re.escape(name)} \d+\n', '', text)

# Renumber remaining MODEL_ defines to stay contiguous (0, 1, 2, ...)
def renumber(m):
    lines = m.group(0).split('\n')
    result = []
    idx = 0
    for line in lines:
        line_new = re.sub(
            r'( #define MODEL_\S+ )\d+',
            lambda lm, i=idx: lm.group(1) + str(i),
            line
        )
        if re.search(r' #define MODEL_\S+ \d+', line_new):
            idx += 1
        result.append(line_new)
    return '\n'.join(result)

text = re.sub(
    r'(?m)^ #define MODEL_\S+ \d+\n(?:^ #define MODEL_\S+ \d+\n)*',
    renumber,
    text
)

open(path, 'w').write(text)
print(f"[del_model] model_wrapper.h  →  MODEL_{name} removed, indices renumbered")
PYEOF

# Remove the #if block from model_wrapper.c
python3 - "$WRAPPER_C" "$MODEL_NAME" << 'PYEOF'
import sys, re

path = sys.argv[1]
name = sys.argv[2]

text = open(path).read()

pattern = rf'\n+#if \(ONNX2C_MODEL == MODEL_{re.escape(name)}\).*?#endif\n'
new_text = re.sub(pattern, '\n', text, flags=re.DOTALL)

if new_text == text:
    print(f"[del_model] WARNING: No #if block found for MODEL_{name} in model_wrapper.c")
else:
    open(path, 'w').write(new_text)
    print(f"[del_model] model_wrapper.c  →  #if block for MODEL_{name} removed")
PYEOF

# -----------------------------------------------------------------------
# 4. If deleted model was active, switch to first remaining model
# -----------------------------------------------------------------------
if [ "$IS_ACTIVE" -eq 1 ]; then
    FALLBACK=$(grep -oP '(?<= #define MODEL_)\S+(?= \d)' "$WRAPPER_H" | head -1)
    info "Was active model — switching to: $FALLBACK"
    bash "$SCRIPT_DIR/set_model.sh" "$FALLBACK"
else
    info "Active model was '$CURRENT_ACTIVE' — no switch needed."
fi

# -----------------------------------------------------------------------
# Done
# -----------------------------------------------------------------------
info ""
info "✓  Model '$MODEL_NAME' has been removed."
info "   Run 'make list-models' to see remaining models."
