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

    signal pulse_5Hz : std_logic := '0';

    signal rng_ready : std_logic  := '0';
    signal rng_data  : std_ulogic_vector(7 downto 0) := (others => '0');
    signal rng_valid : std_ulogic := '0';

    signal sha256_ready : std_logic := '0';
    signal sha256_input : std_logic_vector(511 downto 0);
    signal sha256_data  : std_logic_vector(255 downto 0);
    signal sha256_valid : std_logic := '0';

    signal tx_ready : std_logic := '0';
    signal tx_addr  : natural range 0 to 31 := 0;
    signal tx_data  : std_logic_vector(7 downto 0) := (others => '0');
    signal tx_start : std_logic := '0';
    signal tx_busy : std_logic := '0';

    signal rx_data : std_logic_vector(7 downto 0) := (others => '0');
    signal rx_done : std_logic := '0';

    function slice(x : std_logic_vector; w : natural; n : natural) return std_logic_vector is
        variable ret : std_logic_vector(w - 1 downto 0) := (others => '0');
    begin
        for i in ret'range loop
            ret(i) := x(n * w + i);
        end loop;
        return ret;
    end;
begin

    pll : entity work.MainPLL
        port map (
            clkin  => CLK_100MHz,
            clkout => pll_clk
        );
    clrn <= USER_BTN;

    cs : entity work.ClockScaler
        generic map (
            INPUT_FREQUENCY  => 40.000000,
            OUTPUT_FREQUENCY =>  0.000005
        )
        port map (
            INPUT_CLK    => pll_clk,
            CLRn         => clrn,
            OUTPUT_PULSE => pulse_5Hz
        );

    --------------------------------------------------

    process (pll_clk)
    begin
        if rising_edge(pll_clk) then
            tx_start <= '0';

            if pulse_5Hz = '1' then
                rng_ready <= '1';
            end if;
            if rng_valid = '1' then
                sha256_ready <= '1';
                sha256_input <= sha256_input(sha256_input'high - 8 downto sha256_input'low) & std_logic_vector(rng_data);
            end if;
            if sha256_valid = '1' then
                tx_ready <= '1';
            end if;

            if tx_ready = '1' and tx_busy = '0' and tx_start = '0' then
                tx_addr <= 0;
                if tx_addr < 31 then
                    tx_addr <= tx_addr + 1;
                end if;
                tx_data  <= slice(sha256_data, 8, 7 - tx_addr);
                tx_start <= '1';
            end if;

            if clrn = '0' then
                rng_ready    <= '0';
                sha256_ready <= '0';
                tx_ready     <= '0';
                tx_start     <= '0';
            end if;
        end if;
    end process;

    rng : entity work.neoTRNG
      generic map (
        NUM_CELLS     => 3,
        NUM_INV_START => 3,
        NUM_INV_INC   => 2,
        NUM_INV_DELAY => 2
      )
      port map (
        clk_i    => pll_clk,
        enable_i => rng_ready,
        data_o   => rng_data,
        valid_o  => rng_valid
      );

    sha256 : entity work.SHA256
        port map (
            CLK          => pll_clk,
            CLRn         => clrn,

            INPUT        => sha256_input,
            INPUT_VALID  => sha256_ready,
            OUTPUT       => sha256_data,
            OUTPUT_VALID => sha256_valid
        );

    uart : entity work.UART
        generic map (
            INPUT_FREQUENCY => 40.000000,
            BAUD_RATE       =>   1000000
        )
        port map (
            CLK      => pll_clk,
            CLRn     => clrn,

            UART_RX  => UART_RX,
            UART_TX  => UART_TX,

            TX_DATA  => tx_data,
            TX_START => tx_start,
            TX_BUSY  => tx_busy,

            RX_DATA  => rx_data,
            RX_DONE  => rx_done
        );

    --------------------------------------------------

    process (pll_clk)
    begin
        if rising_edge(pll_clk) then
            if rx_done = '1' then
                LED <= rx_data;
            elsif pulse_5Hz = '1' then
                LED <= sha256_data(7 downto 0);
            end if;
        end if;
    end process;

end TEC0117_HRNG_arch;
