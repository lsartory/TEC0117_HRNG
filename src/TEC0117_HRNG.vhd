---- TEC0117_HRNG.vhd
 --
 -- Author: L. Sartory
 -- Creation: 2022-19-02
----

--------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

--------------------------------------------------

entity TEC0117_HRNG is
    port (
        CLK_100MHz : in  std_logic;
        USER_BTN   : in  std_logic;
        LED        : out std_logic_vector(8 downto 1);

        UART_RX    : in  std_logic;
        UART_TX    : out std_logic
    );
end entity;

--------------------------------------------------

architecture TEC0117_HRNG_arch of TEC0117_HRNG is
    signal pll_clk : std_logic := '0';
    signal clrn    : std_logic := '1';

    signal rng_data  : std_logic_vector(7 downto 0) := (others => '0');
    signal rng_valid : std_logic := '0';

    signal rx_data : std_logic_vector(7 downto 0) := (others => '0');
    signal rx_done : std_logic := '0';

    signal display_pulse : std_logic := '0';
    signal display_data  : std_logic_vector(7 downto 0) := (others => '0');
begin

    main_pll : entity work.MainPLL
        port map (
            clkout => pll_clk,
            clkin  => CLK_100MHz
        );
    clrn <= USER_BTN;

    rng : entity work.neoTRNG
      generic map (
        NUM_CELLS     => 32,
        NUM_INV_START => 3,
        NUM_INV_INC   => 2,
        NUM_INV_DELAY => 2
      )
      port map (
        clk_i    => pll_clk,
        enable_i => clrn,
        data_o   => rng_data,
        valid_o  => rng_valid
      );

    uart : entity work.UART
        generic map (
            INPUT_FREQUENCY => 100.000000,
            BAUD_RATE       =>    1000000
        )
        port map (
            CLK      => pll_clk,
            CLRn     => clrn,

            UART_RX  => UART_RX,
            UART_TX  => UART_TX,

            TX_DATA  => rng_data,
            TX_START => rng_valid,
--          TX_BUSY  => tx_busy,

            RX_DATA  => rx_data,
            RX_DONE  => rx_done
        );

    display_clk : entity work.ClockScaler
        generic map (
            INPUT_FREQUENCY  => 100.000000,
            OUTPUT_FREQUENCY =>   0.000010
        )
        port map (
            INPUT_CLK    => pll_clk,
            CLRn         => clrn,
            OUTPUT_PULSE => display_pulse
        );

    process (pll_clk)
    begin
        if rising_edge(pll_clk) then
            if rng_valid = '1' then
                display_data <= rng_data;
            end if;
            if rx_done = '1' then
                LED <= rx_data;
            elsif display_pulse = '1' then
                LED <= display_data;
            end if;
        end if;
    end process;

end TEC0117_HRNG_arch;
