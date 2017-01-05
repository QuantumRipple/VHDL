--wrapper for DSP functionality with the 7 series dsp48e1 interface.
--this particular impl is for 7 series parts used with Vivado (XST doesn't include the inversion ports), and therefore uses a native dsp48e1

library ieee;
use ieee.std_logic_1164.all;

library unisim;
use unisim.vcomponents.all;

entity dsp48e1plus is
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
end dsp48e1plus;

architecture wrap of dsp48e1plus is
begin
   DSP48E1_inst : DSP48E1
   generic map (
      A_INPUT             => A_INPUT,
      B_INPUT             => B_INPUT,
      USE_DPORT           => USE_DPORT,
      USE_MULT            => USE_MULT,
      USE_SIMD            => USE_SIMD,
      IS_ALUMODE_INVERTED => IS_ALUMODE_INVERTED,
      IS_CARRYIN_INVERTED => IS_CARRYIN_INVERTED,
      IS_CLK_INVERTED     => IS_CLK_INVERTED,
      IS_INMODE_INVERTED  => IS_INMODE_INVERTED,
      IS_OPMODE_INVERTED  => IS_OPMODE_INVERTED,
      AUTORESET_PATDET    => AUTORESET_PATDET,
      MASK                => MASK,
      PATTERN             => PATTERN,
      SEL_MASK            => SEL_MASK,
      SEL_PATTERN         => SEL_PATTERN,
      USE_PATTERN_DETECT  => USE_PATTERN_DETECT,
      ACASCREG            => ACASCREG,
      ADREG               => ADREG,
      ALUMODEREG          => ALUMODEREG,
      AREG                => AREG,
      BCASCREG            => BCASCREG,
      BREG                => BREG,
      CARRYINREG          => CARRYINREG,
      CARRYINSELREG       => CARRYINSELREG,
      CREG                => CREG,
      DREG                => DREG,
      INMODEREG           => INMODEREG,
      MREG                => MREG,
      OPMODEREG           => OPMODEREG,
      PREG                => PREG
   )
   port map (
      ACOUT               => ACOUT,
      BCOUT               => BCOUT,
      CARRYCASCOUT        => CARRYCASCOUT,
      MULTSIGNOUT         => MULTSIGNOUT,
      PCOUT               => PCOUT,
      OVERFLOW            => OVERFLOW,
      PATTERNBDETECT      => PATTERNBDETECT,
      PATTERNDETECT       => PATTERNDETECT,
      UNDERFLOW           => UNDERFLOW,
      CARRYOUT            => CARRYOUT,
      P                   => P,
      ACIN                => ACIN,
      BCIN                => BCIN,
      CARRYCASCIN         => CARRYCASCIN,
      MULTSIGNIN          => MULTSIGNIN,
      PCIN                => PCIN,
      ALUMODE             => ALUMODE,
      CARRYINSEL          => CARRYINSEL,
      CLK                 => CLK,
      INMODE              => INMODE,
      OPMODE              => OPMODE,
      A                   => A,
      B                   => B,
      C                   => C,
      CARRYIN             => CARRYIN,
      D                   => D,
      CEA1                => CEA1,
      CEA2                => CEA2,
      CEAD                => CEAD,
      CEALUMODE           => CEALUMODE,
      CEB1                => CEB1,
      CEB2                => CEB2,
      CEC                 => CEC,
      CECARRYIN           => CECARRYIN,
      CECTRL              => CECTRL,
      CED                 => CED,
      CEINMODE            => CEINMODE,
      CEM                 => CEM,
      CEP                 => CEP,
      RSTA                => RSTA,
      RSTALLCARRYIN       => RSTALLCARRYIN,
      RSTALUMODE          => RSTALUMODE,
      RSTB                => RSTB,
      RSTC                => RSTC,
      RSTCTRL             => RSTCTRL,
      RSTD                => RSTD,
      RSTINMODE           => RSTINMODE,
      RSTM                => RSTM,
      RSTP                => RSTP
   );
end wrap;