# Typical usage: vivado -mode batch -source create_project.tcl -notrace -tclargs ...

set script_file [ file normalize [ info script ] ]

set project_name default_project
set project_path .
set device_name "noname"

puts "Enter project name:"
set project_name [gets stdin]
puts "Enter project path:"
set project_path [gets stdin]
puts "Enter device name:"
set device_name [gets stdin]


set ::argc [llength $::argv]
  if { $::argc > 0 } {
    for { set i 0 } { $i < $::argc } { incr i } {
      set option [string trim [lindex $::argv $i]]
      switch -regexp -- $option {
        "--project_name" { incr i; set project_name [lindex $::argv $i] }
        "--project_path" { incr i; set project_path [lindex $::argv $i] }
        "--project_part" { incr i; set project_part [lindex $::argv $i] }
        "--device_name" { incr i; set device_name [lindex $::argv $i] }
        "--help" { 
          puts "\nDescription:"
          puts "Create project with predifined features. The script contains commands for set project name, directory and chip.\n"
          puts "Usage: vivado -mode batch -source create_project.tcl -notrace -tclargs \{\<options\>\}\n"
          puts "Options:"
          puts "--project_name <name> Specifies project name."
          puts "--project_path <path> Specifies the directory name to write the new project file into."
          puts "--project_part <chip> Specifies the Xilinx chip to be used for the project."
          puts "--device_name <name>  Specifies name of device with selected chip. Used as default name of constraints fileset and runs."
          puts "--help                Print description of this script.\n"
          puts "Examples:\n"
          puts "Create project in current directory with default parameters:"
          puts "vivado -mode batch -source create_project.tcl -notrace\n"
          puts "Create named project in the specified directory with specified project chip and device name:"
          puts "vivado -mode batch -source create_project.tcl -notrace -tclargs --project_path /home/user/projects --project_name new --project_part xc7z020clg484-1 --device_name zc702\n"
          set ::argv ""
          return -code 3
        }
        default {
          puts "\nError: unknown option '$option' specified, please type 'set argv --help; source -notrace create_project.tcl' for usage info.\n"; set ::argv ""; return -code 3
        }
      }
    }
  }

set ::argv ""

if { [info exists project_part] } {
  create_project -force $project_name [file normalize $project_path/$project_name/project] -part $project_part
} else {
  create_project -force $project_name [file normalize $project_path/$project_name/project]
}

cd [file normalize $project_path/$project_name]

set sources_dir [file normalize ./sources]
set bd_dir [file normalize $sources_dir/bd]
set import_dir [file normalize $sources_dir/import]
set ip_dir [file normalize $sources_dir/ip]
set rtl_dir [file normalize $sources_dir/rtl]
set tb_dir [file normalize $sources_dir/tb]
set xdc_dir [file normalize $sources_dir/xdc]

set utility_dir [file normalize ./utility]

set export_hw_dir [file normalize ./export_hw]
set chipscope_dir [file normalize ./chipscope]

if { !([file exists $sources_dir] && [file isdirectory $sources_dir]) } {
  file mkdir $sources_dir
  if { !([file exists $bd_dir] && [file isdirectory $bd_dir]) } { file mkdir $bd_dir }
  if { !([file exists $import_dir] && [file isdirectory $import_dir]) } { file mkdir $import_dir }
  if { !([file exists $ip_dir] && [file isdirectory $ip_dir]) } { file mkdir $ip_dir }
  if { !([file exists $rtl_dir] && [file isdirectory $rtl_dir]) } { file mkdir $rtl_dir }
  if { !([file exists $tb_dir] && [file isdirectory $tb_dir]) } { file mkdir $tb_dir }
  if { !([file exists $xdc_dir] && [file isdirectory $xdc_dir]) } { file mkdir $xdc_dir }
}

if { !([file exists $utility_dir] && [file isdirectory $utility_dir]) } { file mkdir $utility_dir }

if { !([file exists $export_hw_dir] && [file isdirectory $export_hw_dir]) } { file mkdir $export_hw_dir }
if { !([file exists $chipscope_dir] && [file isdirectory $chipscope_dir]) } { file mkdir $chipscope_dir }

set_property DESIGN_MODE RTL [current_fileset]

set_property target_language Verilog [current_project]

set_param project.enableVHDL2008 1

