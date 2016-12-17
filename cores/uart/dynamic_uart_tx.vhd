library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.general_pkg.all;

entity dynamic_uart_tx is
   port(
      clk    : in  std_logic;
      srst   : in  std_logic;
      
      clocks_per_bit : in unsigned(15 downto 0); -- minimum 4, reccommended 16+
      data_bits      : in unsigned( 2 downto 0); -- add 4
      parity_mode    : in unsigned( 1 downto 0); -- 00 = none, X1 = odd, 10 = even
      stop_2_bits    : in std_logic;
      
      txd    : out std_logic;

      data   : in  std_logic_vector(11 downto 0); --only lower [data_bits+4] are transmitted
      en     : in  std_logic; --ignored if asserted when ready is low
      ready  : out std_logic
   );
end dynamic_uart_tx;

architecture rtl of dynamic_uart_tx is
   signal data_i   : std_logic_vector(11 downto 0);
   signal parity_i : std_logic;
   
   signal clk_cnt  : unsigned(15 downto 0) := (others=>'0');
   signal data_cnt : unsigned(3 downto 0);
   
   type t_state is (s_idle, s_data, s_parity, s_stop, s_stop_2, s_hold);
   signal state : t_state := s_hold;
begin

   p_tx : process(clk)
   begin
      if rising_edge(clk) then
         if clk_cnt /= clocks_per_bit-1 then
            clk_cnt <= clk_cnt+1; --default
         else
            clk_cnt <= (others=>'0'); 
         end if;
         
         case state is
            when s_idle =>
               clk_cnt  <= (others=>'0');
               data_cnt <= (others=>'0');
               parity_i <= '0';
               if en='1' then
                  data_i <= data;
                  state  <= s_data;
                  txd    <= '0'; --start bit
                  ready  <= '0';
               end if;
            when s_data =>
               if clk_cnt = clocks_per_bit-1 then
                  txd <= data_i(0);
                  data_i <= '0' & data_i(data_i'left downto 1);
                  parity_i <= parity_i xor data_i(0);
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
                  if parity_mode(0)='1' then --odd
                     txd <= not(parity_i);
                  else
                     txd <= parity_i;
                  end if;
               end if;
            when s_stop =>
               if clk_cnt = clocks_per_bit-1 then
                  txd <= '1'; --stop bit
                  if stop_2_bits='1' then
                     state <= s_stop_2;
                  else
                     state <= s_hold;
                  end if;
               end if;
            when s_stop_2 =>
               if clk_cnt = clocks_per_bit-1 then
                  txd   <= '1'; --stop bit
                  state <= s_hold;
               end if;
            when s_hold =>
               txd <= '1';
               if clk_cnt = clocks_per_bit-2 then --drops a cycle to make time for max speed transmission when en is asserted on the first cycle of idle
                  state <= s_idle;
                  ready <= '1';
               end if;
         end case;
         
         if srst='1' then
            clk_cnt <= (others=>'0');
            ready   <= '0';
            state   <= s_hold;
         end if;
      end if;
   end process;
end rtl;