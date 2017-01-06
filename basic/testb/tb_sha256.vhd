library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_sha256 is
end entity tb_sha256;

architecture tb of tb_sha256 is
   component sha256 is
      port(
         clk       : in  std_logic;
         chunk     : in  std_logic_vector(511 downto 0); --requires preprocessing for arbitrary datastreams
         state     : in  std_logic_vector(255 downto 0);
         hash      : out std_logic_vector(255 downto 0) --65 cycle delay, likewise processing data streams beyond one chunk should be done with 65 streams in parallel (or 64 with a dead cycle to make the muxing cheaper)
      );
   end component;

   constant c_period : time := 10 ns;

   constant c_init_state : std_logic_vector(255 downto 0) := x"6a09e667" & x"bb67ae85" & x"3c6ef372" & x"a54ff53a" & x"510e527f" & x"9b05688c" & x"1f83d9ab" & x"5be0cd19"; --word 0 is msb slot, word 7 is lsb

   constant c_padding_1  : std_logic_vector(511 downto 0) := '1' & 447UX"0" & 64D"0"; --(511=>'1', 63 downto 0 => std_logic_vector(to_unsigned(0,64)), others=>'0');
   constant c_padding_2  : std_logic_vector(511 downto 0) := x"54_68_65_20_71_75_69_63_6B_20_62_72_6F_77_6E_20_66_6F_78_20_6A_75_6D_70_73_20_6F_76_65_72_20_74_68_65_20_6C_61_7A_79_20_64_6F_67" & '1' & 103UX"0" & 64d"344"; --"The quick brown fox jumps over the lazy dog"
   constant c_padding_3  : std_logic_vector(511 downto 0) := x"61_62_63" & '1' & 423UX"0" & 64d"24"; --"abc"
   constant c_padding_4  : std_logic_vector(511 downto 0) := x"61" & '1' & 439UX"0" & 64d"8"; --"a"

   constant c_result_1 : std_logic_vector(255 downto 0) := x"e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"; --
   constant c_result_2 : std_logic_vector(255 downto 0) := x"d7a8fbb307d7809469ca9abcb0082e4f8d5651e46d3cdb762d02d0bf37c9e592"; --The quick brown fox jumps over the lazy dog
   constant c_result_3 : std_logic_vector(255 downto 0) := x"ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"; --abc
   constant c_result_4 : std_logic_vector(255 downto 0) := x"ca978112ca1bbdcafac231b39a23dc4da786eff8147c4e72b9807785afee48bb"; --a

   signal clk : std_logic;

   signal chunk         : std_logic_vector( 511 downto 0) := (others=>'0');
   signal chunk_order   : std_logic_vector( 511 downto 0);
   signal hash          : std_logic_vector( 255 downto 0);

   signal flag : integer := 0;

begin
   p_clk : process
   begin
      while true loop
         clk <= '1';
         wait for c_period/2;
         clk <= '0';
         wait for c_period/2;
      end loop;
   end process;

   g_reorder : for i in 0 to 15 generate
   begin
      chunk_order(32*i+31 downto 32*i) <= chunk(511-32*i downto 480-32*i);
   end generate;

   u_sha256 : sha256
   port map (
      clk       => clk,
      chunk     => chunk_order,
      state     => c_init_state,
      hash      => hash
   );

   p_main : process
   begin
      wait for 1 us;
      wait until rising_edge(clk);
      flag <= 1;
      chunk <= c_padding_1;
      wait until rising_edge(clk);
      chunk <= c_padding_2;
      wait until rising_edge(clk);
      chunk <= c_padding_3;
      wait until rising_edge(clk);
      chunk <= c_padding_4;
      wait until rising_edge(clk);
      chunk <= (others=>'0');
      for i in 4 to 65 loop
         wait until rising_edge(clk);
      end loop;
      assert hash = c_result_1 report "failed first test ()" severity error;
      flag <= 3;
      wait until rising_edge(clk);
      assert hash = c_result_2 report "failed second test (The quick brown fox jumps over the lazy dog)" severity error;
      wait until rising_edge(clk);
      assert hash = c_result_3 report "failed third test (abc)" severity error;
      wait until rising_edge(clk);
      assert hash = c_result_4 report "failed third test (a)" severity error;
      wait;
   end process;

end architecture tb;