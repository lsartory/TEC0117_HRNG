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
        TX_BUSY  : out std_logic
    );
end UART;

--------------------------------------------------

architecture UART_arch of UART is
    signal baud_pulse : std_logic := '0';

    type uart_tx_state_t is (idle, sending);
    signal uart_tx_state : uart_tx_state_t := idle;
    signal tx_shift_reg  : std_logic_vector(9 downto 0) := (others => '0');
begin

    baud_rate_gen: entity work.ClockScaler
        generic map (
            INPUT_FREQUENCY  => INPUT_FREQUENCY,
            OUTPUT_FREQUENCY => real(BAUD_RATE) / 1000000.0
        )
        port map (
            INPUT_CLK    => CLK,
            CLRn         => CLRn,
            OUTPUT_PULSE => baud_pulse
        );

    process (CLK)
    begin
        if rising_edge(CLK) then
            TX_BUSY <= '1';
            case uart_tx_state is
                when idle =>
                    TX_BUSY <= '0';
                    UART_TX <= '1';
                    if TX_START = '1' then
                        tx_shift_reg  <= '1' & TX_DATA & '0';
                        uart_tx_state <= sending;
                    end if;

                when sending =>
                    if unsigned(tx_shift_reg) = 0 then
                        uart_tx_state <= idle;
                    elsif baud_pulse = '1' then
                        UART_TX      <= tx_shift_reg(tx_shift_reg'low);
                        tx_shift_reg <= '0' & tx_shift_reg(tx_shift_reg'high downto tx_shift_reg'low + 1);
                    end if;
            end case;

            if CLRn = '0' then
                uart_tx_state <= idle;
            end if;
        end if;
    end process;

end UART_arch;
