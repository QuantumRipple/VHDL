
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;  

entity wide_uns_comparator_dsp is
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
end wide_uns_comparator_dsp;


architecture rtl of wide_uns_comparator_dsp is
   component dsp48e1plus is
   generic (
      -- Feature Control Attributes: Data Path Selection
      A_INPUT             : string     := "DIRECT";   -- Selects A input source, "DIRECT" (A port) or "CASCADE" (ACIN port)
      B_INPUT             : string     := "DIRECT";   -- Selects B input source, "DIRECT" (B port) or "CASCADE" (BCIN port)
      USE_DPORT           : boolean    := FALSE;      -- Select D port usage (TRUE or FALSE)
      USE_MULT            : string     := "MULTIPLY"; -- Select multiplier usage ("MULTIPLY", "DYNAMIC", or "NONE")
      USE_SIMD            : string     := "ONE48";    -- SIMD selection ("ONE48", "TWO24", "FOUR12")
      IS_ALUMODE_INVERTED : std_logic_vector (3 downto 0) := "0000";
      IS_CARRYIN_INVERTED : bit        := '0';
      IS_CLK_INVERTED     : bit        := '0';
      IS_INMODE_INVERTED  : std_logic_vector (4 downto 0) := "00000";
      IS_OPMODE_INVERTED  : std_logic_vector (6 downto 0) := "0000000";
      AUTORESET_PATDET    : string     := "NO_RESET";      -- "NO_RESET", "RESET_MATCH", "RESET_NOT_MATCH"
      MASK                : bit_vector := X"3fffffffffff"; -- 48-bit mask value for pattern detect (1=ignore)
      PATTERN             : bit_vector := X"000000000000"; -- 48-bit pattern match for pattern detect
      SEL_MASK            : string     := "MASK";          -- "C", "MASK", "ROUNDING_MODE1", "ROUNDING_MODE2"
      SEL_PATTERN         : string     := "PATTERN";       -- Select pattern value ("PATTERN" or "C")
      USE_PATTERN_DETECT  : string     := "NO_PATDET";     -- Enable pattern detect ("PATDET" or "NO_PATDET")
      ACASCREG            : integer := 1; -- Number of pipeline stages between A/ACIN and ACOUT (0, 1 or 2)
      ADREG               : integer := 1; -- Number of pipeline stages for pre-adder (0 or 1)
      ALUMODEREG          : integer := 1; -- Number of pipeline stages for ALUMODE (0 or 1)
      AREG                : integer := 1; -- Number of pipeline stages for A (0, 1 or 2)
      BCASCREG            : integer := 1; -- Number of pipeline stages between B/BCIN and BCOUT (0, 1 or 2)
      BREG                : integer := 1; -- Number of pipeline stages for B (0, 1 or 2)
      CARRYINREG          : integer := 1; -- Number of pipeline stages for CARRYIN (0 or 1)
      CARRYINSELREG       : integer := 1; -- Number of pipeline stages for CARRYINSEL (0 or 1)
      CREG                : integer := 1; -- Number of pipeline stages for C (0 or 1)
      DREG                : integer := 1; -- Number of pipeline stages for D (0 or 1)
      INMODEREG           : integer := 1; -- Number of pipeline stages for INMODE (0 or 1)
      MREG                : integer := 1; -- Number of multiplier pipeline stages (0 or 1)
      OPMODEREG           : integer := 1; -- Number of pipeline stages for OPMODE (0 or 1)
      PREG                : integer := 1  -- Number of pipeline stages for P (0 or 1)
   );
   port (
      ACOUT               : out std_logic_vector(29 downto 0); -- 30-bit output: A port cascade output
      BCOUT               : out std_logic_vector(17 downto 0); -- 18-bit output: B port cascade output
      CARRYCASCOUT        : out std_ulogic;                    -- 1-bit output: Cascade carry output
      MULTSIGNOUT         : out std_ulogic;                    -- 1-bit output: Multiplier sign cascade output
      PCOUT               : out std_logic_vector(47 downto 0); -- 48-bit output: Cascade output
      OVERFLOW            : out std_ulogic;                    -- 1-bit output: Overflow in add/acc output
      PATTERNBDETECT      : out std_ulogic;                    -- 1-bit output: Pattern bar detect output
      PATTERNDETECT       : out std_ulogic;                    -- 1-bit output: Pattern detect output
      UNDERFLOW           : out std_ulogic;                    -- 1-bit output: Underflow in add/acc output
      CARRYOUT            : out std_logic_vector(3 downto 0);  -- 4-bit output: Carry output
      P                   : out std_logic_vector(47 downto 0); -- 48-bit output: Primary data output
      ACIN                : in  std_logic_vector(29 downto 0) := (others=>'0'); -- 30-bit input: A cascade data input
      BCIN                : in  std_logic_vector(17 downto 0) := (others=>'0'); -- 18-bit input: B cascade input
      CARRYCASCIN         : in  std_ulogic                    := '0';           -- 1-bit input: Cascade carry input
      MULTSIGNIN          : in  std_ulogic                    := '0';           -- 1-bit input: Multiplier sign input
      PCIN                : in  std_logic_vector(47 downto 0) := (others=>'0'); -- 48-bit input: P cascade input
      ALUMODE             : in  std_logic_vector(3 downto 0)  := (others=>'0'); -- 4-bit input: ALU control input
      CARRYINSEL          : in  std_logic_vector(2 downto 0)  := (others=>'0'); -- 3-bit input: Carry select input
      CLK                 : in  std_ulogic                    := '0';           -- 1-bit input: Clock input
      INMODE              : in  std_logic_vector(4 downto 0)  := (others=>'0'); -- 5-bit input: INMODE control input
      OPMODE              : in  std_logic_vector(6 downto 0)  := (others=>'0'); -- 7-bit input: Operation mode input
      A                   : in  std_logic_vector(29 downto 0) := (others=>'0'); -- 30-bit input: A data input
      B                   : in  std_logic_vector(17 downto 0) := (others=>'0'); -- 18-bit input: B data input
      C                   : in  std_logic_vector(47 downto 0) := (others=>'0'); -- 48-bit input: C data input
      CARRYIN             : in  std_ulogic                    := '0';           -- 1-bit input: Carry input signal
      D                   : in  std_logic_vector(24 downto 0) := (others=>'0'); -- 25-bit input: D data input
      CEA1                : in  std_ulogic := '1'; -- 1-bit input: Clock enable input for 1st stage AREG
      CEA2                : in  std_ulogic := '1'; -- 1-bit input: Clock enable input for 2nd stage AREG
      CEAD                : in  std_ulogic := '1'; -- 1-bit input: Clock enable input for ADREG
      CEALUMODE           : in  std_ulogic := '1'; -- 1-bit input: Clock enable input for ALUMODE
      CEB1                : in  std_ulogic := '1'; -- 1-bit input: Clock enable input for 1st stage BREG
      CEB2                : in  std_ulogic := '1'; -- 1-bit input: Clock enable input for 2nd stage BREG
      CEC                 : in  std_ulogic := '1'; -- 1-bit input: Clock enable input for CREG
      CECARRYIN           : in  std_ulogic := '1'; -- 1-bit input: Clock enable input for CARRYINREG
      CECTRL              : in  std_ulogic := '1'; -- 1-bit input: Clock enable input for OPMODEREG and CARRYINSELREG
      CED                 : in  std_ulogic := '1'; -- 1-bit input: Clock enable input for DREG
      CEINMODE            : in  std_ulogic := '1'; -- 1-bit input: Clock enable input for INMODEREG
      CEM                 : in  std_ulogic := '1'; -- 1-bit input: Clock enable input for MREG
      CEP                 : in  std_ulogic := '1'; -- 1-bit input: Clock enable input for PREG
      RSTA                : in  std_ulogic := '0'; -- 1-bit input: Reset input for AREG
      RSTALLCARRYIN       : in  std_ulogic := '0'; -- 1-bit input: Reset input for CARRYINREG
      RSTALUMODE          : in  std_ulogic := '0'; -- 1-bit input: Reset input for ALUMODEREG
      RSTB                : in  std_ulogic := '0'; -- 1-bit input: Reset input for BREG
      RSTC                : in  std_ulogic := '0'; -- 1-bit input: Reset input for CREG
      RSTCTRL             : in  std_ulogic := '0'; -- 1-bit input: Reset input for OPMODEREG and CARRYINSELREG
      RSTD                : in  std_ulogic := '0'; -- 1-bit input: Reset input for DREG and ADREG
      RSTINMODE           : in  std_ulogic := '0'; -- 1-bit input: Reset input for INMODEREG
      RSTM                : in  std_ulogic := '0'; -- 1-bit input: Reset input for MREG
      RSTP                : in  std_ulogic := '0'  -- 1-bit input: Reset input for PREG
   );
   end component;
   
   constant c_num_dsp : integer := (n-1)/48 + 1;
   signal gt_i : std_logic_vector(0 to c_num_dsp-1);
   signal eq_i : std_logic_vector(0 to c_num_dsp-1);
   signal a_i  : std_logic_vector(48*c_num_dsp-1 downto 0) := (others=>'0');
   signal b_i  : std_logic_vector(48*c_num_dsp-1 downto 0) := (others=>'0');
