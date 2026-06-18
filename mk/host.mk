## Host transfer target.
## Usage:
##   make host                        — use DEFAULT_MODEL from mk/config.mk
##   make host MODEL_NAME=LSTM        — override model for this run only
host:
	@MODEL_NAME_RESOLVED="$${MODEL_NAME:-$(DEFAULT_MODEL)}"; \
	 DEFAULT_MODEL="$(DEFAULT_MODEL)" \
	 PORT="$${PORT:-/dev/ttyUSB0}" \
	 BAUD="$${BAUD:-115200}" \
	 $(SHELL) host/host.sh "$$MODEL_NAME_RESOLVED"