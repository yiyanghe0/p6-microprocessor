#########################
# ---- Introduction ----
#########################

# Welcome to the VeriSimpleV Makefile!
# this file will allow you to build a fully synthesizable verilog processor
# it should need only minimal changes, if any, for use in project 3
# but will be reused for project 4 and will need updates as you add new files and functionality
# this will mostly be editing SIMFILES, SYNFILES, and TESTBENCH in the executable compilation section
# but feel free to mess around! There are plenty of comments on different make features
# and you should try things out. But make sure you commit changes to git before you break things!

# here's a table contents with make targets for reference:

# ---- Module Testbenches ----
# make <module>_simv     <- compile the verilog executable for a module's testbench
# make <module>.vg       <- synthesize the module (not the testbench) to a synth/<module>.vg file
# make <module>_syn_simv <- compile the verilog executable for a module's synthesis testbench
# make <module>.sim      <- run the module testbench and save the output to output/<module>.sim.out
# make <module>.syn      <- run the synthesis testbench and save the output to output/<module>.syn.out
# make <module>.verdi     <- run a module testbench in verdi via <module>_simv
# make <module>.syn.verdi <- run a module testbench in verdi via <module>_syn_simv
# NOTE: these expect a module verilog/<module>.sv with a corresponding testbench/<module>_tb.sv

# ---- Executable Compilation ----
# make simv     <- compile the verilog executable simv from the testbench and SIMFILES
# make syn_simv <- compile the synthesis executable syn_simv from the testbench and SYNFILES

# ---- Program Memory Compilation ----
# NOTE: programs to run are in the test_progs/ directory
# make <my_program>.mem <- creates the program memory file output/<my_program>.mem for running on simv etc

# ---- Dump Files ----
# make <my_program>.dump_numeric <- creates a numeric dump file for viewing the disassembled source code
# make <my_program>.dump_abi     <- creates an abi dump file for viewing the disassembled source code
# make <my_program>.dump         <- creates both of the above files  at once and is easier to type :)
# make <my_program>.debug.dump_* <- creates dump files for C programs that intersperses the C source code

# ---- Program Execution ----
# NOTE: these should be your main commands for running programs and generating output
# make <my_program>.out     <- run a program on simv and generate .out and .wb output in output/
# make <my_program>.syn.out <- run a program on syn_simv and do the same

# ---- Verdi ----
# make <my_program>.verdi     <- run a program in the verdi debugger via simv
# make <my_program>.syn.verdi <- the same but via syn_simv

# ---- Visual Debugger ----
# make <my_program>.vis <- run a program on the project 3 vtuber visual debugger!
# make vis_simv         <- compile the vtuber executable from visual_testbench.sv and the SIMFILES

# ---- Cleanup ----
# make clean <- remove most created files except specific synthesis files and .mem files
# make nuke  <- remove all files created from make rules

# each of these will compile/run any of their dependencies as needed, and needs no other
# commands to be called first, this is one of the major improvements from the legacy system
# which would require recompiling multiple files before each run of a different program on simv

# I've also added the targets: compile_all dump_all simulate_all simulate_all_syn
# that respectively compile, dump, and simulate EVERY program in test_progs/ at once
# NOTE: you can use the -j flag with make to allow make to run multithreaded to finish these faster
# although this will make color printing funky because of the interleaved output

# credits:
# VeriSimpleV was created by Jielun Tan and has been edited by at least:
# Nevil Pooniwala, Xueyang Liu, Cassie Jones, James Connolly, and Ian Wrzesinski
# the current layout and updates to the Makefile (Jan 2023) were made by Ian Wrzesinski
# other instructors have also likely edited it, but it's hard to find their names in our messy bitbucket
# so this is a specific shoutout to them: thank you all!
# and massive thanks to Jielun Tan for creating VeriSimpleV and his continuous work on it!

########################
# ---- Directories ----
########################

# this is a built-in Make variable that lets Make search folders to find dependencies and targets
# it can greatly simplify make rules and increase readability
VPATH = synth:testbench:test_progs:verilog:output

###############################################
# ---- Compilation Commands and Variables ----
###############################################

# these are various build flags for different parts of the makefile, VCS and LIB should be
# familiar, but there are new variables for supporting the compilation of assembly and C
# source programs into riscv machine code files to be loaded into the processor's memory

# don't be afraid of changing these, but be diligent about testing changes (and make git commits often!)

# stops the "Too Few Instance Port Connection" warnings that amount to ~2.4MiB of text when compiling simv
VCS_NO_WARNINGS = +warn=noTFIPC +warn=noDEBUG_DEP +warn=noENUMASSIGN
VCS = vcs -V -sverilog +vc -Mupdate -line -full64 +vcs+vcdpluson -kdb -lca -debug_access+all $(VCS_NO_WARNINGS)
# also gets appended with a +define+CLOCK_PERIOD in the Common Variables section below

