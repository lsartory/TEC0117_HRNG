---- TEC0117_HRNG.vhd
 --
 -- Author: L. Sartory
 -- Creation: 2022-19-02
----

--------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

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

    signal tx_start : std_logic := '0';
    signal tx_busy  : std_logic := '0';
begin

    main_pll: entity work.MainPLL
        port map (
            clkout => pll_clk,
            clkin  => CLK_100MHz
        );
    clrn <= USER_BTN;

    tx_clk_gen: entity work.ClockScaler
        generic map (
            INPUT_FREQUENCY  => 100.000000,
            OUTPUT_FREQUENCY =>   0.000002
        )
        port map (
            INPUT_CLK    => pll_clk,
            CLRn         => clrn,
            OUTPUT_PULSE => tx_start
        );

    uart: entity work.UART
        generic map (
            INPUT_FREQUENCY => 100.000000,
            BAUD_RATE       =>     115200
        )
        port map (
            CLK      => pll_clk,
            CLRn     => clrn,

            UART_RX  => UART_RX,
            UART_TX  => UART_TX,

            TX_DATA  => x"30",
            TX_START => tx_start,
            TX_BUSY  => tx_busy
        );

    process (pll_clk)
        variable x : std_logic := '0';
    begin
        if rising_edge(pll_clk) then
            if tx_start = '1' then
                x := not x;
                LED <= (others => x);
            end if;
        end if;
    end process;

end TEC0117_HRNG_arch;
