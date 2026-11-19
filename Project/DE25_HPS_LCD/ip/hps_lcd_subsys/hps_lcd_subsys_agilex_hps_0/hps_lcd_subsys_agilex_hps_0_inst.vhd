	component hps_lcd_subsys_agilex_hps_0 is
		port (
			h2f_reset_reset            : out   std_logic;                                        -- reset
			lwhps2fpga_axi_clock_clk   : in    std_logic                     := 'X';             -- clk
			lwhps2fpga_axi_reset_reset : in    std_logic                     := 'X';             -- reset
			lwhps2fpga_awid            : out   std_logic_vector(3 downto 0);                     -- awid
			lwhps2fpga_awaddr          : out   std_logic_vector(28 downto 0);                    -- awaddr
			lwhps2fpga_awlen           : out   std_logic_vector(7 downto 0);                     -- awlen
			lwhps2fpga_awsize          : out   std_logic_vector(2 downto 0);                     -- awsize
			lwhps2fpga_awburst         : out   std_logic_vector(1 downto 0);                     -- awburst
			lwhps2fpga_awlock          : out   std_logic;                                        -- awlock
			lwhps2fpga_awcache         : out   std_logic_vector(3 downto 0);                     -- awcache
			lwhps2fpga_awprot          : out   std_logic_vector(2 downto 0);                     -- awprot
			lwhps2fpga_awvalid         : out   std_logic;                                        -- awvalid
			lwhps2fpga_awready         : in    std_logic                     := 'X';             -- awready
			lwhps2fpga_wdata           : out   std_logic_vector(31 downto 0);                    -- wdata
			lwhps2fpga_wstrb           : out   std_logic_vector(3 downto 0);                     -- wstrb
			lwhps2fpga_wlast           : out   std_logic;                                        -- wlast
			lwhps2fpga_wvalid          : out   std_logic;                                        -- wvalid
			lwhps2fpga_wready          : in    std_logic                     := 'X';             -- wready
			lwhps2fpga_bid             : in    std_logic_vector(3 downto 0)  := (others => 'X'); -- bid
			lwhps2fpga_bresp           : in    std_logic_vector(1 downto 0)  := (others => 'X'); -- bresp
			lwhps2fpga_bvalid          : in    std_logic                     := 'X';             -- bvalid
			lwhps2fpga_bready          : out   std_logic;                                        -- bready
			lwhps2fpga_arid            : out   std_logic_vector(3 downto 0);                     -- arid
			lwhps2fpga_araddr          : out   std_logic_vector(28 downto 0);                    -- araddr
			lwhps2fpga_arlen           : out   std_logic_vector(7 downto 0);                     -- arlen
			lwhps2fpga_arsize          : out   std_logic_vector(2 downto 0);                     -- arsize
			lwhps2fpga_arburst         : out   std_logic_vector(1 downto 0);                     -- arburst
			lwhps2fpga_arlock          : out   std_logic;                                        -- arlock
			lwhps2fpga_arcache         : out   std_logic_vector(3 downto 0);                     -- arcache
			lwhps2fpga_arprot          : out   std_logic_vector(2 downto 0);                     -- arprot
			lwhps2fpga_arvalid         : out   std_logic;                                        -- arvalid
			lwhps2fpga_arready         : in    std_logic                     := 'X';             -- arready
			lwhps2fpga_rid             : in    std_logic_vector(3 downto 0)  := (others => 'X'); -- rid
			lwhps2fpga_rdata           : in    std_logic_vector(31 downto 0) := (others => 'X'); -- rdata
			lwhps2fpga_rresp           : in    std_logic_vector(1 downto 0)  := (others => 'X'); -- rresp
			lwhps2fpga_rlast           : in    std_logic                     := 'X';             -- rlast
			lwhps2fpga_rvalid          : in    std_logic                     := 'X';             -- rvalid
			lwhps2fpga_rready          : out   std_logic;                                        -- rready
			h2f_cold_reset_reset_n     : out   std_logic;                                        -- reset_n
			hps_io_hps_osc_clk         : in    std_logic                     := 'X';             -- hps_osc_clk
			hps_io_spim0_clk           : out   std_logic;                                        -- spim0_clk
			hps_io_spim0_mosi          : out   std_logic;                                        -- spim0_mosi
			hps_io_spim0_ss0_n         : out   std_logic;                                        -- spim0_ss0_n
			hps_io_uart1_tx            : out   std_logic;                                        -- uart1_tx
			hps_io_uart1_rx            : in    std_logic                     := 'X';             -- uart1_rx
			hps_io_gpio34              : inout std_logic                     := 'X';             -- gpio34
			hps_io_gpio35              : inout std_logic                     := 'X';             -- gpio35
			hps_io_gpio42              : inout std_logic                     := 'X'              -- gpio42
		);
	end component hps_lcd_subsys_agilex_hps_0;

	u0 : component hps_lcd_subsys_agilex_hps_0
		port map (
			h2f_reset_reset            => CONNECTED_TO_h2f_reset_reset,            --            h2f_reset.reset
			lwhps2fpga_axi_clock_clk   => CONNECTED_TO_lwhps2fpga_axi_clock_clk,   -- lwhps2fpga_axi_clock.clk
			lwhps2fpga_axi_reset_reset => CONNECTED_TO_lwhps2fpga_axi_reset_reset, -- lwhps2fpga_axi_reset.reset
			lwhps2fpga_awid            => CONNECTED_TO_lwhps2fpga_awid,            --           lwhps2fpga.awid
			lwhps2fpga_awaddr          => CONNECTED_TO_lwhps2fpga_awaddr,          --                     .awaddr
			lwhps2fpga_awlen           => CONNECTED_TO_lwhps2fpga_awlen,           --                     .awlen
			lwhps2fpga_awsize          => CONNECTED_TO_lwhps2fpga_awsize,          --                     .awsize
			lwhps2fpga_awburst         => CONNECTED_TO_lwhps2fpga_awburst,         --                     .awburst
			lwhps2fpga_awlock          => CONNECTED_TO_lwhps2fpga_awlock,          --                     .awlock
			lwhps2fpga_awcache         => CONNECTED_TO_lwhps2fpga_awcache,         --                     .awcache
			lwhps2fpga_awprot          => CONNECTED_TO_lwhps2fpga_awprot,          --                     .awprot
			lwhps2fpga_awvalid         => CONNECTED_TO_lwhps2fpga_awvalid,         --                     .awvalid
			lwhps2fpga_awready         => CONNECTED_TO_lwhps2fpga_awready,         --                     .awready
			lwhps2fpga_wdata           => CONNECTED_TO_lwhps2fpga_wdata,           --                     .wdata
			lwhps2fpga_wstrb           => CONNECTED_TO_lwhps2fpga_wstrb,           --                     .wstrb
			lwhps2fpga_wlast           => CONNECTED_TO_lwhps2fpga_wlast,           --                     .wlast
			lwhps2fpga_wvalid          => CONNECTED_TO_lwhps2fpga_wvalid,          --                     .wvalid
			lwhps2fpga_wready          => CONNECTED_TO_lwhps2fpga_wready,          --                     .wready
			lwhps2fpga_bid             => CONNECTED_TO_lwhps2fpga_bid,             --                     .bid
			lwhps2fpga_bresp           => CONNECTED_TO_lwhps2fpga_bresp,           --                     .bresp
			lwhps2fpga_bvalid          => CONNECTED_TO_lwhps2fpga_bvalid,          --                     .bvalid
			lwhps2fpga_bready          => CONNECTED_TO_lwhps2fpga_bready,          --                     .bready
			lwhps2fpga_arid            => CONNECTED_TO_lwhps2fpga_arid,            --                     .arid
			lwhps2fpga_araddr          => CONNECTED_TO_lwhps2fpga_araddr,          --                     .araddr
			lwhps2fpga_arlen           => CONNECTED_TO_lwhps2fpga_arlen,           --                     .arlen
			lwhps2fpga_arsize          => CONNECTED_TO_lwhps2fpga_arsize,          --                     .arsize
			lwhps2fpga_arburst         => CONNECTED_TO_lwhps2fpga_arburst,         --                     .arburst
			lwhps2fpga_arlock          => CONNECTED_TO_lwhps2fpga_arlock,          --                     .arlock
			lwhps2fpga_arcache         => CONNECTED_TO_lwhps2fpga_arcache,         --                     .arcache
			lwhps2fpga_arprot          => CONNECTED_TO_lwhps2fpga_arprot,          --                     .arprot
			lwhps2fpga_arvalid         => CONNECTED_TO_lwhps2fpga_arvalid,         --                     .arvalid
			lwhps2fpga_arready         => CONNECTED_TO_lwhps2fpga_arready,         --                     .arready
			lwhps2fpga_rid             => CONNECTED_TO_lwhps2fpga_rid,             --                     .rid
			lwhps2fpga_rdata           => CONNECTED_TO_lwhps2fpga_rdata,           --                     .rdata
			lwhps2fpga_rresp           => CONNECTED_TO_lwhps2fpga_rresp,           --                     .rresp
			lwhps2fpga_rlast           => CONNECTED_TO_lwhps2fpga_rlast,           --                     .rlast
			lwhps2fpga_rvalid          => CONNECTED_TO_lwhps2fpga_rvalid,          --                     .rvalid
			lwhps2fpga_rready          => CONNECTED_TO_lwhps2fpga_rready,          --                     .rready
			h2f_cold_reset_reset_n     => CONNECTED_TO_h2f_cold_reset_reset_n,     --       h2f_cold_reset.reset_n
			hps_io_hps_osc_clk         => CONNECTED_TO_hps_io_hps_osc_clk,         --               hps_io.hps_osc_clk
			hps_io_spim0_clk           => CONNECTED_TO_hps_io_spim0_clk,           --                     .spim0_clk
			hps_io_spim0_mosi          => CONNECTED_TO_hps_io_spim0_mosi,          --                     .spim0_mosi
			hps_io_spim0_ss0_n         => CONNECTED_TO_hps_io_spim0_ss0_n,         --                     .spim0_ss0_n
			hps_io_uart1_tx            => CONNECTED_TO_hps_io_uart1_tx,            --                     .uart1_tx
			hps_io_uart1_rx            => CONNECTED_TO_hps_io_uart1_rx,            --                     .uart1_rx
			hps_io_gpio34              => CONNECTED_TO_hps_io_gpio34,              --                     .gpio34
			hps_io_gpio35              => CONNECTED_TO_hps_io_gpio35,              --                     .gpio35
			hps_io_gpio42              => CONNECTED_TO_hps_io_gpio42               --                     .gpio42
		);

