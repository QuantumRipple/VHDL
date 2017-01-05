library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_sha256 is
end entity tb_sha256;

architecture tb of tb_sha256 is
   component sha256_expander is
      port(
         clk       : in  std_logic;
         chunk     : in  std_logic_vector(511 downto 0);
         expansion : out std_logic_vector(2047 downto 0) --24 cycle delay
      );
   end component;
   
   component sha256_compressor is
      port(
         clk       : in  std_logic;
         expansion : in  std_logic_vector(2047 downto 0);
         state     : in  std_logic_vector( 255 downto 0);
         hash      : out std_logic_vector( 255 downto 0) --x cycle delay
      );
   end component;
   
   constant c_period : time := 10 ns;
   
   constant c_init_state : std_logic_vector(255 downto 0) := x"6a09e667" & x"bb67ae85" & x"3c6ef372" & x"a54ff53a" & x"510e527f" & x"9b05688c" & x"1f83d9ab" & x"5be0cd19"; --word 0 is msb slot, word 7 is lsb
   constant c_padding_1  : std_logic_vector(511 downto 0) := '1' & 447UX"0" & 64D"0"; --(511=>'1', 63 downto 0 => std_logic_vector(to_unsigned(0,64)), others=>'0');
   --constant c_padding_2  : std_logic_vector(255 downto 0) := (255=>'1', 63 downto 0 => std_logic_vector(to_unsigned(256,64)), others=>'0');
   
   signal clk : std_logic;
   
   signal chunk         : std_logic_vector( 511 downto 0);
   signal expansion     : std_logic_vector(2047 downto 0);
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



   u_sha256_expander1 : sha256_expander
   port map (
      clk       => clk,
      chunk     => chunk,
      expansion => expansion
   );


   u_sha256_compressor1 : sha256_compressor
   port map (
      clk       => clk,
      expansion => expansion,
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
      chunk <= (others=> '0');
      for i in 1 to 24 loop
         wait until rising_edge(clk);
      end loop;
      flag <= 2;
      for i in 1 to 65 loop
         wait until rising_edge(clk);
      end loop;
      flag <= 3;
      wait;
   end process;
   
end architecture tb;