# LIB is the reference file for the standard structural cells
# this is what the synthesized code is linked against
LIB = /afs/umich.edu/class/eecs470/lib/verilog/lec25dscc25.v

CRT = crt.s
LINKERS = linker.lds
ASLINKERS = aslinker.lds
DEBUG_FLAG = -g

# you might want to update these build flags for the final project, but make sure you know what they do:
# https://gcc.gnu.org/onlinedocs/gcc/RISC-V-Options.html
CFLAGS = -mno-relax -march=rv32im -mabi=ilp32 -nostartfiles -std=gnu11 -mstrict-align -mno-div
# adjust the optimization if you want programs to run faster; this may obfuscate/change their instructions
OFLAGS = -O0
ASFLAGS = -mno-relax -march=rv32im -mabi=ilp32 -nostartfiles -Wno-main -mstrict-align
OBJFLAGS = -SD -M no-aliases
OBJCFLAGS = --set-section-flags .bss=contents,alloc,readonly
OBJDFLAGS = -SD -M numeric,no-aliases

# NOTE: change this and update the below variables if you aren't using a caen machine
CAEN = 1
ifeq (1, $(CAEN))
	GCC     = riscv gcc
	OBJCOPY = riscv objcopy
	OBJDUMP = riscv objdump
	AS      = riscv as
	ELF2HEX = riscv elf2hex
else
	GCC     = riscv64-unknown-elf-gcc
	OBJCOPY = riscv64-unknown-elf-objcopy
	OBJDUMP = riscv64-unknown-elf-objdump
	AS      = riscv64-unknown-elf-as
	ELF2HEX = elf2hex
endif

#############################
# ---- Common Variables ----
#############################

# this is a global clock period variable used in sys_defs.svh and the .tcl scripts
# TODO: you need to reduce this period while keeping an efficient design
# <25 is expected, <20 is good, and <6.66 causes memory to run out of tags (100ns/15 cycles)
# although these numbers are vague ideas, and you should base them on *your* processor's performance
# and don't worry about getting the absolute minimum clock period possible, but do minimize it somewhat
# its also good to target values that are below a cutoff for num memory cycles: 5:20, 6:16.67, 7:14.29
CLOCK_PERIOD = 30.0
# NOTE: synthesis will target this value, but doesn't go farther; you can have 0.0 slack and still decrease
# however, pushing this to the limit will make synthesis take longer (as the synthesizer does more work)
# so start high, then decrease as you begin testing changes that will impact the clock period

# referenced in sys_defs.svh
VCS += +define+CLOCK_PERIOD=$(CLOCK_PERIOD)+

# nice to define the headers up here and export them statically
HEADERS = sys_defs.svh \
          ISA.svh
# ^ note: could replace with $(wildcard *.svh)

# this is read by the .tcl scripts
# also the SOURCES and TOP_NAME variables, but those are set per-command using 'env'
export CLOCK_PERIOD
export HEADERS
# ^ not currently used, but might be nice if you change the .tcl files

# dc_shell supports compiling with multiple cores to improve compile time
# this variable is used by the .tcl script in 'set_host_options -max_cores' to change that
export DC_SHELL_MULTICORE = 1

#####################
# ---- Printing ----
#####################

# this is a function with two arguments: PRINT_COLOR(color : int 0-7, msg : string)
PRINT_COLOR = if [ -t 0 ]; then tput setaf $(1) ; fi; echo $(2); if [ -t 0 ]; then tput sgr0; fi
# this decomposes to:
# first, check if in a terminal and in a compliant shell
# second, use tput setaf to set the ANSI Foreground color based on the number 0-7:
#   0:black, 1:red, 2:green, 3:yellow, 4:blue, 5:magenta, 6:cyan, 7:white
# third, echo the message
# finally, reset the terminal color (but still only if a terminal)
# make functions are called like this:
# $(call PRINT_COLOR,5,msg)
# add '@' at the start of the line so it doesn't print the command itself, only the output

GREP = grep --color=auto

###########################
# ---- Default Target ----
###########################

# The first make rule is the default target and is run when calling 'make' by itself
# it is often called "all" by convention, but you can change it to anything
# don't place any other make targets above this

all: mult_no_lsq.out
# make won't check for the existence of .PHONY targets, and will run their commands every time
# since this is generally what we want for all, we declare it as phony like so:
.PHONY: all

###############################
# ---- Module Testbenches ----
###############################

# create module testbenches for your modules, and update the TESTED_MODULES variable below
# these targets expect you to follow the naming convention:
# for a module verilog/rob.sv
# declares a module named rob
# with a testbench as testbench/rob_tb.sv

