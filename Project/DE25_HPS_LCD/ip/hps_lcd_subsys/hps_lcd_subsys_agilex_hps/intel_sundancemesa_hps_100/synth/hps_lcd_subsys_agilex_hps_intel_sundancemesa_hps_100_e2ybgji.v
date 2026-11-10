// (C) 2001-2026 Altera Corporation. All rights reserved.
// Your use of Altera Corporation's design tools, logic functions and other 
// software and tools, and its AMPP partner logic functions, and any output 
// files from any of the foregoing (including device programming or simulation 
// files), and any associated documentation or information are expressly subject 
// to the terms and conditions of the Altera Program License Subscription 
// Agreement, Altera IP License Agreement, or other applicable 
// license agreement, including, without limitation, that your use is for the 
// sole purpose of programming logic devices manufactured by Altera and sold by 
// Altera or its authorized distributors.  Please refer to the applicable 
// agreement for further details.



module hps_lcd_subsys_agilex_hps_intel_sundancemesa_hps_100_e2ybgji(
  output wire [0 : 0 ] h2f_reset
 ,input wire [0 : 0 ] hps_osc_clk
 ,output wire [0 : 0 ] spim0_clk
 ,output wire [0 : 0 ] spim0_mosi
 ,output wire [0 : 0 ] spim0_ss0_n
 ,output wire [0 : 0 ] uart1_io_tx
 ,input wire [0 : 0 ] uart1_io_rx
 ,inout wire [0 : 0 ] gpio34
 ,inout wire [0 : 0 ] gpio35
 ,inout wire [0 : 0 ] gpio42
);

// assignments for top ports



wire [0:0] hps_osc_clk_ibuf_o;
tennm_ph2_io_ibuf #(
    .buffer_usage("REGULAR"),
    .bus_hold("BUS_HOLD_OFF"),
    .equalization("EQUALIZATION_OFF"),
    .io_standard("IO_STANDARD_IOSTD_OFF"),
    .rzq_id("RZQ_ID_RZQ0"),
    .schmitt_trigger("SCHMITT_TRIGGER_OFF"),
    .termination("TERMINATION_RT_OFF"),
    .toggle_speed("TOGGLE_SPEED_SLOW"),
    .usage_mode("USAGE_MODE_GPIO"),
    .vref("VREF_OFF"),
    .weak_pull_down("WEAK_PULL_DOWN_OFF"),
    .weak_pull_up("WEAK_PULL_UP_OFF")
) hps_hps_osc_clk_ibuf(
    .i(hps_osc_clk),
    .o(hps_osc_clk_ibuf_o)
);



wire [0:0] spim0_mosi_obuf_i;
tennm_ph2_io_obuf #(
    .buffer_usage("REGULAR"),
    .dynamic_pull_up_enabled("false"),
    .equalization("EQUALIZATION_OFF"),
    .io_standard("IO_STANDARD_IOSTD_OFF"),
    .open_drain("OPEN_DRAIN_OFF"),
    .rzq_id("RZQ_ID_RZQ0"),
    .slew_rate("SLEW_RATE_SLOW"),
    .termination("TERMINATION_SERIES_OFF"),
    .toggle_speed("TOGGLE_SPEED_SLOW"),
    .usage_mode("USAGE_MODE_GPIO")
) hps_spim0_mosi_obuf(
    .i(spim0_mosi_obuf_i),
    .o(spim0_mosi),
    .oe(1'b1)
);

wire [0:0] uart1_io_rx_ibuf_o;
tennm_ph2_io_ibuf #(
    .buffer_usage("REGULAR"),
    .bus_hold("BUS_HOLD_OFF"),
    .equalization("EQUALIZATION_OFF"),
    .io_standard("IO_STANDARD_IOSTD_OFF"),
    .rzq_id("RZQ_ID_RZQ0"),
    .schmitt_trigger("SCHMITT_TRIGGER_OFF"),
    .termination("TERMINATION_RT_OFF"),
    .toggle_speed("TOGGLE_SPEED_SLOW"),
    .usage_mode("USAGE_MODE_GPIO"),
    .vref("VREF_OFF"),
    .weak_pull_down("WEAK_PULL_DOWN_OFF"),
    .weak_pull_up("WEAK_PULL_UP_OFF")
) hps_uart1_io_rx_ibuf(
    .i(uart1_io_rx),
    .o(uart1_io_rx_ibuf_o)
);


