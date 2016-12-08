library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.general_pkg.all;

-- safely transitions a bus across clock domains with arbitrary contents (no Hamming distance limitation like plain synchronizers)
-- latency is 3 destination (slow) clock periods MINUS 1 to 2 source (fast) clock periods.
-- if single clock events on the source domain are important, they should be held until src_en has been asserted so they will be transferred to the slower destination domain.
-- this block will malfunction if the destination clock is even infinitessimally faster than the source clock, as it will read a fifo position that the writer missed causing out-of-order results.
-- if the clocks are similar in speed but need a safe clock crossing, the slow_to_fast version of this block can handle slight violations where the source clock is up to 1.3x faster than the destination clock.

entity async_bus_fast_to_slow is
   generic(
      n : positive := 2 --there is no reason to use this on a single bit
   );
   port(
      src_clk    : in  std_logic;
      src_data   : in  std_logic_vector(n-1 downto 0);
      src_en     : out std_logic; --not required to use, but with fast to slow transitions, not every value is used
      dst_clk    : in  std_logic;
      dst_data   : out std_logic_vector(n-1 downto 0)
   );
end async_bus_fast_to_slow;

architecture rtl of async_bus_fast_to_slow is
   component sync2
      generic (
         n       : positive := 1
      );
      port (
         dst_clk : in  std_logic;
         d       : in  std_logic_vector(n-1 downto 0);
         q       : out std_logic_vector(n-1 downto 0)
      );
   end component;
   constant c_gray_rom : t_slv_vec(0 to 3)(1 downto 0) := f_gray_rom(2);
   signal wr_gray_cnt, wr_gray_cnt_d, rd_gray_cnt : std_logic_vector(1 downto 0) := "00";
   signal fifo : t_slv_vec(0 to 3)(n-1 downto 0);
   attribute ram_style : string;
   attribute ram_style of fifo : signal is "distributed"; --sort of a waste of lutram for 4 values, but a 4:1 mux would also take a lut for each bit and registers to boot
   
begin
   p_fast : process(src_clk)
   begin
      if rising_edge(src_clk) then
         if wr_gray_cnt/=wr_gray_cnt_d then
            fifo(to_integer(unsigned(wr_gray_cnt_d))) <= src_data; --uses _d here because when src_clk is very fast, a new address can be propogated before dst_clk has read it
            src_en <= '1';
         else
            src_en <= '0';
         end if;
         wr_gray_cnt_d <= wr_gray_cnt;
      end if;
   end process;
   
   p_slow : process(dst_clk)
   begin
      if rising_edge(dst_clk) then
         rd_gray_cnt <= c_gray_rom(to_integer(unsigned(rd_gray_cnt)));
         dst_data    <= fifo(to_integer(unsigned(rd_gray_cnt)));
      end if;
   end process;

   u_sync : sync2 generic map (n=>2) port map(dst_clk=>src_clk, d=>rd_gray_cnt, q=>wr_gray_cnt);

end rtl;