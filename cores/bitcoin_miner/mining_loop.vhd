--current status: unfinished, not compiled

--this contains the structure of the "inner loop" required for bitcoin mining. The next level up should increment the nonce every cycle and provide new mid_state/message values every time the nonce rolls over

--a hit will be reported with significant latency (currently looking like 178 and change cycles) after the associated nonce is provided,
-- so some subtraction (and possibly fetching the previous message) is required to get the complete valid header.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity mining_loop is
   port (
      mid_state : in  std_logic_vector(255 downto 0);--hash result from the first 64-byte word of the header (that doesn't change per nonce)
      message   : in  std_logic_vector( 95 downto 0);
      nonce     : in  std_logic_vector( 31 downto 0); --only this input should change every cycle
      hit       : out std_logic;
   );
end entity mining_loop;

architecture struct of mining_loop is
   component sha256_expander is
      port(
         chunk     : in  std_logic_vector(511 downto 0);
         expansion : out std_logic_vector(2047 downto 0); --24 cycle delay
      );
   end component;
   
   component sha256_compressor is
      port(
         expansion : in  std_logic_vector(2047 downto 0);
         state     : in  std_logic_vector( 255 downto 0);
         hash      : out std_logic_vector( 255 downto 0); --x cycle delay
      );
   end component;
   
   constant c_init_state : std_logic_vector(255 downto 0) := x"6a09e667" & x"bb67ae85" & x"3c6ef372" & x"a54ff53a" & x"510e527f" & x"9b05688c" & x"1f83d9ab" & x"5be0cd19"; --word 0 is msb slot, word 7 is lsb
   constant c_padding_1  : std_logic_vector(383 downto 0) := (383=>'1', 63 downto 0 => std_logic_vector(to_unsigned(640,64)), others=>'0');
   constant c_padding_2  : std_logic_vector(255 downto 0) := (255=>'1', 63 downto 0 => std_logic_vector(to_unsigned(256,64)), others=>'0');
   
   signal chunk1 : std_logic_vector(511 downto 0);
   
begin
   message : in std_logic_vector(95 downto 0);

   chunk1 <= message & nonce & c_padding_1;

   u_sha256_expander1 : sha256_expander
      port map (
                chunk     => chunk1,
                expansion => expansion1
   );


   u_sha256_compressor1 : sha256_compressor
      port map (
                expansion => expansion1,
                state     => mid_state, --TODO: needs to be delayed to match expansion
                hash      => hash1
   );

   chunk2 <= hash1 & c_padding_2;
   
   u_sha256_expander2 : sha256_expander
      port map (
                chunk     => chunk2,
                expansion => expansion2
   );


   u_sha256_compressor2 : sha256_compressor
      port map (
                expansion => expansion2,
                state     => c_init_state,
                hash      => hash2
   );
   
   --todo compare hash against difficulty
   hit <= '0';
   
end architecture struct;