wire [0:0] gpio42_ibuf_o;
tennm_ph2_io_ibuf #(
    .buffer_usage("REGULAR"),
    .bus_hold("BUS_HOLD_OFF"),
    .equalization("EQUALIZATION_OFF"),
    .io_standard("IO_STANDARD_IOSTD_OFF"),
    .rzq_id("RZQ_ID_RZQ0"),
    .schmitt_trigger("SCHMITT_TRIGGER_OFF"),
    .termination("TERMINATION_RT_OFF"),
    .toggle_speed("TOGGLE_SPEED_SLOW"),
    .usage_mode("USAGE_MODE_GPIO"),
    .vref("VREF_OFF"),
    .weak_pull_down("WEAK_PULL_DOWN_OFF"),
    .weak_pull_up("WEAK_PULL_UP_OFF")
) hps_gpio42_ibuf(
    .i(gpio42),
    .o(gpio42_ibuf_o)
);

wire [0:0] gpio42_obuf_i;
tennm_ph2_io_obuf #(
    .buffer_usage("REGULAR"),
    .dynamic_pull_up_enabled("false"),
    .equalization("EQUALIZATION_OFF"),
    .io_standard("IO_STANDARD_IOSTD_OFF"),
    .open_drain("OPEN_DRAIN_OFF"),
    .rzq_id("RZQ_ID_RZQ0"),
    .slew_rate("SLEW_RATE_SLOW"),
    .termination("TERMINATION_SERIES_OFF"),
    .toggle_speed("TOGGLE_SPEED_SLOW"),
    .usage_mode("USAGE_MODE_GPIO")
) hps_gpio42_obuf(
    .i(gpio42_obuf_i),
    .o(gpio42),
    .oe(1'b1)
);


wire [0:0] spim0_clk_obuf_i;
tennm_ph2_io_obuf #(
    .buffer_usage("REGULAR"),
    .dynamic_pull_up_enabled("false"),
    .equalization("EQUALIZATION_OFF"),
    .io_standard("IO_STANDARD_IOSTD_OFF"),
    .open_drain("OPEN_DRAIN_OFF"),
    .rzq_id("RZQ_ID_RZQ0"),
    .slew_rate("SLEW_RATE_SLOW"),
    .termination("TERMINATION_SERIES_OFF"),
    .toggle_speed("TOGGLE_SPEED_SLOW"),
    .usage_mode("USAGE_MODE_GPIO")
) hps_spim0_clk_obuf(
    .i(spim0_clk_obuf_i),
    .o(spim0_clk),
    .oe(1'b1)
);

wire [0:0] gpio34_ibuf_o;
tennm_ph2_io_ibuf #(
    .buffer_usage("REGULAR"),
    .bus_hold("BUS_HOLD_OFF"),
    .equalization("EQUALIZATION_OFF"),
    .io_standard("IO_STANDARD_IOSTD_OFF"),
    .rzq_id("RZQ_ID_RZQ0"),
    .schmitt_trigger("SCHMITT_TRIGGER_OFF"),
    .termination("TERMINATION_RT_OFF"),
    .toggle_speed("TOGGLE_SPEED_SLOW"),
    .usage_mode("USAGE_MODE_GPIO"),
    .vref("VREF_OFF"),
    .weak_pull_down("WEAK_PULL_DOWN_OFF"),
    .weak_pull_up("WEAK_PULL_UP_OFF")
) hps_gpio34_ibuf(
    .i(gpio34),
    .o(gpio34_ibuf_o)
);