# quick target reference:
# make <module>_simv      <- compile the testbench executable
# make <module>.sim       <- run the testbench (output is output/<module>.sim.out)
# make <module>.vg        <- synthesize the module (not the testbench)
# make <module>_syn_simv  <- compile the synthesis executable
# make <module>.syn       <- run the synthesis testbench (output is output/<module>.syn.out)
# make <module>.verdi     <- run in verdi via <module>_simv
# make <module>.syn.verdi <- run in verdi via <module>_syn_simv

# NOTE: if you make your testbenches print @@@Passed or @@@Failed
# you can use the 'testbench_passed' target below to quickly view success/failure

# TODO TODO TODO TODO
# create a testbench for your first module
# if your module is verilog/rob.sv, add rob to TESTED_MODULES
# and make your testbench file: testbench/rob_tb.sv

# delete this comment area when you want to
# TODO TODO TODO TODO

TESTED_MODULES = RS_entry

# if a module includes other modules, add the dependencies explicitly here
# this works due to the targets using the $^ automatic variable
# example for an execute_stage module that uses mult:
#   execute_stage_simv: mult.sv
#   synth/execute_stage.vg: mult.sv
# must do for both .vg and _simv targets (_syn_simv gets it implicitly through the .vg file)


# this make rule will generate <name>_simv targets from the TESTED_MODULES variable e.g. 'make rob_simv'
# it expects a <name>_tb.sv file in the testbench folder
$(TESTED_MODULES:=_simv): %_simv: $(HEADERS) verilog/RS/%.sv testbench/%_tb.sv
	@$(call PRINT_COLOR, 5, compiling testbench for the $* module)
	@$(call PRINT_COLOR, 3, NOTE: if this is slow to startup: run '"module load vcs verdi"')
	$(VCS) $^ -o $@
	@$(call PRINT_COLOR, 6, finished compiling $@ testbench)
# NOTE: I don't need to add the verilog/ and testbench/ dirs in these recipes due to the VPATH variable

# this generates the <name>.sim targets that actually run the tesbench e.g. 'make rob_sim'
$(TESTED_MODULES:=.sim): %.sim: %_simv | output
	@$(call PRINT_COLOR, 5, running testbench for the $* module)
	./$< | tee output/$(@F).out
	@$(call PRINT_COLOR, 6, finished running $* testbench)
	@$(call PRINT_COLOR, 2, output is in output/$(@F).out)
.PHONY: %.sim

# make sure that you copy-paste actual tab characters here, sometimes piazza turns them to spaces
# around line 252 is a good location for this

# it can be nice to have a separate executable for coverage computations
# however you could just change the default VCS arguments and reuse <module>_simv below
VCS_COVERAGE = -cm line+fsm+tgl+branch+assert
$(TESTED_MODULES:=_coverage_simv): %_coverage_simv: $(HEADERS) verilog/RS/%.sv testbench/%_tb.sv
	@$(call PRINT_COLOR, 5, compiling coverage testbench for the $* module)
	@$(call PRINT_COLOR, 3, NOTE: if this is slow to startup: run '"module load vcs verdi"')
	$(VCS) $(VCS_COVERAGE) $^ -o $@
	@$(call PRINT_COLOR, 6, finished compiling $@)

$(TESTED_MODULES:=.coverage): %.coverage: %_coverage_simv novas.rc verdi_dir | output
	@$(call PRINT_COLOR, 5, running coverage testbench for the $* module)
	./$< $(VCS_COVERAGE) | tee output/$*.coverage
	@$(call PRINT_COLOR, 2, coverage output is in output/$*.coverage)
	@$(call PRINT_COLOR, 5, running verdi in coverage mode for the $* testbench)
	./$< -gui=verdi -cov -covdir $<.vdb

# synthesis is a bit more complicated, as we have to first generate .vg files for each module
# this is only set up to compile modules that only get instantiated at one parameter value
# if you need to instantiate multiple sizes of modules for one testbench, you can try editing this
# or ask one of the GSIs/IAs for help editing this (note you'll probably need more .tcl files)

MODULE_TCL_SCRIPT = module.tcl

# use the module.tcl script to synthesize each module into .vg files e.g. 'make rob.vg'
$(TESTED_MODULES:%=synth/%.vg): synth/%.vg: verilog/RS/%.sv | $(MODULE_TCL_SCRIPT) $(HEADERS)
	@$(call PRINT_COLOR, 5, synthesizing vg file for $* testbench)
	@$(call PRINT_COLOR, 3, this might take a while...)
	@$(call PRINT_COLOR, 3, NOTE: if this is slow to startup: run '"module load synopsys-synth"')
	# pipefail causes the command to exit on failure even though it's piping to tee
	set -o pipefail; cd synth && env TOP_NAME=$* SOURCES="$^" dc_shell-t -f $(MODULE_TCL_SCRIPT) | tee $*_synth.out
	@$(call PRINT_COLOR, 6, finished synthesizing $@)

