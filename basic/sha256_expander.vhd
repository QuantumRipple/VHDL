--status: pipelined but yet to be compiled, untested, and not optimized

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.general_pkg.all;
   
entity sha256_expander is
   port(
      clk       : in  std_logic;
      chunk     : in  std_logic_vector(511 downto 0);
      expansion : out std_logic_vector(2047 downto 0); --24 cycle delay
   );
end sha256_expander;

architecture rtl of sha256_expander is

   signal e_set : t_unsigned_vec(0 to 24)(2047 downto 0) := (others=>(others=>'0')); --expansion set, used to pipeline the expansion process

begin
   e_set(0)(511 downto 0) <= chunk;

   process(clk)
      variable v_s0_a : unsigned(31 downto 0);
      variable v_s1_a : unsigned(31 downto 0);
      variable v_s0_b : unsigned(31 downto 0);
      variable v_s1_b : unsigned(31 downto 0);
   begin
      if rising_edge(clk) then
         for i in 0 to 23 loop --takes 24 pipelined stages to get the remaining 48x 32b words  filled out two at a time
            e_set(i+1)(32*(2*i+16)-1 downto 0) <= e_set(i)(32*(2*i+16)-1 downto 0);
            
            v_s0_a := rotate_right(e_set(i)(32*(2*i+16-15)+31 downto 32*(2*i+16-15)), 7) xor --32 bits
                      rotate_right(e_set(i)(32*(2*i+16-15)+31 downto 32*(2*i+16-15)),18) xor
                       shift_right(e_set(i)(32*(2*i+16-15)+31 downto 32*(2*i+16-15)), 3);
                      
            v_s1_a := rotate_right(e_set(i)(32*(2*i+16-2)+31 downto 32*(2*i+16-2)),17) xor
                      rotate_right(e_set(i)(32*(2*i+16-2)+31 downto 32*(2*i+16-2)),19) xor
                       shift_right(e_set(i)(32*(2*i+16-2)+31 downto 32*(2*i+16-2)),10);
                       
            v_s0_b := rotate_right(e_set(i)(32*(2*i+17-15)+31 downto 32*(2*i+17-15)), 7) xor
                      rotate_right(e_set(i)(32*(2*i+17-15)+31 downto 32*(2*i+17-15)),18) xor
                       shift_right(e_set(i)(32*(2*i+17-15)+31 downto 32*(2*i+17-15)), 3);
                      
            v_s1_b := rotate_right(e_set(i)(32*(2*i+17-2)+31 downto 32*(2*i+17-2)),17) xor
                      rotate_right(e_set(i)(32*(2*i+17-2)+31 downto 32*(2*i+17-2)),19) xor
                       shift_right(e_set(i)(32*(2*i+17-2)+31 downto 32*(2*i+17-2)),10);
            
            e_set(i+1)(32*(2*i+16)+31 downto 32*(2*i+16)) <= v_s0_a + v_s1_a + e_set(i)(32*(2*i+16-16)+31 downto 32*(2*i+16-16)) + e_set(i)(32*(2*i+16-7)+31 downto 32*(2*i+16-7)); --word 16+i*2
            e_set(i+1)(32*(2*i+17)+31 downto 32*(2*i+17)) <= v_s0_b + v_s1_b + e_set(i)(32*(2*i+17-16)+31 downto 32*(2*i+17-16)) + e_set(i)(32*(2*i+17-7)+31 downto 32*(2*i+17-7)); --word 17+i*2
         end loop;
      end if;
   end process;
   
   expansion <= e_set(24);
end rtl;