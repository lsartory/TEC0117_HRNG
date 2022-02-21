library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

--------------------------------------------------

entity TEC0117_HRNG is
	port (
		CLK_100MHz : in  std_logic;
        USER_BTN   : in  std_logic;
		LED        : out std_logic_vector(8 downto 1)
	);
end entity;

--------------------------------------------------

architecture TEC0117_HRNG_arch of TEC0117_HRNG is
    signal pll_clk  : std_logic := '0';
    signal clrn     : std_logic := '1';

    signal clock_divider : unsigned(23 downto 0) := (others => '0');
    signal led_output    : unsigned( 7 downto 0) := (others => '0');
begin

    main_pll: entity work.Main_PLL
    port map (
        clkout => pll_clk,
        clkin  => CLK_100MHz
    );
    clrn <= USER_BTN;

	process (pll_clk)
	begin
		if rising_edge(pll_clk) then
            clock_divider <= clock_divider + 1;
            if clock_divider = 9999999 then
                clock_divider <= (others => '0');
                led_output    <= led_output + 1;
            end if;

            if clrn = '0' then
                clock_divider <= (others => '0');
                led_output    <= (others => '0');
            end if;
        end if;
	end process;
    LED <= std_logic_vector(led_output);

end TEC0117_HRNG_arch;
