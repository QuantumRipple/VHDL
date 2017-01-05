--status: pipelined but yet to be compiled, untested, and not optimized

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.general_pkg.all;

entity sha256_compressor is
   port(
      clk       : in  std_logic;
      expansion : in  std_logic_vector(2047 downto 0);
      state     : in  std_logic_vector( 255 downto 0);
      hash      : out std_logic_vector( 255 downto 0); --65 cycle delay
   );
end sha256_compressor;

architecture rtl of sha256_compressor is
   constant c_k : t_unsigned_vec(0 to 63)(31 downto 0) := (
     x"428a2f98", x"71374491", x"b5c0fbcf", x"e9b5dba5", x"3956c25b", x"59f111f1", x"923f82a4", x"ab1c5ed5",
     x"d807aa98", x"12835b01", x"243185be", x"550c7dc3", x"72be5d74", x"80deb1fe", x"9bdc06a7", x"c19bf174",
     x"e49b69c1", x"efbe4786", x"0fc19dc6", x"240ca1cc", x"2de92c6f", x"4a7484aa", x"5cb0a9dc", x"76f988da",
     x"983e5152", x"a831c66d", x"b00327c8", x"bf597fc7", x"c6e00bf3", x"d5a79147", x"06ca6351", x"14292967",
     x"27b70a85", x"2e1b2138", x"4d2c6dfc", x"53380d13", x"650a7354", x"766a0abb", x"81c2c92e", x"92722c85",
     x"a2bfe8a1", x"a81a664b", x"c24b8b70", x"c76c51a3", x"d192e819", x"d6990624", x"f40e3585", x"106aa070",
     x"19a4c116", x"1e376c08", x"2748774c", x"34b0bcb5", x"391c0cb3", x"4ed8aa4a", x"5b9cca4f", x"682e6ff3",
     x"748f82ee", x"78a5636f", x"84c87814", x"8cc70208", x"90befffa", x"a4506ceb", x"bef9a3f7", x"c67178f2");

   signal d_set : t_unsigned_vec(0 to 64)(255 downto 0); --digest set, used to pipeline compression
begin
--0 = h
--1 = g
--2 = f
--3 = e
--4 = d
--5 = c
--6 = b
--7 = a


   d_set(0) <= state;
   
   process(clk)
      variable v_S1    : unsigned(31 downto 0);
      variable v_ch    : unsigned(31 downto 0);
      variable v_temp1 : unsigned(31 downto 0);
      variable v_S0    : unsigned(31 downto 0);
      variable v_maj   : unsigned(31 downto 0);
      variable v_temp2 : unsigned(31 downto 0);
   begin
      if rising_edge(clk) then
         for i in 0 to 63 loop
            v_S1 := rotate_right(d_set(i)(32*3+31 downto 32*3),6) xor rotate_right(d_set(i)(32*3+31 downto 32*3),11) xor rotate_right(d_set(i)(32*3+31 downto 32*3),25);
            v_ch := (d_set(i)(32*3+31 downto 32*3) and d_set(i)(32*2+31 downto 32*2)) xor (not(d_set(i)(32*3+31 downto 32*3)) and d_set(i)(32*1+31 downto 32*1));
            v_temp1 := d_set(i)(32*0+31 downto 32*0) + v_S1 + v_ch + c_k(i) + expansion(32*i+31 downto 32*i);
            
            v_S0 := rotate_right(d_set(i)(32*7+31 downto 32*7),2) xor rotate_right(d_set(i)(32*7+31 downto 32*7),13) xor rotate_right(d_set(i)(32*7+31 downto 32*7),22);
            v_maj := (d_set(i)(32*7+31 downto 32*7) and d_set(i)(32*6+31 downto 32*6)) xor (d_set(i)(32*7+31 downto 32*7) and d_set(i)(32*5+31 downto 32*5)) xor (d_set(i)(32*6+31 downto 32*6) and d_set(i)(32*5+31 downto 32*5));
            v_temp2 := v_S0 + v_maj;
         
            d_set(i+1)(32*2+31 downto 32*0) <= d_set(i)(32*3+31 downto 32*1); --h := g, g := f, f := e
            
            d_set(i+1)(32*3+31 downto 32*3) <= d_set(i)(32*4+31 downto 32*4) + v_temp1; --e := d+temp1
            
            d_set(i+1)(32*6+31 downto 32*4) <= d_set(i)(32*7+31 downto 32*5); --d := c, c := b, b := a
            
            d_set(i+1)(32*7+31 downto 32*7) <= v_temp1 + v_temp2; --a := temp1+temp2
            
            
         end loop;
         
         for i in 0 to 7 loop
            hash(32*i+31 downto 32*i) <= d_set(64)(32*i+31 downto 32*i) + state_d(64)(32*i+31 downto 32*i);
         end loop;
      end if;
   end process;

end architecture rtl;