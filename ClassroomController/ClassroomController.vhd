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

	-- Declare the components that we created below.
	component ls74 is
	port(	d, clr, pre, clk : IN std_logic;
		-- d is the data input
		-- clr: ACTIVE LOW: clears the output, q, asynchrnously.
		-- Pre: ACTIVE LOW: sets the output q to 1 asynchronously,
		-- clk is a clock signal (q is typically representitive of what d was 1 clock cycle ago)
			q : out std_logic -- single bit output which is d delayed by 1 clock cycle.
	);
	end component;
	
	component piso16b is
	port (	parallel_In : in std_logic_vector(15 downto 0); -- the 16 bits of input for parallel loading
				SorL : in std_logic; -- the Shift/Load signal. 1 = shift, 0 = load
				clk : in std_logic; -- the clock signal for the DFFs contained in the shift reg.
				q : out std_logic -- we shift out through this bit.
			);
	end component;
	
	component comparator6b is
	port (	op1, op2 : in std_logic_vector(5 downto 0); -- our two 6b inputs.
				equal : out std_logic -- our 1 bit equal signal. 1 if op1 = op2, else 0.
			);
	end component;

	
begin

	-- lets wire up some test components.
	testPiso : piso16b port map (
		parallel_In => sw(15 downto 0),
		SorL => sw(17),
		clk => gpio(0),
		q => ledr(0)
	);
	
	ledg(0) <= gpio(0);

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
		if op1 = op2 then -- if they are equal, represent that on equal.
			equal <= '1';
		else
			equal <= '0';
		end if;
	end process;
end a;

-- Finally, we will need a 16b PISO shift regerister.
-- 	in our circuit schematic, we wired two 8 bit shift regeristers together, but here, we can just create a 16b shift register.
Library ieee;
Use ieee.std_logic_1164.all;
Entity piso16b is
	port (	parallel_In : in std_logic_vector(15 downto 0); -- the 16 bits of input for parallel loading
				SorL : in std_logic; -- the Shift/Load signal. 1 = shift, 0 = load
				clk : in std_logic; -- the clock signal for the DFFs contained in the shift reg.
				q : out std_logic -- we shift out through this bit.
			);
end piso16b;
Architecture a of piso16b is
	signal temp : std_logic_vector(15 downto 0);
begin
	-- Note: in this shift regerister, elements are shifted "down" meaning that an item which enters at temp(15) is consecutively shifted down the register to temp(0) at which point it shows up on the output q.
	process(clk) -- 0ur register updates every clock cycle, nothing is asynchronous.
	begin
		if clk'EVENT and clk = '1' then
			if SorL = '0' then -- we should load from our parallel input
				temp <= parallel_In;
			else -- otherwise we should shift down the register.
				temp(14 downto 0) <= temp(15 downto 1);
				temp(15) <= '0';  -- we never need to shift in serial for this project component, so we can simply simulate shifting in a zero.
			end if;
		end if;
	end process;
	
	q <= temp(0); -- connect our temp vector (the zero element) to our output.
end a;