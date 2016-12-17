library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.general_pkg.all;

entity dynamic_uart_rx is
   port(
      clk    : in  std_logic;
      srst   : in  std_logic; --change config inputs while holding reset
      
      clocks_per_bit : in unsigned(15 downto 0); -- minimum 4, reccommended 16+
      data_bits      : in unsigned( 2 downto 0); -- add 4
      parity_mode    : in unsigned( 1 downto 0); -- 00 = none, 01 = odd, 10 = even, 11 = unsupported

      rxd    : in  std_logic; --must by syncronized to clk

      data   : out std_logic_vector(11 downto 0); --only lower [data_bits+4] are valid
      valid  : out std_logic; --pulses once per word. concurrent with error upon parity failure
      error  : out std_logic --pulse upon parity or stop error
   );
end dynamic_uart_rx;

architecture rtl of dynamic_uart_rx is
   signal data_i   : std_logic_vector(11 downto 0);
   signal parity_i : std_logic;
   
   signal clk_cnt  : unsigned(15 downto 0);
   signal data_cnt : unsigned(3 downto 0);
   
   type t_state is (s_idle, s_start, s_data, s_parity, s_stop, s_err, s_err_wait);
   signal state : t_state := s_err;
begin
   p_rx : process(clk)
   begin
      if rising_edge(clk) then
         if clk_cnt /= clocks_per_bit-1 then
            clk_cnt <= clk_cnt+1; --default
         else
            clk_cnt <= (others=>'0'); 
         end if;
         error <= '0'; --default
         valid <= '0'; --default
         
         case state is
            when s_idle =>
               clk_cnt  <= '0' & clocks_per_bit(15 downto 1); --50% phase offset for sampling for best signal integrity
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
                  data_i(to_integer(data_cnt)) <= rxd; --lsb sent first
                  parity_i <= parity_i xor rxd;
                  data_cnt <= data_cnt+1;
                  if data_cnt = ('0' & data_bits) + 3 then
                     if parity_mode(0)='1' or parity_mode(1)='1' then
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
                     if (parity_mode(0)='1' and parity_i='0') or (parity_mode(1)='1' and parity_i='1') then --failed parity
                        error <= '1'; --but stop bit is okay, so we go to idle
                     end if;
                  else
                     state <= s_err;
                     error <= '1';
                  end if;
               end if;
            when s_err =>
               clk_cnt  <= '0' & clocks_per_bit(15 downto 1);
               if rxd='1' then
                  state <= s_err_wait;
               end if;
            when s_err_wait =>
               if clk_cnt = clocks_per_bit-1 then
                  state <= s_idle;
               end if;
         end case;
         
         if srst='1' then
            data_i <= (others => '0'); --clears upper bits if the data width was changed
            state  <= s_err; --waits until we have an idle signal before becoming ready
         end if;
      end if;
   end process;
end rtl;