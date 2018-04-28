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

-- We also need a 6 bit comparator.  In actual hardware, this would likely be two 74x85s in series but here we will make our own 6b comparator.
-- We only need to know if the two operands are equal, so we'll leave out greater than/ less than capabilities.
Library ieee;
Use ieee.std_logic_1164.all;
Entity comparator6b is
	port (	op1, op2 : in std_logic_vector(5 downto 0); -- our two 6b inputs.
				equal : out std_logic -- our 1 bit equal signal. 1 if op1 = op2, else 0.
			);
end comparator6b;
Architecture a of comparator6b is 
begin
	Process (op1, op2)
	begin
		if op1 = op2 then -- if they are equal, represent that on q.
			q <= '1';
		else
			q <= '0';
		end if;
	end process;
end a;