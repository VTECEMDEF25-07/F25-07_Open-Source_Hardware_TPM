# Frequency (User dependent)
set s2f_user_clk0_period 2.0
set s2f_user_clk1_period 2.0

# (C) 2001-2026 Altera Corporation. All rights reserved.
# Your use of Altera Corporation's design tools, logic functions and other 
# software and tools, and its AMPP partner logic functions, and any output 
# files from any of the foregoing (including device programming or simulation 
# files), and any associated documentation or information are expressly subject 
# to the terms and conditions of the Altera Program License Subscription 
# Agreement, Altera IP License Agreement, or other applicable 
# license agreement, including, without limitation, that your use is for the 
# sole purpose of programming logic devices manufactured by Altera and sold by 
# Altera or its authorized distributors.  Please refer to the applicable 
# agreement for further details.


# Frequency 400MHz/2 = 200MHz
set osc_period 5

# Frequency 400MHz
set l4_main_clk_period 2.5

# Frequency 200MHz
set l4_mp_clk_period 5.0

# Frequency 100MHz
set l4_sp_clk_period 10.0

# Fasted possible frequency 400MHz
set cs_at_clk_period 2.5

# Fasted possible frequency 400MHz
set cs_pdbg_clk_period 2.5

# Fasted possible frequency 400MHz
set cs_trace_clk_period 2.5

# Frequency 125MHz
set int_emac_period 8.0

# Frequency 500MHz (doesn't matter)
set pll_c2_clk_period 2.0

# Frequency 100MHz
set l4_sys_free_clk_period 10.0

set apply_false_paths 0

set clocks_to_add_uncertatinty [list]

# ##################
# Internal oscillator clocks
if {[get_collection_size [get_nodes -nowarn sundancemesa_hps_inst~intosc_clk]  ] > 0} { 
    create_clock -name hps_internal_osc -period $osc_period [get_nodes -nowarn sundancemesa_hps_inst~intosc_clk] 
    lappend clocks_to_add_uncertatinty hps_internal_osc
} 

# ##################
# I2C and EMAC clocks
if {[get_collection_size [get_nodes -nowarn sundancemesa_hps_inst~l4_sp_clk]  ] > 0} { 
    create_clock -name l4_sp_clk_src -period $l4_sp_clk_period [get_nodes sundancemesa_hps_inst~l4_sp_clk] 
    lappend clocks_to_add_uncertatinty l4_sp_clk_src

    if {[get_collection_size [get_nodes -nowarn sundancemesa_hps_inst~emac0_gmii_mdc_o]] > 0} {
        create_generated_clock -divide_by 40 -master_clock [get_clocks l4_sp_clk_src] -source [get_nodes sundancemesa_hps_inst~l4_sp_clk] -name emac0_mdc_clk [get_nodes sundancemesa_hps_inst~emac0_gmii_mdc_o]
    }
    if {[get_collection_size [get_nodes -nowarn sundancemesa_hps_inst~emac1_gmii_mdc_o]] > 0} {
        create_generated_clock -divide_by 40 -master_clock [get_clocks l4_sp_clk_src] -source [get_nodes sundancemesa_hps_inst~l4_sp_clk] -name emac1_mdc_clk [get_nodes sundancemesa_hps_inst~emac1_gmii_mdc_o]
    }
    if {[get_collection_size [get_nodes -nowarn sundancemesa_hps_inst~emac2_gmii_mdc_o]] > 0} {
        create_generated_clock -divide_by 40 -master_clock [get_clocks l4_sp_clk_src] -source [get_nodes sundancemesa_hps_inst~l4_sp_clk] -name emac2_mdc_clk [get_nodes sundancemesa_hps_inst~emac2_gmii_mdc_o]
    }
} 

if {[get_collection_size [get_nodes -nowarn sundancemesa_hps_inst~int_emac0_clk]  ] > 0} { 
    create_clock -name int_emac0_clk -period $int_emac_period [get_nodes sundancemesa_hps_inst~int_emac0_clk] 
    lappend clocks_to_add_uncertatinty int_emac0_clk    
}

