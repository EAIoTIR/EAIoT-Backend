sw: $(ELF_FILE)

$(ELF_FILE): $(SW_SRCS) $(XSA_FILE) $(VITIS_TCL) Makefile
	$(call ensure_dir,$(VITIS_BUILD_DIR))
	$(XSCT) $(VITIS_TCL)
	$(call require_file,$@)

clean-sw:
	@rm -rf $(VITIS_BUILD_DIR)