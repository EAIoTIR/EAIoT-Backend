
set origin_dir [file normalize [file dirname [info script]]]
set prj_dir [file normalize "$origin_dir/../.."]
source [file normalize "$prj_dir/project_config.tcl"]

set APP_NAME "${PRJ_NAME}_baremetal"
set WS_DIR [file normalize "$prj_dir/build/$BOARD_NAME/vitis"]
set XSA_PATH [file normalize "$prj_dir/build/$BOARD_NAME/hw_platform/${BOARD_NAME}.xsa"]
set APP_SRC_DIR [file normalize "$prj_dir/sw/src"]
set BOARD_DIR [file normalize "$prj_dir/sw/boards/${BOARD_NAME}"]
set LINKER_SCRIPT_DIR [file normalize "$BOARD_DIR/lscript"]
set LINKER_SCRIPT [file normalize "$LINKER_SCRIPT_DIR/lscript.ld"]
set LHW_DIR    [file normalize "$WS_DIR/hw_platform"]

if {$ARCH_FAMILY eq "7000"} {
    set PROC_NAME "ps7_cortexa9_0"
} elseif {$ARCH_FAMILY eq "ultrascale+"} {
    set PROC_NAME "psu_cortexa53_0"
} else {
    error "Unsupported ARCH_FAMILY=$ARCH_FAMILY"
}

file mkdir $WS_DIR
setws $WS_DIR

if {[file exists $APP_NAME]} {
    puts "INFO: removing existing application project $APP_NAME"
    catch {app remove -name $APP_NAME}
}

file mkdir $LHW_DIR

file copy $XSA_PATH [file normalize "$LHW_DIR/${BOARD_NAME}.xsa"]

# --- Create app (empty standalone C) ---
# Template name can vary; adjust if your Vitis lists it differently.
app create -name $APP_NAME -hw [file normalize "$LHW_DIR/${BOARD_NAME}.xsa"] -os standalone -lang C -proc $PROC_NAME -template {Empty Application}

bsp write

# --- Link sources into the app (soft links) ---
# This links files instead of copying them into the workspace/app.
app config -name $APP_NAME -add include-path "$APP_SRC_DIR/app"
app config -name $APP_NAME -add include-path "$APP_SRC_DIR/eaiot-sdk"
app config -name $APP_NAME -add include-path "$APP_SRC_DIR/lib"
app config -name $APP_NAME -add include-path "$APP_SRC_DIR/platform"

app config -name $APP_NAME -add libraries "m"

app config -name $APP_NAME -set linker-script "$LINKER_SCRIPT"

importsources -name $APP_NAME -path $APP_SRC_DIR -soft-link

# --- Build ---
app build -name $APP_NAME