if {[get_collection_size [get_nodes -nowarn sundancemesa_hps_inst~int_emac1_clk]  ] > 0} { 
    create_clock -name int_emac1_clk -period $int_emac_period [get_nodes sundancemesa_hps_inst~int_emac1_clk] 
    lappend clocks_to_add_uncertatinty int_emac1_clk    
}

if {[get_collection_size [get_nodes -nowarn sundancemesa_hps_inst~int_emac2_clk]  ] > 0} { 
    create_clock -name int_emac2_clk -period $int_emac_period [get_nodes sundancemesa_hps_inst~int_emac2_clk] 
    lappend clocks_to_add_uncertatinty int_emac2_clk
}

# ##################
# User clocks
if {[get_collection_size [get_pins -nowarn sundancemesa_hps_inst|s2f_user_clk0_hio]  ] > 0} { 
    create_clock -add -name h2f_user0_clk_src -period $s2f_user_clk0_period [get_pins sundancemesa_hps_inst|s2f_user_clk0_hio] 
    lappend clocks_to_add_uncertatinty h2f_user0_clk_src    
} 
if {[get_collection_size [get_pins -nowarn sundancemesa_hps_inst|s2f_user_clk1_hio]  ] > 0} { 
    create_clock -add -name h2f_user1_clk_src -period $s2f_user_clk1_period [get_pins sundancemesa_hps_inst|s2f_user_clk1_hio] 
    lappend clocks_to_add_uncertatinty h2f_user1_clk_src        
} 

# ##################
# Other common clocks
if {[get_collection_size [get_nodes -nowarn sundancemesa_hps_inst~l4_main_clk]  ] > 0} { 
    create_clock -name l4_main_clk_src -period $l4_main_clk_period [get_nodes -nowarn sundancemesa_hps_inst~l4_main_clk] 
    lappend clocks_to_add_uncertatinty l4_main_clk_src            
} 
if {[get_collection_size [get_nodes -nowarn sundancemesa_hps_inst~l4_mp_clk]  ] > 0} { 
    create_clock -name l4_mp_clk_src -period $l4_mp_clk_period [get_nodes -nowarn sundancemesa_hps_inst~l4_mp_clk] 
    lappend clocks_to_add_uncertatinty l4_mp_clk_src                
} 

# ##################
# Other clocks
if {[get_collection_size [get_nodes -nowarn sundancemesa_hps_inst~cs_at_clk]  ] > 0} { 
    create_clock -name cs_at_clk -period $cs_at_clk_period [get_nodes -nowarn sundancemesa_hps_inst~cs_at_clk] 
    lappend clocks_to_add_uncertatinty cs_at_clk                    
} 

if {[get_collection_size [get_nodes -nowarn sundancemesa_hps_inst~cs_pdbg_clk]  ] > 0} { 
    create_clock -name cs_pdbg_clk -period $cs_pdbg_clk_period [get_nodes -nowarn sundancemesa_hps_inst~cs_pdbg_clk] 
    lappend clocks_to_add_uncertatinty cs_pdbg_clk                        
} 

if {[get_collection_size [get_nodes -nowarn sundancemesa_hps_inst~cs_trace_clk]  ] > 0} { 
    create_clock -name cs_trace_clk_src -period $cs_trace_clk_period [get_nodes -nowarn sundancemesa_hps_inst~cs_trace_clk] 
    lappend clocks_to_add_uncertatinty cs_trace_clk_src                            
    if {[get_collection_size [get_pins -nowarn sundancemesa_hps_inst|tpiu_trace_clk_hio]] > 0} {
        create_generated_clock -divide_by 2 -master_clock [get_clocks cs_trace_clk_src] -source [get_nodes sundancemesa_hps_inst~cs_trace_clk] -name cs_trace_clk [get_pins sundancemesa_hps_inst|tpiu_trace_clk_hio]
    } 
}

