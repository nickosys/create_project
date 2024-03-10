#!/usr/bin/bash

# Copyright (c) 2024 Nikolay Sysoev

# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:

# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

run_dir=`dirname $0`"/"
cd ${run_dir}
run_dir=`pwd`

project_path=${run_dir} # default path
project_part="xc7k70tfbv676-1" # default chip

msg_c () { echo -e "\033[0;36m""$1""\033[0m"; }

usage () {
	echo -e "Description:"
	echo -e "  Create a project with predefined functions. The script contains commands for set project name, project path and chip."
	echo -e ""
	echo -e "Usage:"
	echo -e "  $1 [options]"
	echo -e ""
	echo -e "Options:"
	echo -e "  -name <name> Specifies project name."
	echo -e "  -path <path> Optional, specifies the directory name to write the new project file into. By default, the project is created in the script directory."
	echo -e "  -chip <chip> Optional, specifies the Xilinx chip to be used for the project."
	echo -e "  -help        Print description of this script."
	echo -e ""
	echo -e "Examples:"
	echo -e ""
	echo -e "Create a project in the current directory with default settings:"
	echo -e "  $1"
	echo -e ""
	echo -e "Create a named project in the specified directory with the specified project chip:"
	echo -e "  $1 -name new -path ./projects/ -chip xc7z020clg484-1"
	echo -e ""
}

while [ -n "$1" ]; do
	case $1 in
		-n | -name )
			shift
			project_name=$1
		;;
		-p | -path )
			shift
			project_path=$1
		;;
		-c | -chip )
            shift
			project_part=$1
		;;
		-h | -help )
			usage $0
			exit 0
		;;
		* )
			echo "What did you mean... Try again."
			usage $0
			exit 1
		;;
	esac
	shift
done
shift

msg_c ""
msg_c "--------------------- Checking command vivado ---------------------"

if ! [ -x "$(command -v vivado)" ]; then
	echo ""
	read -e -p "Enter path to Xilinx settings file (setting64.sh): " xilinx_settings_path
	source ${xilinx_settings_path}
fi

command -v vivado

if [ -z ${project_name+x} ]; then
	echo ""
	read -e -p "Enter project name: " project_name
fi

msg_c ""
msg_c "--------------------- Creating project folders --------------------"

if ! [ -d ${project_name} ]; then mkdir ${project_name}; fi

cp "$(readlink -f $0)" ${project_name}

cd "${project_path}/${project_name}"

chmod -x $0

cfg_dir="${project_path}/${project_name}/cfg"
dbg_dir="${project_path}/${project_name}/dbg"
doc_dir="${project_path}/${project_name}/doc"
out_dir="${project_path}/${project_name}/out"
prj_dir="${project_path}/${project_name}/prj"
src_dir="${project_path}/${project_name}/src"

hdl_dir="${src_dir}/hdl"
lib_dir="${src_dir}/lib"
sim_dir="${src_dir}/sim"
uip_dir="${src_dir}/ip"
xci_dir="${src_dir}/xci"
xdc_dir="${src_dir}/xdc"

if ! [ -d ${src_dir} ]; then mkdir ${src_dir}; fi
if ! [ -d ${hdl_dir} ]; then mkdir ${hdl_dir}; fi
if ! [ -d ${lib_dir} ]; then mkdir ${lib_dir}; fi
if ! [ -d ${sim_dir} ]; then mkdir ${sim_dir}; fi
if ! [ -d ${uip_dir} ]; then mkdir ${uip_dir}; fi
if ! [ -d ${xci_dir} ]; then mkdir ${xci_dir}; fi
if ! [ -d ${xdc_dir} ]; then mkdir ${xdc_dir}; fi
if ! [ -d ${cfg_dir} ]; then mkdir ${cfg_dir}; fi
if ! [ -d ${dbg_dir} ]; then mkdir ${dbg_dir}; fi
if ! [ -d ${doc_dir} ]; then mkdir ${doc_dir}; fi
if ! [ -d ${out_dir} ]; then mkdir ${out_dir}; fi

syn_tcl="synthesis.tcl"
bit_tcl="bitstream.tcl"
prj_tcl="create_project.tcl"
bld_tcl="build.tcl"
bld_scr="build.sh"

