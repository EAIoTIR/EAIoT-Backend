
set origin_dir [file normalize [file dirname [info script]]]
set prj_dir     [file normalize "$origin_dir/../../"]

source [file normalize "$prj_dir/project_config.tcl"]

set board_name $BOARD_NAME
set arch_family $ARCH_FAMILY
set hw_out_dir  [file normalize "$prj_dir/build/$board_name/hw_platform"]
set src_hdl_dir [file normalize "$prj_dir/hw/hdl"] 
set bd_tcl      [file normalize "$prj_dir/hw/bd/${arch_family}.tcl"]
set preset_tcl  [file normalize "$prj_dir/hw/boards/${board_name}.tcl"]
set vivado_prj_dir [file normalize "$prj_dir/build/$board_name/vivado"]


# 1) Create/open project
create_project -force $PRJ_NAME $vivado_prj_dir -part $PART


# 2) Add HDL sources (recursive scan supported)
add_files $src_hdl_dir

update_compile_order -fileset sources_1

# 3) Recreate/import block design from Tcl
# Convention: bd tcl creates a design_1 and leaves it open.
source $bd_tcl

# 4) Apply PS preset for the selected board (your board_files/*.tcl)
# This assumes your preset script targets the PS IP instance inside the BD.
source $preset_tcl

# 5) Validate & generate output products, then synth/impl/bitstream
validate_bd_design
save_bd_design
# After BD exists and is saved (design_1.bd is just an example name)
set bd_file [get_files -quiet *.bd]
make_wrapper -files $bd_file -top -import -force

# Set the wrapper as top (common wrapper module name: <bd_name>_wrapper)
# Example if bd name is "design_1" -> top "design_1_wrapper"
set_property top design_1_wrapper [current_fileset]
update_compile_order -fileset sources_1

generate_target all [get_files *.bd]
launch_runs synth_1 -jobs $JOBS
wait_on_run synth_1

launch_runs impl_1 -to_step write_bitstream -jobs $JOBS
wait_on_run impl_1

# 6) Export hardware platform (.xsa) INCLUDING bitstream
write_hw_platform -fixed -include_bit -force \
  -file [file normalize "$hw_out_dir/${BOARD_NAME}.xsa"]