# fabric tpiu_trace_clkin is always tied off if no output clock port used
if {[get_collection_size [get_pins -nowarn sundancemesa_hps_inst|tpiu_trace_clk_hio]] == 0} {
    # Create virtual clock constraint to avoid warning but set_false_path so resource are not wasted analyzing
    create_clock -name fpga_tpiu_clkin -period $cs_trace_clk_period [get_registers sundancemesa_hps_inst~tpiu_trace_core_reg]
    set_false_path -from [get_clocks fpga_tpiu_clkin]
}

if {[get_collection_size [get_nodes -nowarn sundancemesa_hps_inst~l4_sys_free_clk]  ] > 0} { 
    create_clock -name l4_sys_free_clk -period $l4_sys_free_clk_period [get_nodes -nowarn sundancemesa_hps_inst~l4_sys_free_clk] 
} 


if {[get_collection_size [get_nodes -nowarn sundancemesa_hps_inst~pll_main_c2]  ] > 0} { 
    create_clock -name hps_pll_c2_clk_src -period $pll_c2_clk_period [get_nodes -nowarn sundancemesa_hps_inst~pll_main_c2] 
    lappend clocks_to_add_uncertatinty hps_pll_c2_clk_src                                
    if {[get_collection_size [get_nodes -nowarn sundancemesa_hps_inst~pll_main_c2.reg]] > 0} {
        create_generated_clock -divide_by 1 -master_clock [get_clocks hps_pll_c2_clk_src] -source [get_nodes sundancemesa_hps_inst~pll_main_c2] -name hps_pll_c2_clk [get_nodes sundancemesa_hps_inst~pll_main_c2.reg]
        disable_min_pulse_width [get_keepers sundancemesa_hps_inst~pll_main_c2.reg]
    }    
} 

foreach clock_name $clocks_to_add_uncertatinty {
    set_clock_uncertainty -to [get_clocks $clock_name] 0.05
    set_clock_uncertainty -from [get_clocks $clock_name] 0.05
}

