#!/usr/bin/env bash
# =============================================================================
# xmodem_transfer.sh  —  Send input.bin to the board, receive output.bin
#
# Usage:
#   ftp/xmodem_transfer.sh [MODEL_NAME]
#
#   MODEL_NAME  Optional override. Falls back to DEFAULT_MODEL which is
#               substituted at build time by Make (see mk/host.mk).
#               If neither is set, the script aborts with a clear message.
#
# Environment / Make variables forwarded by mk/host.mk:
#   DEFAULT_MODEL   — model name baked in from mk/config.mk
#   PORT            — serial port  (default: /dev/ttyUSB0)
#   BAUD            — baud rate    (default: 115200)
# =============================================================================

set -euo pipefail

# ---------------------------------------------------------------------------
# Resolve model name: CLI arg > Make-supplied DEFAULT_MODEL > error
# ---------------------------------------------------------------------------
if [ "${1:-}" != "" ]; then
    MODEL="$1"
elif [ "${DEFAULT_MODEL:-}" != "" ]; then
    MODEL="$DEFAULT_MODEL"
else
    echo "[host] ERROR: No model specified and DEFAULT_MODEL is not set." >&2
    echo "[host]        Run: make host MODEL_NAME=<NAME>" >&2
    echo "[host]        Or:  make list-models  to see registered models." >&2
    exit 1
fi

PORT="${PORT:-/dev/ttyUSB0}"
BAUD="${BAUD:-115200}"

# Paths are relative to the host/ directory (parent of ftp/)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOST_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

INPUT_FILE="$HOST_DIR/inputs/$MODEL/input.bin"
OUTPUT_FILE="$HOST_DIR/outputs/$MODEL/output.bin"

# ---------------------------------------------------------------------------
# Validate
# ---------------------------------------------------------------------------
[ -f "$INPUT_FILE" ] || {
    echo "[host] ERROR: Input file not found: $INPUT_FILE" >&2
    echo "[host]        Has model '$MODEL' been added?  Run: make list-models" >&2
    exit 1
}

mkdir -p "$(dirname "$OUTPUT_FILE")"

echo "[host] Model      : $MODEL"
echo "[host] Port       : $PORT  @  $BAUD"
echo "[host] Input      : $INPUT_FILE"
echo "[host] Output     : $OUTPUT_FILE"

# ---------------------------------------------------------------------------
# Transfer
# ---------------------------------------------------------------------------
# Configure serial port
stty -F "$PORT" "$BAUD" cs8 -cstopb -parenb -crtscts

# Step 1: Send input to board
echo "[host] Sending input.bin  →  board ..."
sx -vv "$INPUT_FILE" < "$PORT" > "$PORT"

# Step 2: Receive output from board
echo "[host] Receiving output.bin  ←  board ..."
rx "$OUTPUT_FILE" < "$PORT" > "$PORT"

echo "[host] Done.  Output saved to: $OUTPUT_FILE"
