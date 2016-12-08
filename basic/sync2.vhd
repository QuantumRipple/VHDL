library ieee;
use ieee.std_logic_1164.all;

-- 2 flop synchronizer for arbitrary widths
--
-- d must be the output of a register, not a logic LUT, to avoid catching glitches
--
-- due to the nature of synchronization, when the source domain's clock edge falls such that the destination domain registers' 
-- setup or hold has been violated, each bit will somewhat *indedendently* capture on the earlier or later value. 
-- This means that the integrity of a multi-bit bus (all of q equal to the d right before or after the offending clock edge, 
-- but not a mix of both) can only be guaranteed if subsequent values of d have a Hamming distance of 0 or 1 (such as with Gray
-- code)
--
-- this remains true when the source domain is faster than the destination domain (such that the Hamming distance of subsequent
-- values of Q might exceed 1) as long as all routes from d to s (the first synchronization register) have a skew relative to 
-- each other of less than the period of the faster clock.

entity sync2 is
   generic (
      n       : positive := 1
   );
   port (
      dst_clk : in  std_logic;
      d       : in  std_logic_vector(n-1 downto 0);
      q       : out std_logic_vector(n-1 downto 0)
   );
end sync2;

architecture rtl of sync2 is
begin
   g_bits : for i in 0 to n-1 generate
      signal s, q_i : std_logic;
      attribute async_reg : string;
      attribute async_reg of s, q_i : signal is "true"; --this attribute requests that Vivado pack these two flops very close together to provide maximum time for metastability to settle out. It will also prevent replication, resource sharing, and SRL packing for these flops.
   begin
      q(i) <= q_i;
      process(dst_clk)
      begin
         if rising_edge(dst_clk) then
            q_i <= s;
            s   <= d(i);
         end if;
      end process;
   end generate;
end rtl;