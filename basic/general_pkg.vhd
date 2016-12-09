library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package general_pkg is
   type t_integer_vec is array (natural range <>) of integer;
   type t_unsigned_vec is array (natural range <>) of unsigned; --note: requires VHDL-2008
   type t_slv_vec is array (natural range <>) of std_logic_vector; --note: requires VHDL-2008
   
   function f_log2_ceil   (a : in integer := 1)  return integer;
   function f_is_pow2     (i : in integer := 1)  return boolean;
   function f_min_integer (a : t_integer_vec)    return integer;
   function f_max_integer (a : t_integer_vec)    return integer;
   function f_gray_to_bin (a : std_logic_vector) return unsigned;
   function f_bin_to_gray (a : unsigned)         return std_logic_vector;
   function f_gray_next   (a : std_logic_vector) return std_logic_vector;
   function f_gray_rom    (n : positive)         return t_slv_vec;
   
end general_pkg;

package body general_pkg is
   function f_log2_ceil (a : in integer := 1) return integer is
   begin
      assert (a <= 2147483647) report "log2_ceil argument too large" severity error;
      assert (a > 0) report "log2_ceil argument too small" severity error;
      for i in 0 to 30 loop
         if a <= 2**i then 
            return i; 
         end if;
      end loop;
      return 31;
   end f_log2_ceil;
   
   function f_is_pow2 (i : in integer := 1) return boolean is
   begin
      return i = 2**f_log2_ceil(i);
   end f_is_pow2;
   
   function f_min_integer (a : t_integer_vec) return integer is
      variable temp : integer;
   begin
      assert a'length > 0 report "min_integer null list" severity error;
      temp := a(0);
      for i in a'range loop
         if a(i) < temp then
            temp := a(i);
         end if;
      end loop;
      return temp;
   end f_min_integer;
   
   function f_max_integer (a : t_integer_vec) return integer is
      variable temp : integer;
   begin
      assert a'length > 0 report "max_integer null list" severity error;
      temp := a(0);
      for i in a'range loop
         if a(i) > temp then
            temp := a(i);
         end if;
      end loop;
      return temp;
   end f_max_integer;
   
   function f_gray_to_bin (a : std_logic_vector) return unsigned is
      variable temp : unsigned(a'range);
   begin
      assert not a'ascending report "gray_to_bin incorrect direction" severity error;
      temp(a'high) := a(a'high);
      for i in a'high-1 downto a'low loop
         temp(i) := a(i) xor temp(i+1); --note the long path of n-1 layers of xor. wide gray counters are slow to convert back to binary
         --this can also be done in log2(n) single layer stages to shorten the long path at the cost of luts (easy to pipeline too!), but that's not implemented here
      end loop;
      return temp;
   end f_gray_to_bin;
   
   function f_bin_to_gray (a : unsigned) return std_logic_vector is
      variable temp : std_logic_vector(a'range);
   begin
      assert not a'ascending report "bin_to_gray incorrect direction" severity error;
      temp(a'high) := a(a'high);
      for i in a'high-1 downto a'low loop
         temp(i) := a(i) xor a(i+1);
      end loop;
      return temp;
   end f_bin_to_gray;
   
   
   function f_gray_next (a : std_logic_vector) return std_logic_vector is
   begin
      return f_bin_to_gray(f_gray_to_bin(a)+1);
   end f_gray_next;
   
   function f_gray_rom (n : positive) return t_slv_vec is
      variable temp : t_slv_vec(0 to 2**n-1)(n-1 downto 0);
   begin
      for i in temp'range loop
         temp(i) := f_gray_next(std_logic_vector(to_unsigned(i,n)));
      end loop;
      return temp;
   end f_gray_rom;
   
end package body general_pkg;