if {$apply_false_paths} {
    if {[get_collection_size [get_pins -nowarn -compatibility_mode  sundancemesa_hps_inst|f2s*irq*]  ] > 0} { 
        set_false_path -through [get_pins -compatibility_mode  sundancemesa_hps_inst|f2s*irq*] -to [get_registers *clk*.reg]  
    } 
    if {[get_collection_size [get_pins -nowarn -compatibility_mode  sundancemesa_hps_inst|s2f*irq*]  ] > 0} { 
        set_false_path -through [get_pins -nowarn -compatibility_mode  sundancemesa_hps_inst|s2f*irq*] -from [get_registers *clk*.reg]  
    } 
    if {[get_collection_size [get_pins -nowarn -compatibility_mode  sundancemesa_hps_inst|dbgapbdisable]  ] > 0} { 
        set_false_path -through [get_pins -compatibility_mode  sundancemesa_hps_inst|dbgapbdisable] -to [get_registers *clk*.reg]  
    }
    if {[get_collection_size [get_pins -nowarn -compatibility_mode  sundancemesa_hps_inst|fpga_ctitrig*]  ] > 0} { 
        set_false_path -through [get_pins -compatibility_mode  sundancemesa_hps_inst|fpga_ctitrig*] -to [get_registers *clk*.reg]  
    } 
    if {[get_collection_size [get_pins -nowarn -compatibility_mode  sundancemesa_hps_inst|fpga_ctitrig*]  ] > 0} { 
        set_false_path -through [get_pins -compatibility_mode  sundancemesa_hps_inst|fpga_ctitrig*] -from [get_registers *clk*.reg]  
    }     
    if {[get_collection_size [get_pins -nowarn -compatibility_mode  sundancemesa_hps_inst|*dma*]  ] > 0} { 
        set_false_path -through [get_pins -compatibility_mode  sundancemesa_hps_inst|*dma*] -to [get_registers *clk*.reg]  
    } 
    if {[get_collection_size [get_pins -nowarn -compatibility_mode  sundancemesa_hps_inst|*dma*]  ] > 0} { 
        set_false_path -through [get_pins -compatibility_mode  sundancemesa_hps_inst|*dma*] -from [get_registers *clk*.reg]  
    } 
    if {[get_collection_size [get_pins -nowarn -compatibility_mode  sundancemesa_hps_inst|emac*rst_clk*]  ] > 0} { 
        set_false_path -through [get_pins -compatibility_mode  sundancemesa_hps_inst|emac*rst_clk*] -from [get_registers *clk*.reg]  
    } 
    if {[get_collection_size [get_pins -nowarn -compatibility_mode  sundancemesa_hps_inst|emac*_phy_crs_i]  ] > 0} { 
        set_false_path -through [get_pins -compatibility_mode  sundancemesa_hps_inst|emac*_phy_crs_i] -to [get_registers *clk*.reg]  
    } 
    if {[get_collection_size [get_pins -nowarn -compatibility_mode  sundancemesa_hps_inst|emac*_phy_col_i]  ] > 0} { 
        set_false_path -through [get_pins -compatibility_mode  sundancemesa_hps_inst|emac*_phy_col_i] -to [get_registers *clk*.reg]  
    }    
    if {[get_collection_size [get_pins -nowarn -compatibility_mode  sundancemesa_hps_inst|*uart*]  ] > 0} { 
        set_false_path -through [get_pins -compatibility_mode  sundancemesa_hps_inst|*uart*] -to [get_registers *clk*.reg]  
    } 
    if {[get_collection_size [get_pins -nowarn -compatibility_mode  sundancemesa_hps_inst|*uart*]  ] > 0} { 
        set_false_path -through [get_pins -compatibility_mode  sundancemesa_hps_inst|*uart*] -from [get_registers *clk*.reg]  
    } 
    if {[get_collection_size [get_pins -nowarn -compatibility_mode sundancemesa_hps_inst|f2s_gp*]  ] > 0} { 
        set_false_path -through [get_pins -compatibility_mode  sundancemesa_hps_inst|f2s_gp*] -to [get_registers *clk*.reg]  
    } 
    if {[get_collection_size [get_pins -nowarn -compatibility_mode sundancemesa_hps_inst|s2f_gp*]  ] > 0} { 
        set_false_path -through [get_pins -compatibility_mode sundancemesa_hps_inst|s2f_gp*] -from [get_registers *clk*.reg]  
    } 
    if {[get_collection_size [get_pins -nowarn -compatibility_mode sundancemesa_hps_inst|cs_hwevents_fpga*]  ] > 0} { 
        set_false_path -through [get_pins -compatibility_mode  sundancemesa_hps_inst|cs_hwevents_fpga*] -to [get_registers *clk*.reg]  
    }
    if {[get_collection_size [get_pins -nowarn -compatibility_mode sundancemesa_hps_inst|cs_hwevents_fpga*]  ] > 0} { 
        set_false_path -through [get_pins -compatibility_mode sundancemesa_hps_inst|cs_hwevents_fpga*] -from [get_registers *clk*.reg]  
    }
    if {[get_collection_size [get_pins -nowarn -compatibility_mode sundancemesa_hps_inst|emac*_ptp_aux_ts_trig_i]  ] > 0} { 
        set_false_path -through [get_pins -compatibility_mode  sundancemesa_hps_inst|emac*_ptp_aux_ts_trig_i] -to [get_registers *clk*.reg]  
    }    
    if {[get_collection_size [get_pins -nowarn -compatibility_mode  sundancemesa_hps_inst|f2s_pending_rst_ack]  ] > 0} { 
        set_false_path -through [get_pins -compatibility_mode  sundancemesa_hps_inst|f2s_pending_rst_ack] -to [get_registers *clk*.reg]  
    }      
    if {[get_collection_size [get_pins -nowarn -compatibility_mode  sundancemesa_hps_inst|s2f_pending_rst_req]  ] > 0} { 
        set_false_path -through [get_pins -compatibility_mode  sundancemesa_hps_inst|s2f_pending_rst_req] -from [get_registers *clk*.reg]  
    }         
} 
