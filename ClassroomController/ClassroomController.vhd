Library ieee;

use ieee.std_logic_1164.all;

entity ClassroomController is -- we'll ue classroomControllerHardware as our actual classroomController Simulator
port(	gpio : inout std_logic_vector(7 downto 0);
		ledr : out std_logic_vector(17 downto 0);
		ledg : out std_logic_vector(8 downto 0);
		sw : in std_logic_vector(17 downto 0);
		key : in std_logic_vector (3 downto 0)
	);
end ClassroomController;

architecture a of ClassroomController is

begin

end a;

-- Begin Component Declarations

-- Create a 74x74 chip a DFF
-- This component intends to simulate the behaviors of a 74x74 chipset.
Library ieee;
use ieee.std_logic_1164.all;
Entity ls74 is
	port(	d, clr, pre, clk : IN std_logic;
		-- d is the data input
		-- clr: ACTIVE LOW: clears the output, q, asynchrnously.
		-- Pre: ACTIVE LOW: sets the output q to 1 asynchronously,
		-- clk is a clock signal (q is typically representitive of what d was 1 clock cycle ago)
			q : out std_logic -- single bit output which is d delayed by 1 clock cycle.
	);
end ls74;
Architecture a of ls74 is
begin
	Process(clk, clr, pre) -- the DFF should update its output when any of these change.
	begin
		if clr = '0' then	-- preset q to zero, reguardless of d.
			q <= '0'; -- note that clr and pre are active low.
		elsif pre = '0' then  -- preset q to zero, reguardless of d.
			q <= '1';
		elsif clk'EVENT and clk = '1' then -- mimic d 1 clock cycle ago on q.
			if d = '1' then
				q <= '1';
			else
				q <= '0';
			end if;
		end if;
	end process;
End a;