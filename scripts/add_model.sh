#!/usr/bin/env bash
# =============================================================================
# add_model.sh  —  Register a new onnx2c-generated model into the EAIoT framework
#
# Usage:
#   ./scripts/add_model.sh <model_c_file> <model_name> <input.bin>
#
#   <model_c_file>  Path to the C file exported by onnx2c (with or without
#                   the #include / #if guard header — the script normalises it)
#   <model_name>    UPPER_SNAKE_CASE identifier  (e.g. MY_NET)
#   <input.bin>     Binary input sample
#
# If model_wrapper.h / model_wrapper.c do not exist (empty project), they are
# created from scratch before the model is registered.
# =============================================================================

set -euo pipefail

die()  { echo "[add_model] ERROR: $*" >&2; exit 1; }
info() { echo "[add_model] $*"; }

# ---------------------------------------------------------------------------
# Arguments
# ---------------------------------------------------------------------------
[ "$#" -eq 3 ] || die "Usage: $0 <model_c_file> <model_name> <input.bin>"

MODEL_C="$1"
MODEL_NAME="$2"
INPUT_BIN="$3"

[ -f "$MODEL_C" ]   || die "Model C file not found: $MODEL_C"
[ -f "$INPUT_BIN" ] || die "Input binary not found: $INPUT_BIN"

[[ "$MODEL_NAME" =~ ^[A-Z][A-Z0-9_]*$ ]] || \
    die "model_name must be UPPER_SNAKE_CASE (start with a letter, only A-Z 0-9 _). Got: $MODEL_NAME"

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

WRAPPER_H="$PROJECT_ROOT/sw/src/app/models/model_wrapper.h"
WRAPPER_C="$PROJECT_ROOT/sw/src/app/models/model_wrapper.c"
MODELS_DIR="$PROJECT_ROOT/sw/src/app/models"
HOST_INPUTS="$PROJECT_ROOT/host/inputs"
HOST_OUTPUTS="$PROJECT_ROOT/host/outputs"
CONFIG_MK="$PROJECT_ROOT/mk/config.mk"

[ -f "$CONFIG_MK" ] || die "Expected file not found: $CONFIG_MK"

# ---------------------------------------------------------------------------
# Bootstrap wrapper files if the models folder has no registered models yet
# ---------------------------------------------------------------------------
mkdir -p "$MODELS_DIR"

if [ ! -f "$WRAPPER_H" ] || [ ! -f "$WRAPPER_C" ]; then
    info "model_wrapper files not found — creating from scratch."

    cat > "$WRAPPER_H" << 'EOF'
 #ifndef __MODEL_WRAPPER_H__
 #define __MODEL_WRAPPER_H__

 void run_onnx2c(void*, void**, int*);


 /// CHANGE THIS TO CHANGE MODEL
 #define ONNX2C_MODEL MODEL_PLACEHOLDER

 #endif
EOF

    cat > "$WRAPPER_C" << 'EOF'
#include "model_wrapper.h"
EOF

    info "Created model_wrapper.h and model_wrapper.c"
fi

# ---------------------------------------------------------------------------
# Duplicate check
# ---------------------------------------------------------------------------
grep -q "MODEL_${MODEL_NAME}\b" "$WRAPPER_H" && \
    die "Model '$MODEL_NAME' is already registered in model_wrapper.h. Aborting."
[ -d "$MODELS_DIR/$MODEL_NAME" ] && \
    die "Directory $MODELS_DIR/$MODEL_NAME already exists. Aborting."

# ---------------------------------------------------------------------------
# Parse entry() signature
# ---------------------------------------------------------------------------
ENTRY_LINE=$(grep -m1 "^void entry(" "$MODEL_C") || \
    die "Could not find 'void entry(' in $MODEL_C"

info "Signature : $ENTRY_LINE"

IN_DIMS=$(echo  "$ENTRY_LINE" | sed 's/.*tensor_input\(\(\[[^]]*\]\)\+\).*/\1/')
OUT_DIMS=$(echo "$ENTRY_LINE" | sed 's/.*tensor_output\(\(\[[^]]*\]\)\+\).*/\1/')

[ -n "$IN_DIMS" ]  || die "Failed to parse input dims from:  $ENTRY_LINE"
[ -n "$OUT_DIMS" ] || die "Failed to parse output dims from: $ENTRY_LINE"

IN_REST=$(echo  "$IN_DIMS"  | sed 's/^\[[^]]*\]//')
OUT_REST=$(echo "$OUT_DIMS" | sed 's/^\[[^]]*\]//')

[ -n "$IN_REST" ]  || die "Input tensor has only 1 dimension (cannot form pointer-to-array cast)."
[ -n "$OUT_REST" ] || die "Output tensor has only 1 dimension (cannot form pointer-to-array cast)."

OUTPUT_ELEMS=$(echo "$OUT_REST" | grep -oP '\d+' | awk 'BEGIN{p=1} {p*=$1} END{print p}')
[ -n "$OUTPUT_ELEMS" ] || die "Failed to compute output element count."

INPUT_CAST="(const float (*)${IN_REST})"
OUTPUT_CAST="(float (*)${OUT_REST})"

info "Input  dims : $IN_DIMS   →  cast $INPUT_CAST"
info "Output dims : $OUT_DIMS  →  cast $OUTPUT_CAST  (${OUTPUT_ELEMS} floats)"

# ---------------------------------------------------------------------------
# 1. Copy C file and inject correct #include / #if guard
# ---------------------------------------------------------------------------
MODEL_DIR="$MODELS_DIR/$MODEL_NAME"
mkdir -p "$MODEL_DIR"
C_BASENAME=$(basename "$MODEL_C")
DEST_C="$MODEL_DIR/$C_BASENAME"

