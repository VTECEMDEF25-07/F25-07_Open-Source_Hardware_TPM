	component hps_lcd_subsys is
		port (
			hps_io_hps_osc_clk : in    std_logic := 'X'; -- hps_osc_clk
			hps_io_spim0_clk   : out   std_logic;        -- spim0_clk
			hps_io_spim0_mosi  : out   std_logic;        -- spim0_mosi
			hps_io_spim0_ss0_n : out   std_logic;        -- spim0_ss0_n
			hps_io_uart1_tx    : out   std_logic;        -- uart1_tx
			hps_io_uart1_rx    : in    std_logic := 'X'; -- uart1_rx
			hps_io_gpio34      : inout std_logic := 'X'; -- gpio34
			hps_io_gpio35      : inout std_logic := 'X'; -- gpio35
			hps_io_gpio42      : inout std_logic := 'X'  -- gpio42
		);
	end component hps_lcd_subsys;

	u0 : component hps_lcd_subsys
		port map (
			hps_io_hps_osc_clk => CONNECTED_TO_hps_io_hps_osc_clk, -- hps_io.hps_osc_clk
			hps_io_spim0_clk   => CONNECTED_TO_hps_io_spim0_clk,   --       .spim0_clk
			hps_io_spim0_mosi  => CONNECTED_TO_hps_io_spim0_mosi,  --       .spim0_mosi
			hps_io_spim0_ss0_n => CONNECTED_TO_hps_io_spim0_ss0_n, --       .spim0_ss0_n
			hps_io_uart1_tx    => CONNECTED_TO_hps_io_uart1_tx,    --       .uart1_tx
			hps_io_uart1_rx    => CONNECTED_TO_hps_io_uart1_rx,    --       .uart1_rx
			hps_io_gpio34      => CONNECTED_TO_hps_io_gpio34,      --       .gpio34
			hps_io_gpio35      => CONNECTED_TO_hps_io_gpio35,      --       .gpio35
			hps_io_gpio42      => CONNECTED_TO_hps_io_gpio42       --       .gpio42
		);