wire [0:0] gpio34_obuf_i;
tennm_ph2_io_obuf #(
    .buffer_usage("REGULAR"),
    .dynamic_pull_up_enabled("false"),
    .equalization("EQUALIZATION_OFF"),
    .io_standard("IO_STANDARD_IOSTD_OFF"),
    .open_drain("OPEN_DRAIN_OFF"),
    .rzq_id("RZQ_ID_RZQ0"),
    .slew_rate("SLEW_RATE_SLOW"),
    .termination("TERMINATION_SERIES_OFF"),
    .toggle_speed("TOGGLE_SPEED_SLOW"),
    .usage_mode("USAGE_MODE_GPIO")
) hps_gpio34_obuf(
    .i(gpio34_obuf_i),
    .o(gpio34),
    .oe(1'b1)
);


wire [0:0] spim0_ss0_n_obuf_i;
tennm_ph2_io_obuf #(
    .buffer_usage("REGULAR"),
    .dynamic_pull_up_enabled("false"),
    .equalization("EQUALIZATION_OFF"),
    .io_standard("IO_STANDARD_IOSTD_OFF"),
    .open_drain("OPEN_DRAIN_OFF"),
    .rzq_id("RZQ_ID_RZQ0"),
    .slew_rate("SLEW_RATE_SLOW"),
    .termination("TERMINATION_SERIES_OFF"),
    .toggle_speed("TOGGLE_SPEED_SLOW"),
    .usage_mode("USAGE_MODE_GPIO")
) hps_spim0_ss0_n_obuf(
    .i(spim0_ss0_n_obuf_i),
    .o(spim0_ss0_n),
    .oe(1'b1)
);


wire [0:0] uart1_io_tx_obuf_i;
tennm_ph2_io_obuf #(
    .buffer_usage("REGULAR"),
    .dynamic_pull_up_enabled("false"),
    .equalization("EQUALIZATION_OFF"),
    .io_standard("IO_STANDARD_IOSTD_OFF"),
    .open_drain("OPEN_DRAIN_OFF"),
    .rzq_id("RZQ_ID_RZQ0"),
    .slew_rate("SLEW_RATE_SLOW"),
    .termination("TERMINATION_SERIES_OFF"),
    .toggle_speed("TOGGLE_SPEED_SLOW"),
    .usage_mode("USAGE_MODE_GPIO")
) hps_uart1_io_tx_obuf(
    .i(uart1_io_tx_obuf_i),
    .o(uart1_io_tx),
    .oe(1'b1)
);

wire [0:0] gpio35_ibuf_o;
tennm_ph2_io_ibuf #(
    .buffer_usage("REGULAR"),
    .bus_hold("BUS_HOLD_OFF"),
    .equalization("EQUALIZATION_OFF"),
    .io_standard("IO_STANDARD_IOSTD_OFF"),
    .rzq_id("RZQ_ID_RZQ0"),
    .schmitt_trigger("SCHMITT_TRIGGER_OFF"),
    .termination("TERMINATION_RT_OFF"),
    .toggle_speed("TOGGLE_SPEED_SLOW"),
    .usage_mode("USAGE_MODE_GPIO"),
    .vref("VREF_OFF"),
    .weak_pull_down("WEAK_PULL_DOWN_OFF"),
    .weak_pull_up("WEAK_PULL_UP_OFF")
) hps_gpio35_ibuf(
    .i(gpio35),
    .o(gpio35_ibuf_o)
);

