cd [file dirname [file normalize [info script]]]

set submission_root "final_project_submission"
set archive_name "${submission_root}.zip"

set report_files {
    lab5/clk_wiz_0_synth_1/clk_wiz_0.vds
    lab5/hdmi_tx_0_synth_1/hdmi_tx_0.vds
    lab5/synth_1/lab5_top.vds
    lab5/impl_1/lab5_top_timing_summary_routed.rpt
}

set memory_modules {
    fake_sample_ram.v
    frequency_rom.v
    ram_1w2r.v
    sine_rom.v
    song_rom.v
    tcgrom.v
}

set missing_files {}

proc copy_if_exists {src dst} {
    global missing_files

    if {[file exists $src]} {
        file mkdir [file dirname $dst]
        file copy -force $src $dst
    } else {
        puts "Warning: File not found - $src"
        lappend missing_files $src
    }
}

proc copy_tree {src dst} {
    global missing_files

    if {![file exists $src]} {
        puts "Warning: File not found - $src"
        lappend missing_files $src
        return
    }

    if {[file isfile $src]} {
        file mkdir [file dirname $dst]
        file copy -force $src $dst
        return
    }

    file mkdir $dst
    foreach child [lsort [glob -nocomplain -directory $src *]] {
        set tail [file tail $child]

        # Skip editor swap files and hidden metadata.
        if {[string match ".*" $tail]} {
            continue
        }

        copy_tree $child [file join $dst $tail]
    }
}

file delete -force $submission_root $archive_name

# Core project artifacts.
copy_if_exists init_project.tcl [file join $submission_root init_project.tcl]
copy_if_exists TIMING_TABLES.md [file join $submission_root TIMING_TABLES.md]
copy_if_exists src/lab5.xdc [file join $submission_root constraints lab5.xdc]
copy_if_exists lab5/impl_1/lab5_top.bit [file join $submission_root bitstream lab5_top.bit]

# Reports needed for grading and timing review.
foreach src $report_files {
    copy_if_exists $src [file join $submission_root reports [file tail $src]]
}

# Main HDL sources and testbenches.
copy_tree [file join src design] [file join $submission_root synthesizable_verilog src_design]
copy_tree [file join hdmi_tx_ip hdl] [file join $submission_root synthesizable_verilog hdmi_tx_ip_hdl]
copy_tree [file join src sim] [file join $submission_root testbenches]
copy_tree [file join hdmi_tx_ip sim] [file join $submission_root testbenches hdmi_tx_ip_sim]
copy_if_exists [file join hdmi_tx_ip component.xml] [file join $submission_root synthesizable_verilog hdmi_tx_ip component.xml]
copy_if_exists [file join hdmi_tx_ip readme.md] [file join $submission_root synthesizable_verilog hdmi_tx_ip readme.md]
copy_tree [file join hdmi_tx_ip xgui] [file join $submission_root synthesizable_verilog hdmi_tx_ip xgui]
copy_if_exists zip_submission.tcl [file join $submission_root zip_submission.tcl]

# A separate memory_modules directory matches the expected submission layout.
foreach module $memory_modules {
    copy_if_exists [file join src design $module] [file join $submission_root memory_modules $module]
}

# Optional PDFs can be dropped into a repo-root required_pdfs/ directory later.
if {[file isdirectory required_pdfs]} {
    copy_tree required_pdfs [file join $submission_root required_pdfs]
}

if {[catch {exec /usr/bin/ditto -c -k --norsrc --keepParent $submission_root $archive_name} result]} {
    puts "Error creating zip archive: $result"
} else {
    puts "\nGenerated $archive_name"
    puts "Submission folder: $submission_root"
    if {[llength $missing_files] > 0} {
        puts "Missing files:"
        foreach file $missing_files {
            puts "  $file"
        }
    } else {
        puts "All expected files were found."
    }
}
