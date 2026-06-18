# # scripts/vitis/program_and_run.tcl
# # Run: xsct scripts/vitis/program_and_run.tcl
# #
# # Optional args:
# #   xsct scripts/vitis/program_and_run.tcl <xsa_path> <bit_path> <elf_path> [hw_server_url]
# #
# # Examples:
# #   xsct scripts/vitis/program_and_run.tcl build/hw_platform/MYIR_ZTURNV2.xsa \
# #       build/vivado/<proj>.runs/impl_1/<top>.bit \
# #       build/vitis/MYIR_ZTURNV2/app_MYIR_ZTURNV2/Debug/app_MYIR_ZTURNV2.elf


# set origin_dir [file normalize [file dirname [info script]]]
# set prj_dir     [file normalize "$origin_dir/../../"]
# source [file normalize "$prj_dir/project_config.tcl"]


# # --- User/configurable bits ---
# set APP_NAME   "app_${BOARD_NAME}"
# # Canonical repo sources (kept outside the workspace)
# set SRC_DIR    [file normalize "$prj_dir/src/baremetal/${BOARD_NAME}"]
# set LHW_DIR    [file normalize "$WS_DIR/hw_platform"]

# set XSA_PATH   [file normalize "$WS_DIR/hw_platform/${BOARD_NAME}.xsa"]


# set url      [lindex $argv 1]
# if {$url eq ""} { set url "localhost:3121" }

# # Fallbacks (edit to match your repo)
# # bit_path can be optional if you only want to run SW on an already-configured PL
# # elf_path can be optional if you only want to program PL


# connect -url "TCP:$url"

# # Load HW description so XSCT understands the targets/memory map
# targets -set -filter {name =~ "APU"}
# loadhw $XSA_PATH

# # Initialize PS (common Zynq-7000 flow)
# # If you have ps7_init.tcl from your board vendor, source it here instead.
# rst -system

# set INIT_TCL_PATH   [file normalize "$WS_DIR/hw_platform/ps7_init.tcl"]
# puts "Sourcing PS init script: $INIT_TCL_PATH"
# source $INIT_TCL_PATH
# ps7_init
# ps7_post_config

# # Program PL if bit provided
# set BIT_PATH   [file normalize "$WS_DIR/hw_platform/${BOARD_NAME}.bit"]
# if {$BIT_PATH ne ""} {
#   fpga -file $BIT_PATH
# }

# # Download/run ELF if provided
# set ELF_PATH   [file normalize "$WS_DIR/app_${BOARD_NAME}/Debug/app_${BOARD_NAME}.elf"]
# if {$ELF_PATH ne ""} {
#   targets -set -nocase -filter {name =~ "ARM Cortex-A9*#0"}
#   rst -processor
#   dow $ELF_PATH
#   con
# }
#############################
set origin_dir [file normalize [file dirname [info script]]]
set prj_dir [file normalize "$origin_dir/../.."]
source [file normalize "$prj_dir/project_config.tcl"]

set APP_NAME "${PRJ_NAME}_baremetal"
set XSA_PATH [file normalize "$prj_dir/build/$BOARD_NAME/hw_platform/${BOARD_NAME}.xsa"]
set ELF_PATH [file normalize "$prj_dir/build/$BOARD_NAME/vitis/${APP_NAME}/Debug/${APP_NAME}.elf"]
set WS_DIR     [file normalize "$prj_dir/build/$BOARD_NAME/vitis"]

if {$ARCH_FAMILY eq "7000"} {
    set CPU_FILTER {name =~ "ARM Cortex-A9*#0"}
    set PS_FILTER {name =~ "APU*"}
    set INIT_TCL_PATH   [file normalize "$WS_DIR/hw_platform/ps7_init.tcl"]
    set PS_INIT_CMD "ps7_init"
    set PS_POST_CMD "ps7_post_config"

} elseif {$ARCH_FAMILY eq "ultrascale+"} {
    set CPU_FILTER {name =~ "Cortex-A53*#0"}
    set PS_FILTER {name =~ "APU*"}
    set INIT_TCL_PATH   [file normalize "$WS_DIR/hw_platform/psu_init.tcl"]
    set PS_INIT_CMD "psu_init"
    set PS_POST_CMD "psu_post_config"

} else {
    error "Unsupported ARCH_FAMILY=$ARCH_FAMILY"
}

set url [lindex $argv 0]
if {$url eq ""} { 
connect 
set url "localhost:3121" }
connect -url "TCP:$url"
targets -set -filter $PS_FILTER
loadhw $XSA_PATH


rst -system

puts "Sourcing PS init script: $INIT_TCL_PATH"
source $INIT_TCL_PATH

$PS_INIT_CMD
$PS_POST_CMD

set BIT_PATH   [file normalize "$WS_DIR/hw_platform/${BOARD_NAME}.bit"]
if {$BIT_PATH ne ""} {
  fpga -file $BIT_PATH
}

targets -set -nocase -filter $CPU_FILTER
rst -processor
dow $ELF_PATH
con