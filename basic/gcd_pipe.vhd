--simple calculation of the greatest common divisor between two configurable size integers.
--The calculation uses Stein's algorithm (binary GCD algorithm) as it is more suitible to hardware than the plain Euclidean algorithm
--the design is pipelined with an input -> output latency of n_a+n_b+2
--note that while the latency increases linearly with the size of the inputs, the complextiy is n**2, with the adders and shifters becoming progressively larger as well as the pipeline lengthening
--with fairly large inputs and fast clock speeds, the math could become problematic for timing and could require further pipelining and DSP inclusion.

--a=0, b=0, although mathematically undefined, will return 0
--n_a is the width of operand a in bits and n_b is the width of operand b in bits.
--n_a must be greater than or equal to n_b, and both n_a and n_b must be greater than or equal to 2.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.general_pkg.all;

entity gcd_pipe is
   generic (
      n_a : positive := 4; --if n_a/=n_b, n_a should always be larger
      n_b : positive := 4 --latency = a+b+2
   );
   port (
      clk : in  std_logic;
      a   : in  std_logic_vector(n_a-1 downto 0);
      b   : in  std_logic_vector(n_b-1 downto 0);
      c   : out std_logic_vector(n_a-1 downto 0)
   );
end entity gcd_pipe;

architecture rtl of gcd_pipe is
   constant c_latency : natural := n_a+n_b;

   signal a_pipe : t_unsigned_vec(0 to c_latency)(n_a-1 downto 0);
   signal b_pipe : t_unsigned_vec(0 to c_latency)(n_b-1 downto 0);
   signal k_pipe : t_unsigned_vec(0 to c_latency+1)(f_log2_ceil(c_latency+1)-1 downto 0);
   
   signal gcd_p : unsigned(n_a-1 downto 0);
   signal gcd_i : unsigned(n_a-1 downto 0);
begin
   assert n_a >= n_b report "n_a must be greater than or equal to n_b" severity failure;
   assert n_a >= 2   report "n_a must be greater than or equal to 2" severity failure;
   assert n_b >= 2   report "n_b must be greater than or equal to 2" severity failure;
   
   a_pipe(0) <= unsigned(a);
   b_pipe(0) <= unsigned(b);
   k_pipe(0) <= (others=>'0');
   
   g_pipe : for i in 0 to c_latency-1 generate
   begin
      process(clk)
      begin
         if rising_edge(clk) then
            a_pipe(i+1) <= a_pipe(i); --default
            b_pipe(i+1) <= b_pipe(i); --default
            k_pipe(i+1) <= (others=>'0');
            if i > 0 then --only assign a reduced subset to permit optimization with the knowledge that max value of k at stage i is i
               k_pipe(i+1)(f_log2_ceil(i+1)-1 downto 0) <= k_pipe(i)(f_log2_ceil(i+1)-1 downto 0); --default        
            end if;
         
            if a_pipe(i)(0)='0' and b_pipe(i)(0)='0' then
               a_pipe(i+1) <= '0' & a_pipe(i)(n_a-1 downto 1);
               b_pipe(i+1) <= '0' & b_pipe(i)(n_b-1 downto 1);
               k_pipe(i+1) <= resize(k_pipe(i)(f_log2_ceil(i+2)-1 downto 0)+1,k_pipe(i)'length); --range reduction to permit optimization
            elsif a_pipe(i)(0)='0' then
               a_pipe(i+1) <= '0' & a_pipe(i)(n_a-1 downto 1);
            elsif b_pipe(i)(0)='0' then
               b_pipe(i+1) <= '0' & b_pipe(i)(n_b-1 downto 1);
            elsif a_pipe(i) > b_pipe(i) then
               a_pipe(i+1) <= '0' & (a_pipe(i)(n_a-1 downto 1)-b_pipe(i)(n_b-1 downto 1));
            else
               b_pipe(i+1) <= '0' & (b_pipe(i)(n_b-1 downto 1)-a_pipe(i)(n_b-1 downto 1)); --only use the b width subsection of a, as we know a is less than or equal to b
            end if;
         end if;
      end process;
   end generate;
   
   process(clk)
   begin
      if rising_edge(clk) then
         k_pipe(c_latency+1) <= k_pipe(c_latency);
      
         gcd_p <= a_pipe(c_latency) and resize(b_pipe(c_latency),n_a); --one of these should be 0
         gcd_i <= shift_left(gcd_p, to_integer(k_pipe(c_latency+1)));
      end if ;
   end process;
   
   c <= std_logic_vector(gcd_i);
end architecture rtl;