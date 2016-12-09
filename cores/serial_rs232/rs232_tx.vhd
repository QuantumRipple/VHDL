library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.general_pkg.all;

entity rs232_tx is
   generic(
      clocks_per_bit : positive := 16;
      data_bits      : positive := 8;
      parity_odd     : boolean  := false;
      parity_even    : boolean  := false;
      stop_2_bits    : boolean  := false
   );
   port(
      clk    : in  std_logic;
      srst   : in  std_logic;

      txd    : out std_logic;

      data   : in  std_logic_vector(data_bits-1 downto 0);
      en     : in  std_logic; --ignored if asserted when ready is low
      ready  : out std_logic
   );
end rs232_tx;

architecture rtl of rs232_tx is
   signal data_i   : std_logic_vector(data_bits-1 downto 0);
   signal parity_i : std_logic;
   
   signal clk_cnt  : unsigned(f_log2_ceil(clocks_per_bit)-1 downto 0) := (others=>'0');
   signal data_cnt : unsigned(f_log2_ceil(data_bits)-1 downto 0);
   
   type t_state is (s_idle, s_data, s_parity, s_stop, s_stop_2, s_hold);
   signal state : t_state := s_hold;
begin
   assert not(parity_odd and parity_even) report "rs232_tx parity misconfigured" severity error;

   p_tx : process(clk)
   begin
      if rising_edge(clk) then
         if f_is_pow2(clocks_per_bit) or clk_cnt /= clocks_per_bit-1 then --don't need an explicit rollover if the counter is a power of 2
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
                  if parity_odd then
                     txd <= not(parity_i);
                  else
                     txd <= parity_i;
                  end if;
               end if;
            when s_stop =>
               if clk_cnt = clocks_per_bit-1 then
                  txd <= '1'; --stop bit
                  if stop_2_bits then
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