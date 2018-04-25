Library ieee;

use ieee.std_logic_1164.all;

entity CampusController is
port(	gpio : inout std_logic_vector(3 downto 2);
		ledr : out std_logic_vector(17 downto 0);
		sw : in std_logic_vector(17 downto 0);
		key : in std_logic_vector (3 downto 0)
	);
end CampusController;

architecture a of CampusController is

	-- TESTING COMPONENT DECLARATIONS
	component ls74 is
		port(	d, clr, pre, clk : in std_logic;
				q : out std_logic
		);
	end component;

begin

	gpio(3) <= sw(0);
	ledr(0) <= sw(0);
	ledr(1) <= gpio(2);

	-- TESTING COMPONENT CODES:::
	-- TEST PASSES: test74: ls74  port map (d => sw(7), clr => sw(8), pre => sw(9), clk => key(0), q => ledr(5));

end a;


-- Create a 74x74 chip a DFF
Library ieee;
use ieee.std_logic_1164.all;
Entity ls74 is
	port(	d, clr, pre, clk : IN std_logic;
			q : out std_logic
	);
end ls74;
Architecture a of ls74 is
begin
	Process(clk, clr, pre)
	begin
		if clr = '0' then
			q <= '0';
		elsif pre = '0' then
			q <= '1';
		elsif clk'EVENT and clk = '1' then
			if d = '1' then
				q <= '1';
			else
				q <= '0';
			end if;
		end if;
	end process;
End a;

-- Create RegisterFile Components:
-- 2 to 4 decoder

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
entity ls139 is
	Port (
		A0 : in std_logic;
		A1 : in std_logic;
		Q0 : out std_logic;
		Q1 : out std_logic;
		Q2 : out std_logic;
		Q3 : out std_logic);
end ls139;

architecture Behavioral of ls139 is
	begin
		Q0<= ((not A0) and (not A1));
		Q1<= (A0 and (not A1));
		Q2<= ((not A0) and A1);
		Q3<= (A0 and A1);
end Behavioral;