# this make rule will generate <name>_syn_simv targets for compiling the .vg file into a testbench e.g. 'make rob_syn_simv'
# it expects a <name>_tb.sv file in the testbench folder
$(TESTED_MODULES:=_syn_simv): %_syn_simv: $(HEADERS) synth/%.vg testbench/%_tb.sv
	@$(call PRINT_COLOR, 5, compiling synth testbench for the $* module)
	$(VCS) $^ $(LIB) -o $@
	@$(call PRINT_COLOR, 6, finished compiling $@ synth testbench)
# NOTE: LIB has to come after the other sources as it doesn't define a timescale, and must inherit it from a previous module

# this generates the <name>.syn targets that actually run the tesbench e.g. 'make rob_syn'
$(TESTED_MODULES:=.syn): %.syn: %_syn_simv | output
	@$(call PRINT_COLOR, 5, running synth testbench for the $* module)
	./$< | tee output/$(@F).out
	@$(call PRINT_COLOR, 6, finished running $* synth testbench)
	@$(call PRINT_COLOR, 2, output is in output/$(@F).out)
.PHONY: %.syn

# test all modules in one command
test_all_modules: $(TESTED_MODULES:=.sim)
test_all_modules_synth: $(TESTED_MODULES:=.syn)
.PHONY: test_all_modules test_all_modules_synth

# verdi rules:
# 'make <name>.verdi' or 'make <name>.syn.verdi'
$(TESTED_MODULES:=.verdi): %.verdi: %_simv novas.rc verdi_dir
	./$< -gui=verdi
$(TESTED_MODULES:=.syn.verdi): %.syn.verdi: %_syn_simv novas.rc verdi_dir
	./$< -gui=verdi
.PHONY: %.verdi %.syn.verdi