wire [0:0] gpio35_obuf_i;
tennm_ph2_io_obuf #(
    .buffer_usage("REGULAR"),
    .dynamic_pull_up_enabled("false"),
    .equalization("EQUALIZATION_OFF"),
    .io_standard("IO_STANDARD_IOSTD_OFF"),
    .open_drain("OPEN_DRAIN_OFF"),
    .rzq_id("RZQ_ID_RZQ0"),
    .slew_rate("SLEW_RATE_SLOW"),
    .termination("TERMINATION_SERIES_OFF"),
    .toggle_speed("TOGGLE_SPEED_SLOW"),
    .usage_mode("USAGE_MODE_GPIO")
) hps_gpio35_obuf(
    .i(gpio35_obuf_i),
    .o(gpio35),
    .oe(1'b1)
);



(* preserve *) wire w_tpiu_clkin;

(* preserve *) tennm_lcell_comb #(
    .dont_touch("on"),
    .lut_mask(64'hAAAAAAAAAAAAAAAA) // buffer
  ) tpiu_clkin_lcell (
    .dataa(1'b0)
    ,.combout(w_tpiu_clkin)
);

wire[63:0] unused_bits;
(* preserve *)(* altera_attribute = "-name PRESERVE_FANOUT_FREE_WYSIWYG ON" *) 
tennm_soc_hps #(
.soc_hps_wrapper_powerdown_mode("FALSE")
,.soc_hps_wrapper_hps_a55_core_state("HPS_A55_CORE_STATE_BOTH_ON")
,.soc_hps_wrapper_hps_a76_core_selection("HPS_A76_CORE_SELECTION_DUAL")
,.soc_hps_wrapper_hps_l3_memory_size("HPS_L3_MEMORY_SIZE_1_MB")
,.soc_hps_wrapper_powermode_freq_hz(32'b00011111110010011111100001010000)
,.soc_hps_wrapper_h2f_addr_width(32'b00000000000000000000000000100110)
,.soc_hps_wrapper_h2f_data_width(32'b00000000000000000000000000000000)
,.soc_hps_wrapper_lwh2f_addr_width(32'b00000000000000000000000000011101)
,.soc_hps_wrapper_lwh2f_data_width(32'b00000000000000000000000000000000)
 ) sundancemesa_hps_inst (
  .spim0_miso_i({
     1'h0
  })
 ,.fpga_eventireq({
     1'h0
  })
 ,.emac0_ptp_aux_ts_trig_i({
     1'h0
  })
 ,.lwsoc2fpga_b_resp({
     2'h0
  })
 ,.tpiu_trace_ctl({
     1'h1
  })
 ,.uart1_dsr_n({
     1'h0
  })
 ,.emac0_phy_rxd_i({
     8'h0
  })
 ,.s2f_rst({
     h2f_reset[0:0]
  })
 ,.lwsoc2fpga_aw_ready({
     1'h0
  })
 ,.cs_dbg_fpga_apb_prdata({
     32'h0
  })
 ,.uart1_dcd_n({
     1'h0
  })
 ,.dft_in_core_loopback_en_n({
     1'h1
  })
 ,.lwsoc2fpga_b_id({
     4'h0
  })
 ,.emac1_gmii_mdi_i({
     1'h0
  })
 ,.fpga2soc_emac_timestamp_data({
     64'h0
  })
 ,.fpga2soc_emac_timestamp_clk({
     1'h0
  })
 ,.emac0_phy_rxer_i({
     1'h0
  })
 ,.fpga7_dma_single({
     1'h0
  })
 ,.fpga_atb_atbytes({
     2'h0
  })
 ,.soc2fpga_port_size_config_0({
     1'h1
  })
 ,.soc2fpga_port_size_config_1({
     1'h1
  })
 ,.hps_iob_16_bidir_in({
     uart1_io_rx_ibuf_o
  })
 ,.soc2fpga_b_id({
     4'h0
  })
 ,.i2c_emac0_sda_i({
     1'h0
  })
 ,.fpga_atb_atdata({
     32'h0
  })
 ,.fpga2_dma_single({
     1'h0
  })
 ,.emac1_phy_rxdv_i({
     1'h0
  })
 ,.uart1_cts_n({
     1'h0
  })
 ,.cs_tck_fpga({
     1'h0
  })
 ,.uart1_ri_n({
     1'h0
  })
 ,.emac1_phy_col_i({
     1'h0
  })
 ,.uart0_rx({
     1'h0
  })
 ,.cs_dbg_fpga_apb_pclken({
     1'h0
  })
 ,.cs_hwevents_fpga({
     44'h0
  })
 ,.lwsoc2fpga_ar_ready({
     1'h0
  })
 ,.i2c_emac2_scl_i({
     1'h0
  })
 ,.i2c1_sda_i({
     1'h0
  })
 ,.emac1_phy_crs_i({
     1'h0
  })
 ,.fpga_atb_atvalid({
     1'h0
  })
 ,.uart0_dsr_n({
     1'h0
  })
 ,.soc2fpga_r_last({
     1'h0
  })
 ,.emac1_ptp_aux_ts_trig_i({
     1'h0
  })
 ,.lwsoc2fpga_r_resp({
     2'h0
  })
 ,.lwsoc2fpga_port_size_config_0({
     1'h0
  })
 ,.uart0_dcd_n({
     1'h0
  })
 ,.emac1_phy_rxd_i({
     8'h0
  })
 ,.hps_iob_11_bidir_out({
     gpio34_obuf_i
  })
 ,.fpga5_dma_single({
     1'h0
  })
 ,.lwsoc2fpga_r_id({
     4'h0
  })
 ,.i3c_s_sda_in_a({
     1'h0
  })
 ,.soc2fpga_b_resp({
     2'h0
  })
 ,.fpga0_dma_single({
     1'h0
  })
 ,.hps_iob_15_bidir_out({
     uart1_io_tx_obuf_i
  })
 ,.fpga_atb_atresetn({
     1'h0
  })
 ,.emac1_phy_rxclk_i({
     1'h0
  })
 ,.soc2fpga_r_id({
     4'h0
  })
 ,.uart0_cts_n({
     1'h0
  })
 ,.emac0_phy_txclk_i({
     1'h0
  })
 ,.hps_iob_11_bidir_in({
     gpio34_ibuf_o
  })
 ,.emac2_phy_txclk_i({
     1'h0
  })
 ,.emac2_phy_col_i({
     1'h0
  })
 ,.hps_iob_19_bidir_out({
     gpio42_obuf_i
  })
 ,.hps_iob_20_bidir_out({
     spim0_ss0_n_obuf_i
  })
 ,.i2c0_sda_i({
     1'h0
  })
 ,.i2c_emac1_scl_i({
     1'h0
  })
 ,.soc2fpga_b_valid({
     1'h0
  })
 ,.fpga_eventoack({
     1'h0
  })
 ,.fpga0_dma_req({
     1'h0
  })
 ,.emac2_gmii_mdi_i({
     1'h0
  })
 ,.hps_iob_4_bidir_in({
     hps_osc_clk_ibuf_o
  })
 ,.fpga1_dma_req({
     1'h0
  })
 ,.emac2_phy_crs_i({
     1'h0
  })
 ,.emac1_phy_rxer_i({
     1'h0
  })
 ,.fpga_atb_afready({
     1'h0
  })
 ,.spis0_ss_in_n({
     1'h0
  })
 ,.spis1_mosi_i({
     1'h0
  })
 ,.fpga2_dma_req({
     1'h0
  })
 ,.i3c_m_sda_in_a({
     1'h0
  })
 ,.lwsoc2fpga_b_valid({
     1'h0
  })
 ,.spis1_ss_in_n({
     1'h0
  })
 ,.lwsoc2fpga_clk({
     1'h0
  })
 ,.f2s_gp({
     32'h0
  })
 ,.fpga3_dma_req({
     1'h0
  })
 ,.fpga4_dma_req({
     1'h0
  })
 ,.emac2_phy_rxdv_i({
     1'h0
  })
 ,.uart0_ri_n({
     1'h0
  })
 ,.emac2_ptp_aux_ts_trig_i({
     1'h0
  })
 ,.fpga3_dma_single({
     1'h0
  })
 ,.fpga5_dma_req({
     1'h0
  })
 ,.hps_iob_19_bidir_in({
     gpio42_ibuf_o
  })
 ,.fpga6_dma_req({
     1'h0
  })
 ,.emac2_phy_rxd_i({
     8'h0
  })
 ,.cs_dbg_fpga_apb_pready({
     1'h0
  })
 ,.hps_iob_12_bidir_in({
     gpio35_ibuf_o
  })
 ,.f2s_pending_rst_ack({
     1'h0
  })
 ,.fpga7_dma_req({
     1'h0
  })
 ,.hps_iob_12_bidir_out({
     gpio35_obuf_i
  })
 ,.spis0_mosi_i({
     1'h0
  })
 ,.uart1_rx({
     1'h0
  })
 ,.soc2fpga_r_resp({
     2'h0
  })
 ,.i3c_s_scl_in_a({
     1'h0
  })
 ,.soc2fpga_aw_ready({
     1'h0
  })
 ,.spim0_ss_in_n({
     1'h0
  })
 ,.fpga_atb_atclk({
     1'h0
  })
 ,.lwsoc2fpga_r_data({
     32'h0
  })
 ,.spim1_ss_in_n({
     1'h0
  })
 ,.fpga_ctitrigin({
     8'h0
  })
 ,.cs_tdi_fpga({
     1'h0
  })
 ,.emac0_gmii_mdi_i({
     1'h0
  })
 ,.i2c_emac0_scl_i({
     1'h0
  })
 ,.i2c_emac2_sda_i({
     1'h0
  })
 ,.dbgapbdisable({
     1'h0
  })
 ,.soc2fpga_r_valid({
     1'h0
  })
 ,.cs_dbg_fpga_apb_pslverr({
     1'h0
  })
 ,.hps_iob_21_bidir_out({
     spim0_clk_obuf_i
  })
 ,.fpga6_dma_single({
     1'h0
  })
 ,.soc2fpga_w_ready({
     1'h0
  })
 ,.i2c1_scl_i({
     1'h0
  })
 ,.lwsoc2fpga_r_valid({
     1'h0
  })
 ,.emac0_phy_rxdv_i({
     1'h0
  })
 ,.fpga1_dma_single({
     1'h0
  })
 ,.cs_dbg_fpga_apb_pclk({
     1'h0
  })
 ,.i3c_m_scl_in_a({
     1'h0
  })
 ,.lwsoc2fpga_w_ready({
     1'h0
  })
 ,.fpga_ctitrigoutack({
     8'h0
  })
 ,.soc2fpga_ar_ready({
     1'h0
  })
 ,.fpga_atb_atid({
     7'h0
  })
 ,.emac2_phy_rxer_i({
     1'h0
  })
 ,.emac0_phy_rxclk_i({
     1'h0
  })
 ,.spim1_miso_i({
     1'h0
  })
 ,.emac2_phy_rxclk_i({
     1'h0
  })
 ,.emac0_phy_col_i({
     1'h0
  })
 ,.i2c_emac1_sda_i({
     1'h0
  })
 ,.emac1_phy_txclk_i({
     1'h0
  })
 ,.lwsoc2fpga_r_last({
     1'h0
  })
 ,.fpga4_dma_single({
     1'h0
  })
 ,.emac0_phy_crs_i({
     1'h0
  })
 ,.cs_ntrst_fpga({
     1'h0
  })
 ,.f2s_free_clk({
     1'h0
  })
 ,.soc2fpga_clk({
     1'h0
  })
 ,.cs_tms_fpga({
     1'h0
  })
 ,.emac_ptp_ref_clk({
     1'h0
  })
 ,.hps_iob_22_bidir_out({
     spim0_mosi_obuf_i
  })
 ,.i2c0_scl_i({
     1'h0
  })
 ,.tpiu_trace_clkin(w_tpiu_clkin)
);

endmodule


