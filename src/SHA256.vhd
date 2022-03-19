---- SHA256.vhd
 --
 -- Author: L. Sartory
 -- Creation: 13.03.2022
----

--------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

--------------------------------------------------

entity W_RAM is
    port
    (
        CLK      : in  std_logic;
        ADDR     : in  natural range 0 to 63;
        DATA_IN  : in  unsigned(31 downto 0);
        DATA_OUT : out unsigned(31 downto 0);
        WE       : in  std_logic := '1'
    );
end entity W_RAM;

--------------------------------------------------

architecture W_RAM_arch of W_RAM is
    type memory_t is array(63 downto 0) of unsigned(31 downto 0);
    signal ram : memory_t := (others => (others => '0'));
begin
    process (CLK)
    begin
        if rising_edge(CLK) then
            if WE = '1' then
                ram(ADDR) <= DATA_IN;
            end if;
            DATA_OUT <= ram(ADDR);
        end if;
    end process;
end W_RAM_arch;

--------------------------------------------------
--------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

--------------------------------------------------

entity SHA256 is
    port (
        CLK          : in  std_logic;
        CLRn         : in  std_logic;

        INPUT        : in  std_logic_vector(511 downto 0);
        INPUT_VALID  : in  std_logic;
        OUTPUT       : out std_logic_vector(255 downto 0);
        OUTPUT_VALID : out std_logic
    );
end entity SHA256;

--------------------------------------------------

