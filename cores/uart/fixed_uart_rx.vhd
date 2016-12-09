library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.general_pkg.all;


entity fixed_uart_rx is
   generic(
      clocks_per_bit : positive := 16;
      data_bits      : positive := 8;
      parity_odd     : boolean  := false;
      parity_even    : boolean  := false
      --will wait for next start bit regardless of how many stop bits transmitter uses
   );
   port(
      clk    : in  std_logic;
      srst   : in  std_logic;

      rxd    : in  std_logic; --must by syncronized to clk

      data   : out std_logic_vector(data_bits-1 downto 0);
      valid  : out std_logic; --pulses once per word. concurrent with error upon parity failure
      error  : out std_logic --pulse upon parity or stop error
   );
end fixed_uart_rx;

architecture rtl of fixed_uart_rx is
   signal data_i   : std_logic_vector(data_bits-1 downto 0);
   signal parity_i : std_logic;
   
   signal clk_cnt  : unsigned(f_log2_ceil(clocks_per_bit)-1 downto 0);
   signal data_cnt : unsigned(f_log2_ceil(data_bits)-1 downto 0);
   
   type t_state is (s_idle, s_start, s_data, s_parity, s_stop, s_err, s_err_wait);
   signal state : t_state := s_err;
begin
   assert not(parity_odd and parity_even) report "fixed_uart_rx parity misconfigured" severity error;

   p_rx : process(clk)
   begin
      if rising_edge(clk) then
         if f_is_pow2(clocks_per_bit) or clk_cnt /= clocks_per_bit-1 then --don't need an explicit rollover if the counter is a power of 2
            clk_cnt <= clk_cnt+1; --default
         else
            clk_cnt <= (others=>'0'); 
         end if;
         error <= '0'; --default
         valid <= '0'; --default
         
         case state is
            when s_idle =>
               clk_cnt  <= to_unsigned(clocks_per_bit/2, clk_cnt'length); --50% phase offset for sampling for best signal integrity
               data_cnt <= (others=>'0');
               parity_i <= '0';
               if rxd='0' then
                  state <= s_start;
               end if;
            when s_start =>
               if clk_cnt = clocks_per_bit-1 then
                  state <= s_data;
               end if;
            when s_data =>
               if clk_cnt = clocks_per_bit-1 then
                  data_i <= rxd & data_i(data_i'left downto 1); --lsb sent first, so we need to fill from the top
                  parity_i <= parity_i xor rxd;
                  data_cnt <= data_cnt+1;
                  if data_cnt = data_bits-1 then
                     if parity_odd or parity_even then
                        state <= s_parity;
                     else
                        state <= s_stop;
                     end if;
                  end if;
               end if;
            when s_parity =>
               if clk_cnt = clocks_per_bit-1 then
                  state <= s_stop;
                  parity_i <= parity_i xor rxd;
               end if;
            when s_stop =>
               if clk_cnt = clocks_per_bit-1 then
                  data <= data_i;
                  if rxd='1' then
                     state <= s_idle;
                     valid <= '1';
                     if (parity_odd and parity_i='0') or (parity_even and parity_i='1') then --failed parity
                        error <= '1'; --but stop bit is okay, so we go to idle
                     end if;
                  else
                     state <= s_err;
                     error <= '1';
                  end if;
               end if;
            when s_err =>
               clk_cnt  <= to_unsigned(clocks_per_bit/2, clk_cnt'length);
               if rxd='1' then
                  state <= s_err_wait;
               end if;
            when s_err_wait =>
               if clk_cnt = clocks_per_bit-1 then
                  state <= s_idle;
               end if;
         end case;
         
         if srst='1' then
            state <= s_err; --waits until we have an idle signal before becoming ready
         end if;
      end if;
   end process;
end rtl;