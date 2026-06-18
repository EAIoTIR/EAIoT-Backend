SHELL := /bin/bash
.DEFAULT_GOAL := all

include mk/config.mk
include mk/utils.mk
include mk/hw.mk
include mk/sw.mk
include mk/deploy.mk
include mk/host.mk

.PHONY: all help clean clean-hw clean-sw clean-deploy \
        hw_platform sw deploy host print-config status \
        add-model del-model set-model list-models

all: hw_platform sw

help:
	@echo ""
	@echo "  Build targets:"
	@echo "    make all                                              build HW platform + SW"
	@echo "    make hw_platform                                      build Vivado HW platform"
	@echo "    make sw                                               build Vitis firmware"
	@echo "    make deploy                                           program the board"
	@echo ""
	@echo "  Host (transfer) targets:"
	@echo "    make host                                             run with DEFAULT_MODEL ($(DEFAULT_MODEL))"
	@echo "    make host MODEL_NAME=<NAME>                          override model for this run"
	@echo ""
	@echo "  Model management:"
	@echo "    make list-models                                      show all registered models"
	@echo "    make add-model MODEL_C=<f> MODEL_NAME=<N> INPUT_BIN=<f>   add + activate a model"
	@echo "    make set-model MODEL_NAME=<NAME>                     switch active / default model"
	@echo "    make del-model MODEL_NAME=<NAME>                     remove a model"
	@echo ""
	@echo "  Info:"
	@echo "    make print-config                                     show build variables"
	@echo "    make status                                           show build artefact status"
	@echo ""
	@echo "  Board      : $(BOARD)"
	@echo "  Arch       : $(ARCH_FAMILY)"
	@echo "  Default model : $(DEFAULT_MODEL)"
	@echo ""

# ---------------------------------------------------------------------------
# Model management targets
# ---------------------------------------------------------------------------

## List all registered models, highlighting the active and default ones.
list-models:
	@bash scripts/list_models.sh

## Register a new onnx2c model, copy input.bin, and set it as the active model.
##   make add-model MODEL_C=path/to/model.c MODEL_NAME=MY_NET INPUT_BIN=path/to/input.bin
add-model:
	@test -n "$(MODEL_C)"    || { echo ""; echo "  ERROR: MODEL_C is required."; \
	  echo "  Usage: make add-model MODEL_C=<file> MODEL_NAME=<NAME> INPUT_BIN=<file>"; echo ""; exit 1; }
	@test -n "$(MODEL_NAME)" || { echo ""; echo "  ERROR: MODEL_NAME is required."; \
	  echo "  Usage: make add-model MODEL_C=<file> MODEL_NAME=<NAME> INPUT_BIN=<file>"; echo ""; exit 1; }
	@test -n "$(INPUT_BIN)"  || { echo ""; echo "  ERROR: INPUT_BIN is required."; \
	  echo "  Usage: make add-model MODEL_C=<file> MODEL_NAME=<NAME> INPUT_BIN=<file>"; echo ""; exit 1; }
	@bash scripts/add_model.sh "$(MODEL_C)" "$(MODEL_NAME)" "$(INPUT_BIN)"

## Switch the active model (firmware #define + host default).
##   make set-model MODEL_NAME=LSTM
set-model:
	@test -n "$(MODEL_NAME)" || { echo ""; echo "  ERROR: MODEL_NAME is required."; \
	  echo "  Usage: make set-model MODEL_NAME=<NAME>"; \
	  echo "  Run 'make list-models' to see available models."; echo ""; exit 1; }
	@bash scripts/set_model.sh "$(MODEL_NAME)"

## Remove a model and all its associated files.
##   make del-model MODEL_NAME=LSTM
del-model:
	@test -n "$(MODEL_NAME)" || { echo ""; echo "  ERROR: MODEL_NAME is required."; \
	  echo "  Usage: make del-model MODEL_NAME=<NAME>"; \
	  echo "  Run 'make list-models' to see available models."; echo ""; exit 1; }
	@bash scripts/del_model.sh "$(MODEL_NAME)"

print-config:
	@echo "PRJ_NAME=$(PRJ_NAME)"
	@echo "BOARD=$(BOARD)"
	@echo "ARCH_FAMILY=$(ARCH_FAMILY)"
	@echo "DEVICE_CLASS=$(DEVICE_CLASS)"
	@echo "PART=$(PART)"
	@echo "JOBS=$(JOBS)"
	@echo "BUILD_DIR=$(BUILD_DIR)"
	@echo "XSA_FILE=$(XSA_FILE)"
	@echo "ELF_FILE=$(ELF_FILE)"

status:
	@echo "[status] board      : $(BOARD)"
	@echo "[status] arch       : $(ARCH_FAMILY)"
	@echo "[status] xsa        : $(if $(wildcard $(XSA_FILE)),OK,MISSING)"
	@echo "[status] elf        : $(if $(wildcard $(ELF_FILE)),OK,MISSING)"

clean: clean-sw clean-hw clean-deploy
	@rm -f build/.host.stamp