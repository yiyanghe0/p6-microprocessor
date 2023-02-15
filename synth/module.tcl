#/***********************************************************/
#/*   FILE        : module.tcl                              */
#/*   Description : Default Synopsys Design Compiler Script */
#/*   Usage       : dc_shell-t -f module.tcl                */
#/*   Much of the configuration has been moved to the       */
#/*   Makefile, so this shouldn't require changes per-design*/
#/***********************************************************/
set search_path [ list "./" "/afs/umich.edu/class/eecs470/lib/synopsys/" ]
set target_library "lec25dscc25_TT.db"
set link_library [concat  "*" $target_library]

# this apparently makes it so it is optional to add the
# // synopsys sync_set_reset "reset"
# line before every always_ff block
# not updating every source file because of this though
set hdlin_ff_always_sync_set_reset true

# uncomment this and change number appropriately if on multi-core machine
set_host_options -max_cores [getenv DC_SHELL_MULTICORE]

#/***********************************************************/
#/* Set some flags to suppress warnings we don't care about */
set suppress_errors [concat $suppress_errors "UID-401"]
suppress_message {"VER-130"}

#/***********************************************************/
#/* The following lines read and elaborate the sources and  */
#/* set the design name                                     */
#/***********************************************************/
lappend search_path ../

# these environment variables are set by the Makefile

set sources [getenv SOURCES]
set design_name [getenv TOP_NAME]
# the combination of analyze and elaborate does the same thing as read_file
# although analyze doesn't seem to play well with header files
analyze -format sverilog $sources

# try to elaborate and set the current design, but quit early if we failed somehow
# this is very imperfect, and will still continue through seemingly obvious bugs to fail in compilation
if {![elaborate $design_name]} {exit 1}
if {[current_design $design_name] == [list] } {exit 1}

set clock_name clock
set reset_name reset
set CLOCK_PERIOD [getenv CLOCK_PERIOD]

set syn_dir ./

#/***********************************************************/
#/* The rest of this file may be left alone for most small  */
#/* to moderate sized designs.  You may need to alter it    */
#/* when synthesizing your final project.                   */
#/* It's probably best to copy into a new .tcl file if you  */
#/* do make changes.                                        */
#/***********************************************************/

# Set some flags for optimisation

set compile_top_all_paths "true"
set auto_wire_load_selection "false"
set compile_seqmap_synchronous_extraction "true"

# timing constraints

set CLK_TRANSITION 0.1 ;# unused
set CLK_UNCERTAINTY 0.1
set CLK_LATENCY 0.1 ;# unused

# input/output delay values
set AVG_INPUT_DELAY 0.1
set AVG_OUTPUT_DELAY 0.1

# critical range (ns)
set CRIT_RANGE 1.0

# Design Constraints

set MAX_TRANSITION 1.0
set FAST_TRANSITION 0.1 ;# unused
set MAX_FANOUT 32
set MID_FANOUT 8 ;# unused
set LOW_FANOUT 1 ;# unused
set HIGH_DRIVE 0 ;# unused
set HIGH_LOAD 1.0 ;# unused
set AVG_LOAD 0.1
set AVG_FANOUT_LOAD 10

# some variables

set DRIVING_CELL dffacs1
set WIRE_LOAD "tsmcwire"
set LOGICLIB lec25dscc25_TT

# output filenames

set chk_file     ${syn_dir}${design_name}.chk ;# a check file of warnings and errors
set netlist_file ${syn_dir}${design_name}.vg  ;# our .vg file! it's generated here!
set ddc_file     ${syn_dir}${design_name}.ddc ;# is the internal dc_shell design representation
                                               # can be read in another design with 'read_ddc'
# the svsim file, unnecessary for most designs, but can be useful for generating parameterized
# modules that instantiate the netlist (.vg) modules, uncomment if you want to also generate these
# set svsim_file   ${syn_dir}${design_name}_svsim.sv
set rep_file     ${syn_dir}${design_name}.rep ;# reoprt file, has area, timing, and constraint reports
set res_file     ${syn_dir}${design_name}.res ;# resources file

# design compile

current_design $design_name
link
set_wire_load_model -name $WIRE_LOAD -lib $LOGICLIB $design_name
set_wire_load_mode top
set_fix_multiple_port_nets -outputs -buffer_constants
create_clock -period $CLOCK_PERIOD -name $clock_name [find port $clock_name]
set_clock_uncertainty $CLK_UNCERTAINTY $clock_name
set_fix_hold $clock_name
group_path -from [all_inputs] -name input_grp
group_path -to [all_outputs] -name output_grp
set_driving_cell  -lib_cell $DRIVING_CELL [all_inputs]
remove_driving_cell [find port $clock_name]
set_fanout_load $AVG_FANOUT_LOAD [all_outputs]
set_load $AVG_LOAD [all_outputs]
set_input_delay $AVG_INPUT_DELAY -clock $clock_name [all_inputs]
remove_input_delay -clock $clock_name [find port $clock_name]
set_output_delay $AVG_OUTPUT_DELAY -clock $clock_name [all_outputs]
set_dont_touch $reset_name
set_resistance 0 $reset_name
set_drive 0 $reset_name
set_critical_range $CRIT_RANGE [current_design]
set_max_delay $CLOCK_PERIOD [all_outputs]
set MAX_FANOUT $MAX_FANOUT ;# does this actually do anything?
set MAX_TRANSITION $MAX_TRANSITION ;# ??? I'm not going to remove it but...
# did they mean set_max_fanout ???
uniquify
ungroup -all -flatten
# output the check file before we compile
redirect $chk_file { check_design }

# compile!
compile -map_effort medium

# output other files
write -hier -format verilog -output $netlist_file $design_name
write -hier -format ddc -output $ddc_file $design_name
# the svsim file, unnecessary for most designs, but can be useful for generating parameterized
# modules that instantiate the netlist (.vg) modules, uncomment if you want to also generate these
#write -format svsim -output $svsim_file $design_name
redirect $rep_file { report_design -nosplit }
redirect -append $rep_file { report_area }
redirect -append $rep_file { report_timing -max_paths 2 -input_pins -nets -transition_time -nosplit }
redirect -append $rep_file { report_constraint -max_delay -verbose -nosplit }
redirect $res_file { report_resources -hier }
remove_design -all
# also report the reference from the netlist file
read_file -format verilog $netlist_file
current_design $design_name
redirect -append $rep_file { report_reference -nosplit }
quit