msg_c ""
msg_c "--------------------- Creating project scripts --------------------"

cat > ${prj_tcl} << EOF
# Create project script

puts "\n\033\[1;36m------------------------- Creating project ------------------------\033\[0m\n"

create_project ${project_name} ${prj_dir} -part ${project_part}

set_property DESIGN_MODE RTL [current_fileset]
set_property target_language Verilog [current_project]
set_param project.enableVHDL2008 1
config_ip_cache -disable_cache

# set_property ip_repo_paths [file normalize ${uip_dir}] [current_project] # Vivado 2021.1 has some bug with path

set_property STEPS.SYNTH_DESIGN.ARGS.FLATTEN_HIERARCHY none [current_run -synthesis]

set_property generic {G_MAJOR_VERSION=0 G_MINOR_VERSION=0 G_BUILD_VERSION=1 G_LITER_VERSION=\"\"} [current_fileset]

add_files -fileset utils_1 -norecurse [file normalize "${cfg_dir}/${syn_tcl}"]
set_property STEPS.SYNTH_DESIGN.TCL.PRE [get_files [file normalize "${cfg_dir}/${syn_tcl}"] -of [get_fileset utils_1]] [current_run -synthesis]

add_files -fileset utils_1 -norecurse [file normalize "${cfg_dir}/${bit_tcl}"]
set_property STEPS.WRITE_BITSTREAM.TCL.POST [get_files [file normalize "${cfg_dir}/${bit_tcl}"] -of [get_fileset utils_1]] [current_run -implementation]

EOF

cat > ${cfg_dir}/${syn_tcl} << EOF
set prj_dir [get_property DIRECTORY [current_project]]
set datetime [clock format [clock seconds] -format {%Y %m %d %H %M %S}]
set datecode [expr 0x[format %4.4X [expr 1[lindex \$datetime 0] % 10000]][format %2.2X [expr 1[lindex \$datetime 1] % 100]][format %2.2X [expr 1[lindex \$datetime 2] % 100]]]
set timecode [expr 0x[format %2.2X [expr 1[lindex \$datetime 3] % 100]][format %2.2X [expr 1[lindex \$datetime 4] % 100]][format %2.2X [expr 1[lindex \$datetime 5] % 100]]]
set git_hash [expr 0x[exec git -C "\$prj_dir/../" log -1 --pretty=%h]]
set_property generic {[get_property generic [current_fileset]] { G_BUILT_DATE=\$datecode } { G_BUILT_TIME=\$timecode } { G_BUILD_HASH=\$git_hash } } [current_fileset]

EOF

cat > ${cfg_dir}/${bit_tcl} << EOF
# Variables
set hw_name ${project_name}
set prj_dir [get_property XLNX_PROJ_DIR [current_design]]
set run_dir [get_property DIRECTORY [current_run]]
set cur_top [get_property top [current_fileset]]
set cur_dir [pwd]

# Write project tcl
open_project "\$prj_dir/\$hw_name.xpr"
write_project_tcl -force -validate -target_proj_dir prj [file normalize "\$prj_dir/../\$hw_name.tcl"]
close_project

# Write bitstream and xsa
set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]
write_bitstream -force -raw_bitfile -bin_file [file normalize "\$prj_dir/../out/\$hw_name"]
write_hw_platform -force -include_bit -fixed -file [file normalize "\$prj_dir/../out/\$hw_name.xsa"]

# Write debug nets
write_debug_probes -force [file normalize "\$prj_dir/../dbg/\$cur_top.ltx"]

# Write checksum
cd [file normalize "\$prj_dir/../"]
set hash_file [open "./bin.md5" w]
puts \$hash_file [exec md5sum "./out/\$hw_name.bin"]
close \$hash_file
cd \$cur_dir

EOF

cat > ${bld_tcl} << EOF
# Build project Xilinx Vivado script

set threads [expr [exec nproc --all] >> 1]

set execute bitstream

set ::argc [llength $::argv]