# quick useful rules:
# view synthesis slack
slack:
	$(GREP) "slack" synth/*.rep
# check if testbenches passed or failed (must $display @@@Passed or @@@Failed in your testbenches)
testbench_passed:
	$(GREP) "@@@Passed|@@@Failed" output/*.sim.out output/*.syn.out
.PHONY: slack testbench_passed

###################################
# ---- Executable Compilation ----
###################################

# These are the files and recipes for compiling the verilog executables simv and syn_simv
# Note that for projects 3/4, the executable is not the only thing you need to compile
# you must also create a .mem file for the program you're running that will be loaded
# into mem.sv's memory data by the testbench on startup.

# To actually run a program on simv or syn_simv, see the program compilation section later
# you can also use the legacy targets 'sim' and 'syn' that use the legacy program.mem file

# TODO TODO TODO TODO

# start by testing individual modules in the module testbench section above
# only edit this section once you're ready to test your full processor

# the old processor does not compile with the CACHE_MODE flag defined in sys_defs.svh
# it is your job to update your processor work with this mode
# the included icache.sv module should be a good starting place
# and you should update SIMFILES to compile your files when you start to test the full processor
# the old *_stage.sv files have been included for your reference in verilog/old_verilog/

# delete this comment area when you want to
# TODO TODO TODO TODO

# if you want to restore the original processor functionality temporarily:
# (i.e. when testing non-memory functionality)
# 1. comment out CACHE_MODE in sys_defs
# 2. define MEM_LATENCY_IN_CYCLES as 0 in sys_defs
# 3. set SIMFILES = pipeline.sv regfile.sv $(wildcard verilog/old_verilog/*_stage.sv)
# your final processor must work with CACHE_MODE enabled and the 100ns memory latency

# NOTE: we're able to write these filenames without directories due to the VPATH declaration above
# Make will automatically expand these to their actual paths when used in recipes
TESTBENCH = testbench.sv \
            mem.sv
#TESTBENCH = verilog/RS/RS_entry_testbench.sv
# you could simplify this line with $(wildcard verilog/*.sv) - but the manual way is more explicit
SIMFILES = pipeline.sv \
           regfile.sv \
           icache.sv \
           mult.sv

#SIMFILES = verilog/RS/RS_entry_unfinalized.sv

simv: $(HEADERS) $(TESTBENCH) $(SIMFILES)
	@$(call PRINT_COLOR, 5, compiling $@)
	@$(call PRINT_COLOR, 3, NOTE: if this is slow to startup: run '"module load vcs verdi"')
	$(VCS) $^ -o simv
	@$(call PRINT_COLOR, 6, finished compiling $@)

# NOTE: ^ is an automatic variable, and is replaced by the list of all of the prerequisites
# ^, <, @, *, etc are also automatic variables that are used in this makefile
# see: https://www.gnu.org/software/make/manual/html_node/Automatic-Variables.html

SYNFILES = synth/pipeline.vg

# if you add more .vg files to your synthesis build, make sure to add new build rules and TCL scripts for them
# you shouldn't have to for project 3, but likely will for project 4 when doing individual testbenches
PIPELINE_TCL_SCRIPT = pipeline.tcl
synth/pipeline.vg: $(SIMFILES) | $(PIPELINE_TCL_SCRIPT) $(HEADERS)
	@$(call PRINT_COLOR, 5, synthesizing $@)
	@$(call PRINT_COLOR, 3, this might take a while...)
	@$(call PRINT_COLOR, 3, NOTE: if this is slow to startup: run '"module load synopsys-synth"')
	# pipefail causes the command to exit on failure even though it's piping to tee
	set -o pipefail; cd synth && env TOP_NAME=pipeline SOURCES="$^" dc_shell-t -f $(PIPELINE_TCL_SCRIPT) | tee pipeline_synth.out
	@$(call PRINT_COLOR, 6, finished synthesizing $@)

syn_simv: $(HEADERS) $(TESTBENCH) $(SYNFILES)
	@$(call PRINT_COLOR, 5, compiling $@)
	$(VCS) $^ $(LIB) -o syn_simv
	@$(call PRINT_COLOR, 6, finished compiling $@)
# NOTE: LIB has to come after the other sources as it doesn't define a timescale, and must inherit it from a previous module

##############################
# ---- Build Directories ----
##############################

# some targets in this makefile are built in the output/ directory for organization
# this rule creates the output directory if it doesn't exist yet
# the entire directory is deleted by 'make nuke', so be careful with that
# NOTE: add "| output" at the end of make rules that put things into output
# it creates 'ordered' dependencies that are built first, and in order
# because you can't put files into output/ if it doesn't exist
output:
ifeq ($(wildcard output/.),) # whether output/ exists
	mkdir output
endif

#######################################
# ---- Program Memory Compilation ----
#######################################

# this section is where you compile programs into .mem files to be loaded into
# memory by the testbench on startup
# you start with either an assembly or C program in the test_progs/ directory
# you compile those into a link file by using the riscv assembler or compiler
# then you convert that assembly to a .mem hex file
# this section uses some more complicated make syntax you might not be familiar with
# so I'll explain new stuff as it's introduced with the NOTE keyword below

# read all the test program files and separate them based on suffix of .s or .c
ASSEMBLY = $(wildcard test_progs/*.s)
C_CODE   = $(wildcard test_progs/*.c)

# concatenate ASSEMBLY and C_CODE to create a list of all the desired programs (in the output dir)
# NOTE: this is Make's pattern substitution syntax
# see: https://www.gnu.org/software/make/manual/html_node/Text-Functions.html#Text-Functions
# it's technically equivalent to calling the function: $(patsubst pattern,replacement,$(var))
# but the better syntax is: $(var:pattern=replacement)
# the percent sign '%' acts as the wildcard, and can be reused in the replacement
# if you don't include the percent it automatically attempts to replace just the suffix of the input
PROGRAMS = $(ASSEMBLY:test_progs/%.s=output/%) $(C_CODE:test_progs/%.c=output/%)

# make link files from assembly code (matches the legacy 'assemble' target)
# NOTE: this is complicated Make syntax, but is extremely powerful and concise
# first, this creates a variable holding the desired target filenames (i.e. output/sampler.elf)
# second, it creates a 'static pattern rule' that turns all the elements of the variable into targets
# see: https://www.gnu.org/software/make/manual/html_node/Static-Usage.html
# the pattern part allows me to extract the name of the program using the '%' wildcard
# and I then reuse that as the $* automatic variable in the declaration
ASSEMBLY_ELF = $(ASSEMBLY:test_progs/%.s=output/%.elf)
$(ASSEMBLY_ELF): output/%.elf: test_progs/%.s | $(ASLINKERS) output
	@$(call PRINT_COLOR, 5, compiling assembly file $*.s)
	$(GCC) $(ASFLAGS) $^ -T $(ASLINKERS) $(CUSTOM_ASM_ARGS) -o $@

# make link files from C source code (matches the legacy 'compile' target)
C_CODE_ELF = $(C_CODE:test_progs/%.c=output/%.elf)
$(C_CODE_ELF): output/%.elf: $(CRT) test_progs/%.c | $(LINKERS) output
	@$(call PRINT_COLOR, 5, compiling C code file $*.c)
	$(GCC) $(CFLAGS) $(OFLAGS) $^ -T $(LINKERS) $(CUSTOM_C_ARGS) -o $@

# NOTE: the .elf commands only compile single file sources, however it's not difficult to add multi-source files
# if you had a file 'test_progs/multi.c' that needed to compile with 'test_progs/helper1.c' and
# 'test_progs/obj_helper2.o', you would uncomment the following line:
# multi.elf: helper1.c obj_helper2.o
# this adds the dependences to the $^ variable used in the command above (also why LINKERS is after the |)
# NOTE: I've also included CUSTOM_ASM_ARGS and CUSTOM_C_ARGS variables that you can override at
# the command line in case you need more complicated functionality:
# make multi.elf CUSTOM_C_ARGS="test_progs/helper1.c test_progs/obj_helper2.o -v -pipe etc"

# NOTE: I declare the .elf files as intermediate files here.
# Make will automatically rm intermediate files after they're used in a recipe
# and it won't remake targets depending on them if they don't exist
# but if their sources (*.s *.c) are updated, then they'll be made and deleted again as needed
.INTERMEDIATE: $(ASSEMBLY_ELF) $(C_CODE_ELF)

# turn any link file into a hex memory file ready for the testbench (matches the legacy 'hex' target)
%.mem: %.elf
	$(ELF2HEX) 8 8192 $< > $@
	@$(call PRINT_COLOR, 6, created memory file $@)
	@$(call PRINT_COLOR, 3, NOTE - to see the disassembled code)
	@$(call PRINT_COLOR, 3, make $*.dump_numeric or $*.dump_abi)
	@$(call PRINT_COLOR, 3, for .c sources - make .debug.dump_\*)

# this command compiles all the programs at once
# NOTE: use 'make -j' to run multithreaded
compile_all: $(PROGRAMS:=.mem)
.PHONY: compile_all

#######################
# ---- Dump Files ----
#######################

# it can also be usefule to look at dump files that represent the compiled riscv assembly code
# there are two types, which are useful for debugging different things:
#   1. dump_numeric gives dump files where the registers use their numeric values, better for debugging
#      with verdi in the waveform view
#   2. dump_abi gives dump files where the registers use their named values as written in the sources
#      this is better for testing that your assembly matches a source file you wrote
# these match the legacy 'disassemble' target (dump_abi is .dump, and dump_numeric is .debug.dump)

# this creates the <my_program>.debug.elf targets, which can be used in: 'make <my_program>.debug.dump_*'
# these are useful for the C sources because the debug flag makes the assembly more understandable
# because it includes some of the original C operations and function/variable names
# NOTE: static pattern make rules generally need their dependencies to be above them in the makefile
# otherwise you can get the 'No rule to make target' error, due to being unable to find a dependency
DEBUG_C_PROGRAMS = $(C_CODE:test_progs/%.c=output/%.debug)
$(DEBUG_C_PROGRAMS:=.elf): output/%.debug.elf: test_progs/%.c $(CRT) | $(LINKERS) output
	@$(call PRINT_COLOR, 5, making debug C code link file $*.c)
	$(GCC) $(DEBUG_FLAG) $(CFLAGS) $(OFLAGS) $^ -T $(LINKERS) $(CUSTOM_C_ARGS) -o $@

DUMP_PROGRAMS = $(PROGRAMS) $(DEBUG_C_PROGRAMS)

# 'make <my_program>.dump_numeric'
$(DUMP_PROGRAMS:=.dump_numeric): %.dump_numeric: %.elf
	@$(call PRINT_COLOR, 5, disassembling $<)
	$(OBJDUMP) $(OBJDFLAGS) $< > $@
	@$(call PRINT_COLOR, 6, created numeric dump file $@)

# 'make <my_program>.dump_abi'
$(DUMP_PROGRAMS:=.dump_abi): %.dump_abi: %.elf
	@$(call PRINT_COLOR, 5, disassembling $<)
	$(OBJDUMP) $(OBJFLAGS) $< > $@
	@$(call PRINT_COLOR, 6, created abi dump file $@)

# 'make <my_program>.dump' will create both files at once!
$(DUMP_PROGRAMS:=.dump): %.dump: %.dump_numeric %.dump_abi
.PHONY: %.dump

# this command creates all dump files at once
# NOTE: use 'make -j' to run multithreaded
dump_all: $(DUMP_PROGRAMS:=.dump_abi) $(DUMP_PROGRAMS:=.dump_numeric)
.PHONY: dump_all

##############################
# ---- Program Execution ----
##############################

# run one of the executables (simv/syn_simv) using the chosen program
# e.g. 'make sampler.out' does the following from a clean directory:
#   1. compiles simv
#   2. compiles test_progs/sampler.s into its .elf and then .mem file (in output/)
#   3. runs ./simv +MEMORY=output/sampler.mem +WRITEBACK=output/sampler.wb
#   4. which creates the sampler.out and sampler.wb files in output/
# the same can be done for synthesis by doing 'make sampler.syn.out'
# which will also create .syn.wb and files in output/
# NOTE: deleted references to .ppln files, as they are not compatible with the final project

# NOTE: see the explanation of this syntax above at ASSEMBLY_ELF
$(PROGRAMS:=.out): %.out: simv %.mem
	@$(call PRINT_COLOR, 5, running simv with $*.mem)
	./simv +MEMORY=$*.mem +WRITEBACK=$*.wb > $@
	@$(call PRINT_COLOR, 6, finished running $*.mem)
	@$(call PRINT_COLOR, 2, output is in $@ $*.wb)

# this does the same as simv, but adds .syn to the output files and compiles syn_simv instead
# run synthesis with: 'make <my_program>.syn.out'
$(PROGRAMS:=.syn.out): %.syn.out: syn_simv %.mem
	@$(call PRINT_COLOR, 5, running syn_simv with $*.mem)
	@$(call PRINT_COLOR, 3, this might take a while...)
	./syn_simv +MEMORY=$*.mem +WRITEBACK=$*.syn.wb > $@
	@$(call PRINT_COLOR, 6, finished running $*.mem)
	@$(call PRINT_COLOR, 2, "output is in $@ $*.syn.wb")

# these commands run all the programs on simv or syn_simv in one command
# NOTE: use 'make -j' to run multithreaded
# NOTE: I'm using ordered prerequisites here (via the | character) so that make first compiles
# everything before it runs anything, otherwise the output will be much messier
# see: https://www.gnu.org/software/make/manual/html_node/Prerequisite-Types.html
simulate_all: $(PROGRAMS:=.out) | compile_all simv
simulate_all_syn: $(PROGRAMS:=.syn.out) | compile_all syn_simv
.PHONY: simulate_all simulate_all_syn

##################
# ---- Verdi ----
##################

# run verdi on a program with: 'make <my_program>.verdi' or 'make <my_program>.syn.verdi'

# this creates a directory that verdi will use if it doesn't exist yet
verdi_dir:
	if [[ ! -d /tmp/$${USER}470 ]] ; then mkdir /tmp/$${USER}470 ; fi
.PHONY: verdi_dir

novas.rc: initialnovas.rc
	sed s/UNIQNAME/$$USER/ initialnovas.rc > novas.rc

# these are phony targets because they don't produce output files and should just run every time
$(PROGRAMS:=.verdi): %.verdi: simv %.mem novas.rc verdi_dir
	./simv -gui=verdi +MEMORY=$*.mem +WRITEBACK=/dev/null

$(PROGRAMS:=.syn.verdi): %.syn.verdi: syn_simv %.mem novas.rc verdi_dir
	./syn_simv -gui=verdi +MEMORY=$*.mem +WRITEBACK=/dev/null
.PHONY: %.verdi

# these targets use the legacy program.mem system and load the program in SOURCE below
verdi: simv novas.rc verdi_dir program.mem $(SOURCE)
	./simv -gui=verdi
verdi_syn: syn_simv novas.rc verdi_dir program.mem $(SOURCE)
	./syn_simv -gui=verdi
.PHONY: verdi verdi_syn

############################
# ---- GUI Debugger ----
############################

# feel free to write your own debugger for project 4!

##################################################
# ---- Legacy program.mem Compilation System ----
##################################################

# This is the old system for compiling programs, it required you to run
# 'make assembly' or 'make program' for Assembly vs C code SOURCE
# in order to to create "program.mem" which would be overwritten every time
# and which was hardcoded in the testbench.sv file for loading into memory.
# It would also create the hardcoded program.out, writeback.out, (and pipeline.out - not for p4)
# files which would also be overwritten every time.
# This doesn't follow the way Make is meant to be used for creating files and
# the new compilation system should be used instead.
# However I only have so much time to edit both this and the autograder
# this semester, so I'm leaving this for backwards compatibility.
# running simv or syn_simv with no arguments will still load "program.mem" into memory

# the source program for the legacy system
# NOTE: you can override this at the command line like: 'make SOURCE=test_progs/<my_program.s/.c>'
# this however always recompiles program.mem and is inefficient vs the new system
SOURCE = test_progs/sampler.s

assemble: $(ASLINKERS)
	@$(call PRINT_COLOR, 5, compiling assembly file $(SOURCE))
	$(GCC) $(ASFLAGS) $(SOURCE) -T $(ASLINKERS) -o program.elf
	cp program.elf program.debug.elf

compile: $(CRT) $(LINKERS)
	@$(call PRINT_COLOR, 5, compiling C code file $(SOURCE))
	$(GCC) $(CFLAGS) $(OFLAGS) $(CRT) $(SOURCE) -T $(LINKERS) -o program.elf
	$(GCC) $(CFLAGS) $(DEBUG_FLAG) $(OFLAGS) $(CRT) $(SOURCE) -T $(LINKERS) -o program.debug.elf

disassemble: program.debug.elf
	@$(call PRINT_COLOR, 5, disassembling)
	$(OBJCOPY) $(OBJCFLAGS) program.debug.elf
	$(OBJDUMP) $(OBJFLAGS) program.debug.elf > program.dump
	$(OBJDUMP) $(OBJDFLAGS) program.debug.elf > program.debug.dump
	rm program.debug.elf

hex: program.elf
	$(ELF2HEX) 8 8192 program.elf > program.mem
	@$(call PRINT_COLOR, 6, created memory file program.mem)

.PHONY: assemble compile disassemble hex

# these targets combine the above three commands for compiling either an assembly or C code program
assembly: assemble disassemble hex # for an assembly program
program: compile disassemble hex # for a C code program
.PHONY: program assembly

# this allows you to compile SOURCE for running locally to test stdout or use gdb if you want to
debug_program:
	gcc -lm -g -std=gnu11 -DDEBUG $(SOURCE) -o debug_bin
.PHONY: debug_program

##############################################
# ---- Automatic program.mem Compilation ----
##############################################

# these targets are not part of the legacy compilation system, but I'm adding
# them here because they're a useful addition even if the new system is better.
# The dependencies on the Makefile itself are so that if you update SOURCE in
# the Makefile, it will still recompile program.mem

ifneq ($(filter %.s,$(SOURCE)),)
program.elf program.debug.elf: Makefile
	@$(call PRINT_COLOR, 5, compiling assembly file $(SOURCE))
	$(GCC) $(ASFLAGS) $(SOURCE) -T $(ASLINKERS) -o program.elf
else ifneq ($(filter %.c,$(SOURCE)),)
program.elf program.debug.elf: Makefile
	@$(call PRINT_COLOR, 5, compiling C code file $(SOURCE))
	$(GCC) $(CFLAGS) $(OFLAGS) $(CRT) $(SOURCE) -T $(LINKERS) -o program.elf
endif
.INTERMEDIATE: program.elf

program.mem: program.elf
	$(ELF2HEX) 8 8192 $< > $@
	@$(call PRINT_COLOR, 6, created memory file $@)

# these two commands run program.mem on the compiled executable
sim: simv program.mem
	@$(call PRINT_COLOR, 5, running simv on $(SOURCE))
	./simv | tee program.out
	@$(call PRINT_COLOR, 6, finished running $(SOURCE))
	@$(call PRINT_COLOR, 2, "output is in program.out and writeback.out")

syn: syn_simv program.mem
	@$(call PRINT_COLOR, 5, running syn_simv on $(SOURCE))
	./syn_simv | tee syn_program.out
	@$(call PRINT_COLOR, 6, finished running $(SOURCE))
	@$(call PRINT_COLOR, 2, "output is in syn_program.out and writeback.out")
.PHONY: sim syn

####################
# ---- Cleanup ----
####################

# cleans most build files, but notably does not remove .mem or synthesis files (does remove syn_simv)
# clean does most common cleanup, nuke cleans everything
# other clean_* commands clean only certain files

# removes executables and per-run output files
clean: clean_exe clean_run_files
	@$(call PRINT_COLOR, 6, NOTE: clean is split into multiple commands that you can call separately: clean_exe and clean_run_files)

# removes all extra synthesis files and the entire output directory
# use cautiously, this can cause hours of recompiling
nuke: clean clean_output_dir clean_synth
	@$(call PRINT_COLOR, 6, NOTE: nuke is split into multiple commands that you can call separately: clean_output_dir and clean_synth)
	@$(call PRINT_COLOR, 6, you can also call clean_programs to just delete the .mem and .dump files)

clean_exe:
	@$(call PRINT_COLOR, 3, removing compiled executable files)
	rm -rf *simv *.daidir csrc *.key   # created by simv/syn_simv/vis_simv
	rm -rf vcdplus.vpd vc_hdrs.h       # created by simv/syn_simv/vis_simv
	rm -rf verdi* novas* *fsdb*        # verdi files
	rm -rf dve* inter.vpd DVEfiles     # old DVE debugger

clean_run_files:
	@$(call PRINT_COLOR, 3, removing per-run outputs)
	rm -rf output/*.out output/*.wb output/*.ppln
	rm -rf *.elf *.dump *.mem debug_bin # legacy program.mem compilation files
	rm -rf *.out                        # legacy execution outputs

clean_synth:
	@$(call PRINT_COLOR, 1, removing synthesis files)
	cd synth && rm -rf *.vg *_svsim.sv *.res *.rep *.ddc *.chk *.syn *.out *.db *.svf *.mr *.pvl command.log

clean_output_dir:
	@$(call PRINT_COLOR, 1, removing entire output directory)
	rm -rf output/

# implicit in clean_output_dir, and therefore nuke
clean_programs:
	@$(call PRINT_COLOR, 3, removing program memory files)
	rm -rf output/*.mem
	@$(call PRINT_COLOR, 3, removing dump files)
	rm -rf output/*.dump*

.PHONY: clean nuke clean_%

# :)
