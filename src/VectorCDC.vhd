---- VectorCDC.vhd
 --
 -- Author: L. Sartory
 -- Creation: 01.04.2015
----

--------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

--------------------------------------------------

entity VectorCDC is
    generic (
        LATCH_COUNT : natural := 3
    );
    port (
        TARGET_CLK  : in  std_logic;
        INPUT       : in  std_logic_vector;
        OUTPUT      : out std_logic_vector
    );
end entity VectorCDC;

--------------------------------------------------

architecture VectorCDC_arch of VectorCDC is
    type latch_array is array(natural range <>) of std_logic_vector(INPUT'high downto INPUT'low);
    signal input_latch : latch_array(LATCH_COUNT - 1 downto 0) := (others => (others => '0'));
begin

    -- Vector clock domain crossing
    process (TARGET_CLK)
    begin
        if rising_edge(TARGET_CLK) then
            for i in input_latch'high downto input_latch'low + 1 loop
                input_latch(i) <= input_latch(i - 1);
            end loop;
            input_latch(input_latch'low) <= INPUT;
        end if;
    end process;
    OUTPUT <= input_latch(input_latch'high);

end VectorCDC_arch;