architecture SHA256_arch of SHA256 is
    type sha256_state_t is (idle, copy, extend, compress, add, done);
    signal sha256_state : sha256_state_t        := idle;
    signal i            : natural range 0 to 63 := 0;
    signal op           : natural range 0 to  6 := 0;

    constant base_hash : unsigned(255 downto 0)    := x"6a09e667bb67ae853c6ef372a54ff53a510e527f9b05688c1f83d9ab5be0cd19";
    signal hash        : unsigned(base_hash'range) := base_hash;
    signal input_copy  : unsigned(INPUT'range)     := (others => '0');

    subtype unsigned_32b is unsigned(31 downto 0);
    type unsigned_32b_array_t is array (natural range <>) of unsigned_32b;
    constant k : unsigned_32b_array_t(0 to 63) := (
        x"428a2f98", x"71374491", x"b5c0fbcf", x"e9b5dba5", x"3956c25b", x"59f111f1", x"923f82a4", x"ab1c5ed5",
        x"d807aa98", x"12835b01", x"243185be", x"550c7dc3", x"72be5d74", x"80deb1fe", x"9bdc06a7", x"c19bf174",
        x"e49b69c1", x"efbe4786", x"0fc19dc6", x"240ca1cc", x"2de92c6f", x"4a7484aa", x"5cb0a9dc", x"76f988da",
        x"983e5152", x"a831c66d", x"b00327c8", x"bf597fc7", x"c6e00bf3", x"d5a79147", x"06ca6351", x"14292967",
        x"27b70a85", x"2e1b2138", x"4d2c6dfc", x"53380d13", x"650a7354", x"766a0abb", x"81c2c92e", x"92722c85",
        x"a2bfe8a1", x"a81a664b", x"c24b8b70", x"c76c51a3", x"d192e819", x"d6990624", x"f40e3585", x"106aa070",
        x"19a4c116", x"1e376c08", x"2748774c", x"34b0bcb5", x"391c0cb3", x"4ed8aa4a", x"5b9cca4f", x"682e6ff3",
        x"748f82ee", x"78a5636f", x"84c87814", x"8cc70208", x"90befffa", x"a4506ceb", x"bef9a3f7", x"c67178f2"
    );
    signal w_addr : natural range 0 to 63 := 0;
    signal w      : unsigned_32b := (others => '0');
    signal w_mem  : unsigned_32b := (others => '0');
    signal w_we   : std_logic := '0';

    signal a : unsigned_32b := (others => '0');
    signal b : unsigned_32b := (others => '0');
    signal c : unsigned_32b := (others => '0');
    signal d : unsigned_32b := (others => '0');
    signal e : unsigned_32b := (others => '0');
    signal f : unsigned_32b := (others => '0');
    signal g : unsigned_32b := (others => '0');
    signal h : unsigned_32b := (others => '0');

    signal temp1 : unsigned_32b := (others => '0');
    signal temp2 : unsigned_32b := (others => '0');

    function slice(x : unsigned; w : natural; n : natural) return unsigned is
        variable ret : unsigned(w - 1 downto 0) := (others => '0');
    begin
        for i in ret'range loop
            ret(i) := x(n * w + i);
        end loop;
        return ret;
    end;
    function rightrotate(x : unsigned; n : natural) return unsigned is
    begin
        if n = 0 then
            return x;
        else
            return x(x'low + n - 1 downto x'low) & x(x'high downto x'low + n);
        end if;
    end;
    function rightshift(x : unsigned; n : natural) return unsigned is
    begin
        if n = 0 then
            return x;
        else
            return (n - 1 downto 0 => '0') & x(x'high downto x'low + n);
        end if;
    end;
begin

    w_ram : entity work.W_RAM
        port map (
            CLK      => CLK,
            ADDR     => w_addr,
            DATA_IN  => w,
            DATA_OUT => w_mem,
            WE       => w_we
        );

    process (CLK)
    begin
        if rising_edge(CLK) then
            OUTPUT_VALID <= '0';
            w_we         <= '0';

            case sha256_state is
                when idle =>
                    i  <= 0;
                    op <= 0;
                    if INPUT_VALID = '1' then
                        input_copy   <= unsigned(INPUT);
                        sha256_state <= copy;
                    end if;

                when copy =>
                    i      <= i + 1;
                    w_addr <= i;
                    w      <= slice(input_copy, 32, 15 - i);
                    w_we   <= '1';
                    if i >= 15 then
                        sha256_state <= extend;
                    end if;

                when extend =>
                    op <= 0;
                    if op < 6 then
                        op <= op + 1;
                    end if;
                    case op is
                        when 0 =>
                            w_addr <= i - 15;
                        when 1 =>
                            w_addr <= i -  2;
                        when 2 =>
                            w_addr <= i - 16;
                            temp1  <= rightrotate(w_mem,  7) xor rightrotate(w_mem, 18) xor rightshift(w_mem,  3);
                        when 3 =>
                            w_addr <= i -  7;
                            temp2  <= rightrotate(w_mem, 17) xor rightrotate(w_mem, 19) xor rightshift(w_mem, 10);
                        when 4 =>
                            temp1 <= temp1 + w_mem;
                        when 5 =>
                            temp2 <= temp2 + w_mem;
                        when 6 =>
                            w_addr <= i;
                            w      <= temp1 + temp2;
                            w_we   <= '1';
                            if i < 63 then
                                i <= i + 1;
                            else
                                i <= 0;
                                a <= slice(hash, 32, 7);
                                b <= slice(hash, 32, 6);
                                c <= slice(hash, 32, 5);
                                d <= slice(hash, 32, 4);
                                e <= slice(hash, 32, 3);
                                f <= slice(hash, 32, 2);
                                g <= slice(hash, 32, 1);
                                h <= slice(hash, 32, 0);
                                sha256_state <= compress;
                            end if;
                    end case;

                when compress =>
                    case op is
                        when 0 =>
                            op <= 1;
                            w_addr <= i;
                        when 1 =>
                            op <= 2;
                        when 2 =>
                            op <= 3;
                            if i < 63 then
                                w_addr <= i + 1;
                            end if;
                            temp1 <= h + (rightrotate(e, 6) xor rightrotate(e, 11) xor rightrotate(e, 25)) + ((e and f) xor ((not e) and g)) + k(i) + w_mem;
                            temp2 <=     (rightrotate(a, 2) xor rightrotate(a, 13) xor rightrotate(a, 22)) + ((a and b) xor (a and c) xor (b and c));
                        when 3 =>
                            op <= 2;
                            h  <= g;
                            g  <= f;
                            f  <= e;
                            e  <= d + temp1;
                            d  <= c;
                            c  <= b;
                            b  <= a;
                            a  <= temp1 + temp2;
                            if i < 63 then
                                i <= i + 1;
                            else
                                i <= 0;
                                sha256_state <= add;
                            end if;
                        when others =>
                            op <= 0;
                    end case;

                when add =>
                    hash(255 downto 224) <= slice(hash, 32, 7) + a;
                    hash(223 downto 192) <= slice(hash, 32, 6) + b;
                    hash(191 downto 160) <= slice(hash, 32, 5) + c;
                    hash(159 downto 128) <= slice(hash, 32, 4) + d;
                    hash(127 downto  96) <= slice(hash, 32, 3) + e;
                    hash( 95 downto  64) <= slice(hash, 32, 2) + f;
                    hash( 63 downto  32) <= slice(hash, 32, 1) + g;
                    hash( 31 downto   0) <= slice(hash, 32, 0) + h;
                    sha256_state         <= done;

                when done =>
                    OUTPUT       <= std_logic_vector(hash);
                    OUTPUT_VALID <= '1';
                    sha256_state <= idle;
            end case;

            if CLRn = '0' then
                sha256_state <= idle;
                hash         <= base_hash;
            end if;
        end if;
    end process;

end SHA256_arch;