begin
   a_i(a'range) <= a;
   b_i(b'range) <= b;

   g_dsps : for i in 0 to c_num_dsp-1 generate
      signal cout : std_logic_vector(3 downto 0);
   begin
      u_dsp : dsp48e1plus
      generic map(
         -- Feature Control Attributes: Data Path Selection
         A_INPUT             => "DIRECT",   -- Selects A input source, "DIRECT" (A port) or "CASCADE" (ACIN port)
         B_INPUT             => "DIRECT",   -- Selects B input source, "DIRECT" (B port) or "CASCADE" (BCIN port)
         USE_DPORT           => FALSE,      -- Select D port usage (TRUE or FALSE)
         USE_MULT            => "NONE", -- Select multiplier usage ("MULTIPLY", "DYNAMIC", or "NONE")
         USE_SIMD            => "ONE48",    -- SIMD selection ("ONE48", "TWO24", "FOUR12")
         IS_ALUMODE_INVERTED => "0000",
         IS_CARRYIN_INVERTED => '0',
         IS_CLK_INVERTED     => '0',
         IS_INMODE_INVERTED  => "00000",
         IS_OPMODE_INVERTED  => "0000000",
         AUTORESET_PATDET    => "NO_RESET",      -- "NO_RESET", "RESET_MATCH", "RESET_NOT_MATCH"
         MASK                => X"000000000000", -- 48-bit mask value for pattern detect (1=ignore)
         PATTERN             => X"000000000000", -- 48-bit pattern match for pattern detect
         SEL_MASK            => "MASK",          -- "C", "MASK", "ROUNDING_MODE1", "ROUNDING_MODE2"
         SEL_PATTERN         => "PATTERN",       -- Select pattern value ("PATTERN" or "C")
         USE_PATTERN_DETECT  => "PATDET",     -- Enable pattern detect ("PATDET" or "NO_PATDET")
         ACASCREG            => 1, -- Number of pipeline stages between A/ACIN and ACOUT (0, 1 or 2)
         ADREG               => 1, -- Number of pipeline stages for pre-adder (0 or 1)
         ALUMODEREG          => 1, -- Number of pipeline stages for ALUMODE (0 or 1)
         AREG                => 1, -- Number of pipeline stages for A (0, 1 or 2)
         BCASCREG            => 1, -- Number of pipeline stages between B/BCIN and BCOUT (0, 1 or 2)
         BREG                => 1, -- Number of pipeline stages for B (0, 1 or 2)
         CARRYINREG          => 1, -- Number of pipeline stages for CARRYIN (0 or 1)
         CARRYINSELREG       => 1, -- Number of pipeline stages for CARRYINSEL (0 or 1)
         CREG                => 1, -- Number of pipeline stages for C (0 or 1)
         DREG                => 1, -- Number of pipeline stages for D (0 or 1)
         INMODEREG           => 1, -- Number of pipeline stages for INMODE (0 or 1)
         MREG                => 1, -- Number of multiplier pipeline stages (0 or 1)
         OPMODEREG           => 1, -- Number of pipeline stages for OPMODE (0 or 1)
         PREG                => 1  -- Number of pipeline stages for P (0 or 1)
      )
      port map(
         ACOUT               => open,
         BCOUT               => open,
         CARRYCASCOUT        => open,
         MULTSIGNOUT         => open,
         PCOUT               => open,
         OVERFLOW            => open,
         PATTERNBDETECT      => open,
         PATTERNDETECT       => eq_i(i),
         UNDERFLOW           => open,
         CARRYOUT            => cout,-- 4-bit output: Carry output
         P                   => open,
         ACIN                => (others=>'0'),
         BCIN                => (others=>'0'),
         CARRYCASCIN         => '0',
         MULTSIGNIN          => '0',
         PCIN                => (others=>'0'),
         ALUMODE             => "0011", -- z-(x+y+cin) ... c-a:b
         CARRYINSEL          => (others=>'0'),
         CLK                 => clk,
         INMODE              => (others=>'0'),
         OPMODE              => "0110011", --x=a:b, z=c
         A                   => a_i(48*i+29 downto 48*i),    -- : in  std_logic_vector(29 downto 0) := (others=>'0'); -- 30-bit input: A data input
         B                   => a_i(48*i+47 downto 48*i+30), -- : in  std_logic_vector(17 downto 0) := (others=>'0'); -- 18-bit input: B data input
         C                   => b_i(48*i+47 downto 48*i),    -- : in  std_logic_vector(47 downto 0) := (others=>'0'); -- 48-bit input: C data input
         CARRYIN             => '0',
         D                   => (others=>'0'),
         CEA1                => '0', -- 1-bit input: Clock enable input for 1st stage AREG
         CEA2                => '1', -- 1-bit input: Clock enable input for 2nd stage AREG
         CEAD                => '0', -- 1-bit input: Clock enable input for ADREG
         CEALUMODE           => '1', -- 1-bit input: Clock enable input for ALUMODE
         CEB1                => '0', -- 1-bit input: Clock enable input for 1st stage BREG
         CEB2                => '1', -- 1-bit input: Clock enable input for 2nd stage BREG
         CEC                 => '1', -- 1-bit input: Clock enable input for CREG
         CECARRYIN           => '1', -- 1-bit input: Clock enable input for CARRYINREG
         CECTRL              => '1', -- 1-bit input: Clock enable input for OPMODEREG and CARRYINSELREG
         CED                 => '0', -- 1-bit input: Clock enable input for DREG
         CEINMODE            => '0', -- 1-bit input: Clock enable input for INMODEREG
         CEM                 => '0', -- 1-bit input: Clock enable input for MREG
         CEP                 => '1', -- 1-bit input: Clock enable input for PREG
         RSTA                => '0', -- 1-bit input: Reset input for AREG
         RSTALLCARRYIN       => '0', -- 1-bit input: Reset input for CARRYINREG
         RSTALUMODE          => '0', -- 1-bit input: Reset input for ALUMODEREG
         RSTB                => '0', -- 1-bit input: Reset input for BREG
         RSTC                => '0', -- 1-bit input: Reset input for CREG
         RSTCTRL             => '0', -- 1-bit input: Reset input for OPMODEREG and CARRYINSELREG
         RSTD                => '0', -- 1-bit input: Reset input for DREG and ADREG
         RSTINMODE           => '0', -- 1-bit input: Reset input for INMODEREG
         RSTM                => '0', -- 1-bit input: Reset input for MREG
         RSTP                => '0'  -- 1-bit input: Reset input for PREG
      );
      
      g_eq_checks : if c_num_dsp-1 generate
         gt_i(i) <= cout(3); --cout shold trigger on borrow, meaning a was greater than b to cause the borrow since we're doing b-a in the DSP
      else
         gt_i(i) <= cout(3) and and(eq_i(eq_i'left downto i+1)); --if we care about the higher order bits, and_reduce their equality checks
      end generate;
   end generate;

   process(clk)
   begin
      if rising_edge(clk) then
         gt <= or(gt_i);
         eq <= and(eq_i);
      end if;
   end process;

end architecture rtl;