set_property ip_repo_paths $sources_dir/ip [current_project]

config_ip_cache -disable_cache

set_property coreContainer.enable 1 [current_project]

set_property NAME $device_name [get_filesets [current_fileset -constrset]]

set_property NAME utility [get_filesets -filter {FILESET_TYPE == Utils}]

set syn_label syn_$device_name
set par_label par_$device_name

set_property name $syn_label [get_runs [get_property NAME [current_run -synthesis]]]
set_property name $par_label [get_runs [get_property NAME [current_run]]]

set_property STEPS.WRITE_BITSTREAM.ARGS.BIN_FILE true [get_runs $par_label]

set_property generic {G_MAJOR_VERSION=0 G_MINOR_VERSION=0 G_BUILD_VERSION=0 G_LITER_VERSION=\"\"} [current_fileset]

# Synthesis script
set synthesis_script [file normalize "./utility/synthesis.tcl"]
if { !([file exists $synthesis_script]) } {
  set fileID [open $synthesis_script w]
  puts $fileID {set project_dir [get_property DIRECTORY [current_project]]}
  puts $fileID {set datetime [clock format [clock seconds] -format {%Y %m %d %H %M %S}]}
  puts $fileID {set datecode [expr 0x[format %4.4X [expr 1[lindex $datetime 0] % 10000]][format %2.2X [expr 1[lindex $datetime 1] % 100]][format %2.2X [expr 1[lindex $datetime 2] % 100]]]}
  puts $fileID {set timecode [expr 0x[format %2.2X [expr 1[lindex $datetime 3] % 100]][format %2.2X [expr 1[lindex $datetime 4] % 100]][format %2.2X [expr 1[lindex $datetime 5] % 100]]]}
  puts $fileID {set git_hash [expr 0x[exec git -C "$project_dir/../" log -1 --pretty=%h]]}
  puts $fileID {set_property generic "[get_property generic [current_fileset]] {G_BUILT_DATE=$datecode} {G_BUILT_TIME=$timecode} {G_BUILD_HASH=$git_hash}" [current_fileset]}
  puts $fileID {set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]}
  close $fileID
}

add_files -fileset utility -norecurse $synthesis_script
set_property STEPS.SYNTH_DESIGN.TCL.PRE [get_files $synthesis_script -of [get_fileset utility]] [get_runs $syn_label]

# Bitstream script
set bitstream_script [file normalize "./utility/bitstream.tcl"]
if { !([file exists $bitstream_script]) } {
  set fileID [open $bitstream_script w]
  puts $fileID {set project_dir [get_property DIRECTORY [current_project]]}
  puts $fileID {set project_name [get_property NAME [current_project]]}
  puts $fileID {set run_name [get_property NAME [current_run]]}
  puts $fileID {set run_module [get_property top [current_fileset]]}
  puts $fileID {set ltx_filename [file normalize "$project_dir/$project_name.runs/$run_name/$run_module.ltx"]}
  puts $fileID {if { [file exists $ltx_filename] }}
  puts $fileID {  file copy -force $ltx_filename [file normalize "$project_dir/../chipscope/$run_module.ltx"]}
  puts $fileID {write_hw_platform -fixed -include_bit -force -file [file normalize "$project_dir/../export_hw/$run_module.xsa"]}
  puts $fileID {write_project_tcl -all_properties -force [file normalize "$project_dir/../export_hw/$project_name.tcl"]}
  close $fileID
}

add_files -fileset utility -norecurse $bitstream_script
set_property STEPS.WRITE_BITSTREAM.TCL.POST [get_files $bitstream_script -of [get_fileset utility]] [get_runs $par_label]

if { !([file exists readme.md]) } {
  set fileID [open [file normalize "readme.md"] w]
  puts $fileID "# $project_name "
  close $fileID
}

# Version control
if { !([file exists .git] && [file isdirectory .git]) } { exec git init -b main }

if { !([file exists .gitignore]) } {
  set fileID [open [file normalize ".gitignore"] w]
  puts $fileID {/project/**}
  puts $fileID {!/project/*.wcfg}
  puts $fileID {!/project/import.log}
  close $fileID
}

exec git add .gitignore

exec git add readme.md

exec git add $utility_dir

file copy -force $script_file .

exec git add create_project.tcl
