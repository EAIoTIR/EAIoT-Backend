deploy: $(DEPLOY_STAMP)

$(DEPLOY_STAMP): $(DEPLOY_SRCS) $(XSA_FILE) $(ELF_FILE) $(DEPLOY_TCL) Makefile
	$(call ensure_dir,$(@D))
	$(XSCT) $(DEPLOY_TCL)
	@touch $@

clean-deploy:
	@rm -rf $(BUILD_DIR)/deploy