if { $::argc > 0 } {
  for { set i 0 } { \$i < $::argc } { incr i } {
    set option [string trim [lindex $::argv \$i]]
    switch -regexp -- \$option {
      "--project" { incr i; set project [lindex $::argv \$i] }
      "--execute" { incr i; set execute [lindex $::argv \$i] }
      "--threads" { incr i; set threads [lindex $::argv \$i] }
      "--help" { 
        puts "\nDescription:"
        puts "  Build project in project mode. The script contains commands for set project, execute command and count of threads."
        puts "\nUsage: vivado -nolog -nojournal -mode batch -source ${bld_tcl} -notrace -tclargs \{\<options\>\}"
        puts "\nOptions:"
        puts "  --project <title> Specifies the project file."
        puts "  --execute <stage> Optional parameter specifies the stage to be execute: [s]ynthesis, [i]mplement or [b]itstream."
        puts "  --threads <count> Optional parameter specifies the count of threads to be used for build the project."
        puts "  --help            Print description of this script."
        puts "\nExamples:"
        puts "\nBuild project in current directory with default parameters:"
        puts "  vivado -nolog -nojournal -mode batch -source ${bld_tcl} -notrace -tclargs --project noname.xpr"
        puts "\nBuild project in current directory with specified execute stage and count of threads:"
        puts "  vivado -nolog -nojournal -mode batch -source ${bld_tcl} -notrace -tclargs --project noname.xpr --execute i --threads 2"
        puts ""
        set ::argv ""
        return -code 3
      }
      default {
        puts "\nError: unknown option '\$option' specified, please type 'vivado -nolog -nojournal -mode batch -source ${bld_tcl} -notrace -tclargs --help' for usage info.\n"; set ::argv ""; return -code 3
      }
    }
  }
}

set ::argv ""

open_project \$project

update_compile_order -fileset [current_fileset]

if { \$execute == {s} || \$execute == {sythesis} || \$execute == {i} || \$execute == {implement} || \$execute == {b} || \$execute == {bitstream} } {
    puts "\n\033\[1;36m----------------------- Launching synthesis -----------------------\033\[0m\n"
    reset_run [current_run -synthesis]
    launch_runs -verbose [current_run -synthesis] -jobs \$threads
    wait_on_run [current_run -synthesis]
} else {
    puts "\n\033\[1;31m------------------- Unknown argument for execute ------------------\033\[0m\n"
    return -code 3
}

if { \$execute == {i} || \$execute == {implement} || \$execute == {b} || \$execute == {bitstream} } {
    puts "\n\033\[1;36m--------------------- Launching place & route ---------------------\033\[0m\n"
    reset_run [current_run -implementation]
    launch_runs -verbose [current_run -implementation] -jobs \$threads
    wait_on_run [current_run -implementation]
}

if { \$execute == {b} || \$execute == {bitstream} } {
    puts "\n\033\[1;36m----------------------- Generating bitstream ----------------------\033\[0m\n"
    launch_runs -verbose [current_run -implementation] -to_step write_bitstream -jobs \$threads
    wait_on_run [current_run -implementation]
} 

EOF

cat > ${bld_scr} << EOF
#!/usr/bin/bash

