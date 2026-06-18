define ensure_dir
	@mkdir -p $(1)
endef

define require_file
	@test -f $(1) || { echo "ERROR: missing file: $(1)"; exit 1; }
endef