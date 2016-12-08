library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.general_pkg.all;

-- safely transitions a bus across clock domains with arbitrary contents (no Hamming distance limitation like plain synchronizers)
-- latency is 1 destination (slow) clock PLUS 1-2 destination (fast) clocks
-- if the pulse width of events from the source domain are important, the data on the destination domain should only be considered when dst_en is asserted
-- although designed for applications whene the source clock is slower than the destination clock, this block will function
-- without error when the source clock is up to 1.3x faster than the destination clock, and will indicate each time a read position is missed on the read side with the dst_jump output.

entity async_bus_slow_to_fast is
   generic(
      n : positive := 2 --there is no reason to use this on a single bit
   );
   port(
      src_clk    : in  std_logic;
      src_data   : in  std_logic_vector(n-1 downto 0);
      dst_clk    : in  std_logic;
      dst_data   : out std_logic_vector(n-1 downto 0);
      dst_en     : out std_logic; --not required to consider, asserted once per src_clk, the only time the dst_data can change.
      dst_jump   : out std_logic -- indicates a read position was due to the src_clk speed exceeding the dst_clk speed
   );
end async_bus_slow_to_fast;

architecture rtl of async_bus_slow_to_fast is
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
   signal wr_gray_cnt, rd_gray_cnt, rd_gray_cnt_d : std_logic_vector(1 downto 0) := "00";
   signal fifo : t_slv_vec(0 to 3)(n-1 downto 0);
   attribute ram_style : string;
   attribute ram_style of fifo : signal is "distributed"; --sort of a waste of lutram for 4 values, but a 4:1 mux would also take a lut for each bit and registers to boot
begin
   p_slow : process(src_clk)
   begin
      if rising_edge(src_clk) then --driving address progression from the slower clock means we can't overflow/underflow our fifo no matter how much faster the dst_clk is
         wr_gray_cnt <= c_gray_rom(to_integer(unsigned(wr_gray_cnt)));
         fifo(to_integer(unsigned(wr_gray_cnt))) <= src_data;
      end if;
   end process;

   u_sync : sync2 generic map (n=>2) port map(dst_clk=>dst_clk, d=>wr_gray_cnt, q=>rd_gray_cnt);

   p_fast : process(dst_clk)
   begin
      if rising_edge(dst_clk) then
         if rd_gray_cnt/=rd_gray_cnt_d then
            dst_data <= fifo(to_integer(unsigned(rd_gray_cnt_d))); --uses _d here because when dst_clk is very fast, a new address can be propogated before src_clk has written it
            dst_en <= '1';
         else
            dst_en <= '0';
         end if;
         if rd_gray_cnt(0)/=rd_gray_cnt_d(0) and rd_gray_cnt(1)/=rd_gray_cnt_d(1) then --Gray code won't do this if the domain it is incrementing on is actually slower
            dst_jump <= '1';
         else
            dst_jump <= '0';
         end if;
         rd_gray_cnt_d <= rd_gray_cnt;
      end if;
   end process;
end rtl;