run_dir=\`dirname \$0\`"/"
cd \${run_dir}
run_dir=\`pwd\`

hw_name=${project_name}

prj_dir=\${run_dir}/prj

threads=\$(((8)>>1))

project="\${prj_dir}/\${hw_name}.xpr"

msg_c () { echo -e "\033[0;36m""\$1""\033[0m"; }

usage () {
	echo "Description:"
	echo "  Re-creating a project from a script then building it: synthesis or implementation with generate bitstream. The script contains commands for set execute command and count of threads."
	echo "\$1 [options]"
	echo -e "  -synthesis		re-creating and synthesis project."
	echo -e "  -implement   	re-creating and implement project."
	echo -e "  -bitstream   	re-creating project and generate bitstream."
	echo -e "  -threads <count>	optional parameter specifies the count of threads to be used for build the project."
	echo -e "  -project <title>	optional parameter specifies the project file for build."
}

while [ -n "\$1" ]; do
	case \$1 in
		-s | -synthesis )
			execute=s
		;;
		-i | -implement )
			execute=i
		;;
		-b | -bitstream )
			execute=b
		;;		
		-t | -threads )
			shift
			threads=\$1
		;;
		-p | -project )
			shift
			project=\$1
		;;
		-h | -help )
			usage \$0
			exit 0
		;;
		* )
			echo "What did you mean... Try again."
			usage \$0
			exit 1
		;;
	esac
	shift
done
shift

if ! [ -f \${run_dir}/xilinx_settings.sh ]; then
	read -e -p "Enter path to Xilinx settings file (setting64.sh): " xilinx_settings_path
	ln -s "\${xilinx_settings_path}" "\${run_dir}/xilinx_settings.sh"
fi

source \${run_dir}/xilinx_settings.sh

highlight () { sed -e 's,INFO:,\x1b[32m&\x1b[0m,; s,WARNING:,\x1b[93m&\x1b[0m,; s,CRITICAL:,\x1b[33m&\x1b[0m,; s,ERROR:,\x1b[31m&\x1b[0m,'; }

if ! [ -f \${project} ]; then
	echo -e ""
    msg_c "----------------- Re-creating project from script -----------------"
    vivado -nolog -nojournal -mode batch -source "\${hw_name}.tcl" -notrace | highlight
fi

if [ "\${execute}" != "" ]; then
	echo -e ""
	msg_c "-------------------- Opening project in Vivado --------------------"
	vivado -nolog -nojournal -mode batch -source "\${run_dir}/${bld_tcl}" -notrace -tclargs --project \${project} --execute \${execute} --threads \${threads} | highlight
fi

EOF

chmod +x ${bld_scr}

msg_c ""
msg_c "------------------------- Executing vivado ------------------------"

vivado -nolog -nojournal -mode batch -source ${prj_tcl} -notrace | sed -e 's,INFO:,\x1b[32m&\x1b[0m,; s,WARNING:,\x1b[93m&\x1b[0m,; s,CRITICAL:,\x1b[33m&\x1b[0m,; s,ERROR:,\x1b[31m&\x1b[0m,'

rm ${prj_tcl}

msg_c ""
msg_c "----------------------- Creating readme file ----------------------"

if ! [ -f readme.md ]; then cat > readme.md << EOF
# ${project_name}  

The project was created by a script $(basename "$0").  
Project structure:  
\`\`\`
  ├── ${bld_scr} - project shell build script for re-creating project and building it.
  ├── ${bld_tcl} - project tcl build script for re-creating, synthesizing and implementing the project.
  ├── $(basename "${cfg_dir}") - directory for project configuration files. 
  │   ├──${syn_tcl} - pre-synthesis run script. Used to set variables with build date, time and git hash.
  │   └──${bit_tcl} - post-bitstream run script.
  ├── $(basename "$0") - file for creating the project.
  ├── $(basename "${dbg_dir}") - project directory for debugging files like.
  ├── $(basename "${doc_dir}") - project documentation directory for file types like with markdown or asciidoc, etc.
  ├── $(basename "${out_dir}") - project output directory. Version control is disabled for this directory.
  ├── $(basename "${prj_dir}") - vivado project directory. Version control is disabled for this directory.
  └── $(basename "${src_dir}") - project sources directory.  
      ├── $(basename "${hdl_dir}") - hardware description language source files: vhdl, verilog and system verilog.   
      ├── $(basename "${lib_dir}") - imported sources.
      ├── $(basename "${sim_dir}") - simulation files.
      ├── $(basename "${xci_dir}") - directory for Xilinx IP core files.
      └── $(basename "${xdc_dir}") - directory for Xilinx constraint files.
\`\`\`
EOF
fi

msg_c ""
msg_c "----- Initializing git repository, adding files and commiting -----"

if ! [ -f .gitignore ]; then cat > .gitignore << EOF
/prj/**
/out/**
EOF
fi

if ! [ -d .git ]; then
	git	init -b main
	git add .gitignore
	git add readme.md
	git add ${cfg_dir}/${syn_tcl}
	git add ${cfg_dir}/${bit_tcl}
	git add ${bld_tcl}
	git add ${bld_scr}
	git add $(basename "$0")
	git commit -am "Initial commit."
fi

msg_c ""
msg_c "------------------------------- Done ------------------------------"
msg_c ""
