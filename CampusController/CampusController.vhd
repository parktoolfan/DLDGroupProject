Library ieee;

use ieee.std_logic_1164.all;

entity CampusController is
port(	--gpio_0 : inout std_logic_vector(1 downto 0);
		gpio : out std_logic_vector(3 downto 2);
		ledr : out std_logic_vector(1 downto 0);
		sw : in std_logic_vector(1 downto 0)
	);
end CampusController;

architecture a of CampusController is 

begin

	gpio(3) <= sw(0);
	ledr(0) <= sw(0);

end a;
		