python3 - "$MODEL_C" "$DEST_C" "$MODEL_NAME" << 'PYEOF'
import sys, re

src_path   = sys.argv[1]
dst_path   = sys.argv[2]
model_name = sys.argv[3]

lines = open(src_path).readlines()

# Strip any existing #include "../model_wrapper.h" and the #if that follows it
cleaned = []
skip_next_if = False
for line in lines:
    if re.match(r'\s*#include\s+"[./]*model_wrapper\.h"', line):
        skip_next_if = True
        continue
    if skip_next_if:
        skip_next_if = False
        if re.match(r'\s*#if\s+\(ONNX2C_MODEL\s*==\s*MODEL_', line):
            continue
    cleaned.append(line)

# Strip lone closing #endif at end of file (the old guard footer)
i = len(cleaned) - 1
while i >= 0 and cleaned[i].strip() == '':
    i -= 1
if i >= 0 and cleaned[i].strip() == '#endif':
    cleaned.pop(i)

# Insert point: after the leading // comment block, before first #include
insert_at = 0
for idx, line in enumerate(cleaned):
    if line.startswith('//') or line.strip() == '':
        insert_at = idx + 1
    else:
        break

header = [
    '#include "../model_wrapper.h"\n',
    f'#if (ONNX2C_MODEL == MODEL_{model_name})\n',
]
footer = ['#endif\n']

result = cleaned[:insert_at] + header + cleaned[insert_at:] + footer

with open(dst_path, 'w') as f:
    f.writelines(result)

print(f"[add_model] Written {dst_path}  (guards set to MODEL_{model_name})")
PYEOF

# ---------------------------------------------------------------------------
# 2. Update model_wrapper.h — add define + switch active model
# ---------------------------------------------------------------------------
python3 - "$WRAPPER_H" "$MODEL_NAME" << 'PYEOF'
import sys, re

path = sys.argv[1]
name = sys.argv[2]

text = open(path).read()

# Find the highest existing MODEL_ index; -1 means none yet
existing = re.findall(r'#define MODEL_\S+ (\d+)', text)
next_idx = max((int(x) for x in existing), default=-1) + 1

new_define = f' #define MODEL_{name} {next_idx}\n'

# If there are existing MODEL_ defines, insert after the last one
if existing:
    text = re.sub(
        r'( #define MODEL_\S+ \d+\n)(\n /// CHANGE)',
        lambda m: m.group(1) + new_define + m.group(2),
        text
    )
else:
    # No defines yet — insert the first one before the /// CHANGE comment
    text = re.sub(
        r'(\n /// CHANGE)',
        '\n' + new_define + r'\1',
        text
    )

# Switch (or set) the active model, replacing PLACEHOLDER if present
text = re.sub(
    r' #define ONNX2C_MODEL \S+\n',
    f' #define ONNX2C_MODEL MODEL_{name}\n',
    text
)

open(path, 'w').write(text)
print(f"[add_model] model_wrapper.h  →  MODEL_{name}={next_idx}, ONNX2C_MODEL=MODEL_{name}")
PYEOF

# ---------------------------------------------------------------------------
# 3. Append run_onnx2c block to model_wrapper.c
# ---------------------------------------------------------------------------
python3 - "$WRAPPER_C" "$MODEL_NAME" "$OUTPUT_ELEMS" "$INPUT_CAST" "$OUTPUT_CAST" << 'PYEOF'
import sys

path        = sys.argv[1]
name        = sys.argv[2]
out_elems   = sys.argv[3]
input_cast  = sys.argv[4]
output_cast = sys.argv[5]

block = f"""

#if (ONNX2C_MODEL == MODEL_{name})

void run_onnx2c(void* input , void** output_p, int* output_size_p) {{

\t*output_size_p = sizeof(float) * {out_elems};

  \t*output_p = malloc(*output_size_p);

\tentry({input_cast} input, {output_cast} (*output_p));

}}
#endif
"""

with open(path, 'a') as f:
    f.write(block)

print(f"[add_model] model_wrapper.c  →  appended #if block for MODEL_{name}")
PYEOF

# ---------------------------------------------------------------------------
# 4. Host directories + input.bin
# ---------------------------------------------------------------------------
mkdir -p "$HOST_INPUTS/$MODEL_NAME"
mkdir -p "$HOST_OUTPUTS/$MODEL_NAME"
cp "$INPUT_BIN" "$HOST_INPUTS/$MODEL_NAME/input.bin"
info "host/inputs/$MODEL_NAME/input.bin  ✓"
info "host/outputs/$MODEL_NAME/          ✓"

# ---------------------------------------------------------------------------
# 5. Update DEFAULT_MODEL in mk/config.mk
# ---------------------------------------------------------------------------
if grep -q "^DEFAULT_MODEL\s*:=" "$CONFIG_MK"; then
    sed -i "s|^DEFAULT_MODEL\s*:=.*|DEFAULT_MODEL        := $MODEL_NAME|" "$CONFIG_MK"
    info "mk/config.mk  →  DEFAULT_MODEL = $MODEL_NAME"
else
    info "WARNING: DEFAULT_MODEL not found in mk/config.mk — skipping that update."
    info "         Add 'DEFAULT_MODEL := $MODEL_NAME' manually if needed."
fi

# ---------------------------------------------------------------------------
# Done
# ---------------------------------------------------------------------------
info ""
info "✓  Model '$MODEL_NAME' registered and set as default."
info ""
info "   sw/src/app/models/$MODEL_NAME/$C_BASENAME"
info "   host/inputs/$MODEL_NAME/input.bin"
info "   host/outputs/$MODEL_NAME/  (ready for output)"
info ""
info "   Run 'make sw'   to rebuild firmware."
info "   Run 'make host' to transfer input and collect output."
