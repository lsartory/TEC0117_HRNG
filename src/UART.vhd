---- UART.vhd
 --
 -- Author: L. Sartory
 -- Creation: 2022-02-27
----

--------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

--------------------------------------------------

entity UART is
    generic (
        INPUT_FREQUENCY : real;
        BAUD_RATE       : natural
    );
    port (
        CLK      : in  std_logic;
        CLRn     : in  std_logic;

        UART_RX  : in  std_logic;
        UART_TX  : out std_logic;

        TX_DATA  : in  std_logic_vector(7 downto 0);
        TX_START : in  std_logic;
        TX_BUSY  : out std_logic;

        RX_DATA  : out std_logic_vector(7 downto 0);
        RX_DONE  : out std_logic
    );
end UART;

--------------------------------------------------

architecture UART_arch of UART is

    type tx_state_t is (idle, sending);
    signal tx_state      : tx_state_t := idle;
    signal tx_baud_pulse : std_logic  := '0';
    signal tx_shift_reg  : std_logic_vector(9 downto 0) := (others => '0');

    signal uart_rx_sync  : std_logic := '0';
    signal uart_rx_prev  : std_logic := '0';
    type rx_state_t is (idle, receiving);
    signal rx_state      : rx_state_t := idle;
    signal rx_baud_pulse : std_logic  := '0';
    signal rx_baud_clrn  : std_logic  := '0';
    signal rx_shift_reg  : std_logic_vector(8 downto 0) := (others => '0');
    signal rx_count      :         unsigned(4 downto 0) := (others => '0');

begin

    tx_baud_rate_gen : entity work.ClockScaler
        generic map (
            INPUT_FREQUENCY  => INPUT_FREQUENCY,
            OUTPUT_FREQUENCY => real(BAUD_RATE) / 1000000.0
        )
        port map (
            INPUT_CLK    => CLK,
            CLRn         => CLRn,
            OUTPUT_PULSE => tx_baud_pulse
        );

    process (CLK)
    begin
        if rising_edge(CLK) then
            TX_BUSY <= '1';
            case tx_state is
                when idle =>
                    UART_TX <= '1';
                    if TX_START = '1' then
                        tx_shift_reg <= '1' & TX_DATA & '0';
                        tx_state     <= sending;
                    else
                        TX_BUSY <= '0';
                    end if;

                when sending =>
                    if unsigned(tx_shift_reg) = 0 then
                        tx_state <= idle;
                    elsif tx_baud_pulse = '1' then
                        UART_TX      <= tx_shift_reg(tx_shift_reg'low);
                        tx_shift_reg <= '0' & tx_shift_reg(tx_shift_reg'high downto tx_shift_reg'low + 1);
                    end if;
            end case;

            if CLRn = '0' then
                tx_state <= idle;
            end if;
        end if;
    end process;

    --------------------------------------------------

    rx_cdc : entity work.VectorCDC
        port map (
            TARGET_CLK => CLK,
            INPUT(0)   => UART_RX,
            OUTPUT(0)  => uart_rx_sync
        );

    rx_baud_rate_gen : entity work.ClockScaler
        generic map (
            INPUT_FREQUENCY  => INPUT_FREQUENCY,
            OUTPUT_FREQUENCY => real(BAUD_RATE) / 500000.0
        )
        port map (
            INPUT_CLK    => CLK,
            CLRn         => rx_baud_clrn,
            OUTPUT_PULSE => rx_baud_pulse
        );

    process (CLK)
    begin
        if rising_edge(CLK) then
            RX_DONE      <= '0';
            rx_baud_clrn <= '0';
            uart_rx_prev <= uart_rx_sync;

            case rx_state is
                when idle =>
                    rx_count <= (others => '0');
                    if uart_rx_prev = '1' and uart_rx_sync = '0' then
                        rx_baud_clrn <= '1';
                        rx_state     <= receiving;
                    end if;

                when receiving =>
                    rx_baud_clrn <= '1';
                    if rx_baud_pulse = '1' then
                        rx_count <= rx_count + 1;
                        if rx_count >= 18 then
                            if rx_shift_reg(rx_shift_reg'high) = '0' and uart_rx_sync = '1' then
                                RX_DATA  <= rx_shift_reg(7 downto 0);
                                RX_DONE  <= '1';
                                rx_state <= idle;
                            end if;
                        elsif rx_count(rx_count'low) = '0' then
                            rx_shift_reg <= rx_shift_reg(rx_shift_reg'high - 1 downto rx_shift_reg'low) & uart_rx_sync;
                        end if;
                    end if;
            end case;

            if CLRn = '0' then
                RX_DONE  <= '0';
                rx_state <= idle;
            end if;
        end if;
    end process;

end UART_arch;
