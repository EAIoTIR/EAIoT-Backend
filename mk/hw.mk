hw_platform: $(XSA_FILE)

$(XSA_FILE): $(HDL_SRCS) $(HW_SCRIPT_SRCS) $(VIVADO_TCL) Makefile
	$(call ensure_dir,$(HW_BUILD_DIR))
	$(call ensure_dir,$(VIVADO_BUILD_DIR))
	$(VIVADO) -mode batch -source $(VIVADO_TCL)
	$(call require_file,$@)

clean-hw:
	@rm -rf $(HW_BUILD_DIR) $(VIVADO_BUILD_DIR)