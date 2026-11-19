	component hps_lcd_subsys is
		port (
			hps_io_hps_osc_clk    : in    std_logic                     := 'X';             -- hps_osc_clk
			hps_io_spim0_clk      : out   std_logic;                                        -- spim0_clk
			hps_io_spim0_mosi     : out   std_logic;                                        -- spim0_mosi
			hps_io_spim0_ss0_n    : out   std_logic;                                        -- spim0_ss0_n
			hps_io_uart1_tx       : out   std_logic;                                        -- uart1_tx
			hps_io_uart1_rx       : in    std_logic                     := 'X';             -- uart1_rx
			hps_io_gpio34         : inout std_logic                     := 'X';             -- gpio34
			hps_io_gpio35         : inout std_logic                     := 'X';             -- gpio35
			hps_io_gpio42         : inout std_logic                     := 'X';             -- gpio42
			display_waitrequest   : in    std_logic                     := 'X';             -- waitrequest
			display_readdata      : in    std_logic_vector(31 downto 0) := (others => 'X'); -- readdata
			display_readdatavalid : in    std_logic                     := 'X';             -- readdatavalid
			display_burstcount    : out   std_logic_vector(0 downto 0);                     -- burstcount
			display_writedata     : out   std_logic_vector(31 downto 0);                    -- writedata
			display_address       : out   std_logic_vector(7 downto 0);                     -- address
			display_write         : out   std_logic;                                        -- write
			display_read          : out   std_logic;                                        -- read
			display_byteenable    : out   std_logic_vector(3 downto 0);                     -- byteenable
			display_debugaccess   : out   std_logic;                                        -- debugaccess
			fabric_clock_clk      : in    std_logic                     := 'X';             -- clk
			fabric_reset_reset_n  : in    std_logic                     := 'X'              -- reset_n
		);
	end component hps_lcd_subsys;

	u0 : component hps_lcd_subsys
		port map (
			hps_io_hps_osc_clk    => CONNECTED_TO_hps_io_hps_osc_clk,    --       hps_io.hps_osc_clk
			hps_io_spim0_clk      => CONNECTED_TO_hps_io_spim0_clk,      --             .spim0_clk
			hps_io_spim0_mosi     => CONNECTED_TO_hps_io_spim0_mosi,     --             .spim0_mosi
			hps_io_spim0_ss0_n    => CONNECTED_TO_hps_io_spim0_ss0_n,    --             .spim0_ss0_n
			hps_io_uart1_tx       => CONNECTED_TO_hps_io_uart1_tx,       --             .uart1_tx
			hps_io_uart1_rx       => CONNECTED_TO_hps_io_uart1_rx,       --             .uart1_rx
			hps_io_gpio34         => CONNECTED_TO_hps_io_gpio34,         --             .gpio34
			hps_io_gpio35         => CONNECTED_TO_hps_io_gpio35,         --             .gpio35
			hps_io_gpio42         => CONNECTED_TO_hps_io_gpio42,         --             .gpio42
			display_waitrequest   => CONNECTED_TO_display_waitrequest,   --      display.waitrequest
			display_readdata      => CONNECTED_TO_display_readdata,      --             .readdata
			display_readdatavalid => CONNECTED_TO_display_readdatavalid, --             .readdatavalid
			display_burstcount    => CONNECTED_TO_display_burstcount,    --             .burstcount
			display_writedata     => CONNECTED_TO_display_writedata,     --             .writedata
			display_address       => CONNECTED_TO_display_address,       --             .address
			display_write         => CONNECTED_TO_display_write,         --             .write
			display_read          => CONNECTED_TO_display_read,          --             .read
			display_byteenable    => CONNECTED_TO_display_byteenable,    --             .byteenable
			display_debugaccess   => CONNECTED_TO_display_debugaccess,   --             .debugaccess
			fabric_clock_clk      => CONNECTED_TO_fabric_clock_clk,      -- fabric_clock.clk
			fabric_reset_reset_n  => CONNECTED_TO_fabric_reset_reset_n   -- fabric_reset.reset_n
		);

