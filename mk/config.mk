PROJECT_CONFIG := project_config.tcl

PRJ_NAME        := $(shell sed -n 's/^set PRJ_NAME "\(.*\)".*/\1/p' $(PROJECT_CONFIG))
BOARD        := $(shell sed -n 's/^set BOARD_NAME "\(.*\)".*/\1/p' $(PROJECT_CONFIG))
ARCH_FAMILY  := $(shell sed -n 's/^set ARCH_FAMILY "\(.*\)".*/\1/p' $(PROJECT_CONFIG))
DEVICE_CLASS := $(shell sed -n 's/^set DEVICE_CLASS "\(.*\)".*/\1/p' $(PROJECT_CONFIG))
PART         := $(shell sed -n 's/^set PART "\(.*\)".*/\1/p' $(PROJECT_CONFIG))
JOBS         := $(shell sed -n 's/^set JOBS \(.*\)/\1/p' $(PROJECT_CONFIG))

BUILD_DIR        := build/$(BOARD)
HW_BUILD_DIR     := $(BUILD_DIR)/hw_platform
VIVADO_BUILD_DIR := $(BUILD_DIR)/vivado
VITIS_BUILD_DIR  := $(BUILD_DIR)/vitis

DEPLOY_STAMP     := $(BUILD_DIR)/deploy/.stamp

XSA_FILE         := $(HW_BUILD_DIR)/$(BOARD).xsa
SW_APP_NAME      := $(PRJ_NAME)_baremetal
ELF_FILE         := $(VITIS_BUILD_DIR)/$(SW_APP_NAME)/Debug/$(SW_APP_NAME).elf

VIVADO_TCL       := hw/scripts/build_vivado.tcl
VITIS_TCL        := sw/scripts/build_vitis_xsct.tcl
DEPLOY_TCL       := deploy/scripts/program_board.tcl

HDL_SRCS         := $(shell find hw/hdl -type f 2>/dev/null)
HW_SCRIPT_SRCS   := $(shell find hw/bd hw/boards hw/scripts -type f 2>/dev/null) project_config.tcl
SW_SRCS          := $(shell find sw/src/app sw/boards sw/scripts -type f 2>/dev/null)
DEPLOY_SRCS      := $(shell find deploy/scripts -type f 2>/dev/null)
HOST_SRCS    := $(shell find host -type f 2>/dev/null)

PYTHON ?= python3
VIVADO ?= vivado
XSCT   ?= xsct

# Active model — managed by scripts/add_model.sh, set_model.sh, del_model.sh.
# Override on the command line:  make host MODEL_NAME=LSTM
DEFAULT_MODEL        := MNIST_CNN