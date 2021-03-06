--current status: unfinished, not compiled

--this contains the structure of the "inner loop" required for bitcoin mining. The next level up should increment the nonce every cycle and provide new mid_state/message values every time the nonce rolls over

--a hit will be reported with significant latency (currently looking like 178 and change cycles) after the associated nonce is provided,
-- so some subtraction (and possibly fetching the previous message) is required to get the complete valid header.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity mining_loop is
   port (
      clk       : in  std_logic;
      mid_state : in  std_logic_vector(255 downto 0);--hash result from the first 64-byte word of the header (that doesn't change per nonce)
      message   : in  std_logic_vector( 95 downto 0);
      nonce     : in  std_logic_vector( 31 downto 0); --only this input should change every cycle
      target    : in  std_logic_vector(223 downto 0); --probably most efficient to have a constant or very small variability in permitted target numbers since 224x 224:1 muxes is super expensive (technically a 255 bit number, but top 32 bits are 0 at easiest difficulty)
      hit       : out std_logic
   );
end entity mining_loop;

architecture struct of mining_loop is
   component sha256 is
      port(
         clk       : in  std_logic;
         chunk     : in  std_logic_vector(511 downto 0);
         state     : in  std_logic_vector(255 downto 0);
         hash      : out std_logic_vector(255 downto 0) --65 cycle delay
      );
   end component;
      
   component wide_uns_comparator_dsp is
      generic (
         n : positive := 48
      );
      port (
         clk : in  std_logic;
         a   : in  std_logic_vector(n-1 downto 0);
         b   : in  std_logic_vector(n-1 downto 0);
         gt  : out std_logic; --3 cycle delay
         eq  : out std_logic
      );
   end component;
   
   function f_word_reverse (a : std_logic_vector) return std_logic_vector is
      variable temp : std_logic_vector(a'range);
   begin
      assert a'length mod 32 = 0 report "invalid width input" severity failure;
      for i in 0 to a'length/32-1 loop
         for j in 0 to 31 loop
            temp(32*i+j) := a(a'high-i*32-31+j);
         end loop;
      end loop;
      return temp;
   end f_word_reverse;
   
   constant c_init_state : std_logic_vector(255 downto 0) := x"6a09e667" & x"bb67ae85" & x"3c6ef372" & x"a54ff53a" & x"510e527f" & x"9b05688c" & x"1f83d9ab" & x"5be0cd19"; --word 0 is msb slot, word 7 is lsb
   constant c_padding_1  : std_logic_vector(383 downto 0) := '1' & 319UX"0" & 64d"128"; 
   constant c_padding_2  : std_logic_vector(255 downto 0) := '1' & 191UX"0" & 64d"256";
   
   signal chunk1         : std_logic_vector( 511 downto 0);
   signal hash1          : std_logic_vector( 255 downto 0);
   signal chunk2         : std_logic_vector( 511 downto 0);
   signal hash2          : std_logic_vector( 255 downto 0);
   signal target_ext     : std_logic_vector( 239 downto 0);
   signal gt             : std_logic;
   signal top0           : std_logic_vector(1 to 3);
   
begin

   chunk1 <= f_word_reverse(message & nonce & c_padding_1);

   u_sha256_1 : sha256
   port map (
      clk       => clk,
      chunk     => chunk1,
      state     => mid_state, --TODO: needs to be delayed to match expansion
      hash      => hash1
   );

   chunk2 <= f_word_reverse(hash1 & c_padding_2);
   
   u_sha256_2 : sha256
   port map (
      clk       => clk,
      chunk     => chunk2,
      state     => c_init_state,
      hash      => hash2
   );
   
   target_ext(239 downto 224) <= (others=>'0');
   target_ext(223 downto   0) <= target; --TODO: this needs to be delayed to match hash
   
   u_wide_uns_comparator_dsp : wide_uns_comparator_dsp
   generic map (
      n => 240 --comparison happens in groups of 48, so any n where n mod 48 /= 0 is wasting free resources. We actually only need 224 bits for the dynamic portion of the target
   )
   port map (
      clk => clk,
      a   => hash2(239 downto 0),
      b   => target_ext(239 downto 0),
      gt  => gt, --3 cycles latency
      eq  => open
   );
   
   process(clk)
   begin
      if rising_edge(clk) then
         if unsigned(hash2(255 downto 240)) = 0 then --check the top few bits with LUTs since it would take a whole extra DSP and checking for 0 is easier than a proper gt/lt comparison.
            top0(1) <= '1';
         else
            top0(1) <= '0';
         end if;
         top0(2 to 3) <= top0(1 to 2); --latency match to the comparator DSPs
         
         hit <= not gt and top0(3);
      end if;
   end process;
   
end architecture struct;