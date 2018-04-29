library ieee;
use ieee.std_logic_1164.all;

entity sanitycheck is 
	port (gpio : inout Std_logic_vector(30 downto 25);
			key : in std_logic_vector(0 downto 0)
			);
end sanitycheck;

architecture a of sanitycheck is
begin

gpio(30) <= '1';

end a;