library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

--------------------------------------------------

entity HRNG is
	port (
		CLK_100MHz : in  std_logic;
        CLRn       : in  std_logic;
		LED        : out std_logic_vector(7 downto 0)
	);
end entity;

--------------------------------------------------

architecture HRNG_arch of HRNG is
    signal clock_divider : unsigned(23 downto 0) := (others => '0');
    signal led_output    : unsigned( 7 downto 0) := (others => '0');
begin

	process (CLK_100MHz)
	begin
		if rising_edge(CLK_100MHz) then
            clock_divider <= clock_divider + 1;
            if clock_divider = 9999999 then
                clock_divider <= (others => '0');
                led_output    <= led_output + 1;
            end if;

            if CLRn = '0' then
                clock_divider <= (others => '0');
                led_output    <= (others => '0');
            end if;
        end if;
	end process;
    LED <= std_logic_vector(led_output);

end HRNG_arch;
