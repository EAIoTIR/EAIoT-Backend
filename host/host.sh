#!/usr/bin/env bash
# =============================================================================
# host.sh  —  Transfer input to the board and collect output
#
# Usage (called by Make):
#   host/host.sh [MODEL_NAME]
#
#   MODEL_NAME  Optional. Overrides the DEFAULT_MODEL baked in at build time.
#               Passed through from 'make host MODEL_NAME=<NAME>'.
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$SCRIPT_DIR/ftp/xmodem_transfer.sh" "$@"
