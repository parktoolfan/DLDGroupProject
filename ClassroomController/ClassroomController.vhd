Library ieee;

use ieee.std_logic_1164.all;

entity ClassroomController is -- we'll ue classroomControllerHardware as our actual classroomController Simulator
port(	gpio : inout std_logic_vector(39 downto 0);
		ledr : out std_logic_vector(17 downto 0);
		ledg : out std_logic_vector(8 downto 0);
		sw : in std_logic_vector(17 downto 0);
		key : in std_logic_vector (3 downto 0)
	);
end ClassroomController;

architecture a of ClassroomController is

	-- Declare the components that we created below.
	Component ClassroomControllerHardware is 
		port (	ClassroomInUse, LightsAreOn, ProjectorIsOn, RX : in std_logic;
					RoomID, OurID : in std_logic_vector(5 downto 0);
					Clk_In : in std_logic;
					projectorEnable, LightsEnable, TX, transmitting : out std_logic
				);
	end Component;
	
	signal master_clock : std_logic;
	signal c0len, c0pen, c1len, c1pen, c2len, c2pen, c3len, c3pen : std_logic; -- classroomNumber, lights or projector enable
	signal sen0u, sen0l, sen0p, sen1u, sen1l, sen1p, sen2u, sen2l, sen2p, sen3u, sen3l, sen3p : std_logic; -- sensor associated with classroom #, sensing use, lights, projector
	signal net1RoomID, net2RoomID : std_logic_vector(5 downto 0);
	signal net1tx, net2tx : std_logic;
	signal trans0, trans1, trans2, trans3 : std_logic;
	
begin
	
	-- GPIO
	-- Clock
	master_clock <= gpio(8);
	-- RoomIDs
	net1RoomID <= gpio(5 downto 0);
	net2RoomID <= gpio(14 downto 9);
	-- TX bits
	gpio(6) <= net1tx;
	gpio(15) <= net2tx;
	
	-- flash on clock
	ledg(8) <= master_clock;
	
	-- input switches
	-- Class 0:
	sen0u <= sw(0);
	sen0l <= sw(1);
	sen0p <= sw(2);
	-- Class 1:
	sen1u <= sw(4);
	sen1l <= sw(5);
	sen1p <= sw(6);
	-- Class 2:
	sen2u <= sw(8);
	sen2l <= sw(9);
	sen2p <= sw(10);
	-- Class 3:
	sen3u <= sw(12);
	sen3l <= sw(13);
	sen3p <= sw(14);
	
	-- Outpus LEDs:
	-- Class 0:
	ledr(0) <= c0len;
	ledr(1) <= c0pen;
	ledr(2) <= trans0;
	-- Class 1:
	ledr(4) <= c1len;
	ledr(5) <= c1pen;
	ledr(6) <= trans1;
	-- Class 2:
	ledr(8) <= c2len;
	ledr(9) <= c2pen;
	ledr(10) <= trans2;
	-- Class 3:
	ledr(12) <= c3len;
	ledr(13) <= c3pen;
	ledr(14) <= trans3;
	
	-- for testing purposes, we will plot network 1 room id and network 1 tx on ledg
	ledg(5 downto 0) <= net1RoomID;
	ledg(7) <= net1tx;
	
	
	Classroom0 : classroomControllerHardware port map(
		ClassroomInUse => sen0u,
		LightsAreOn => sen0l,
		ProjectorIsOn => sen0p,
		RX => '0',
		RoomID => net1RoomID,
		OurID => "000000",
		Clk_In => master_clock,
		ProjectorEnable => c0pen,
		LightsEnable => c0len,
		TX => net1tx,
		transmitting => trans0
	);
	
		Classroom1 : classroomControllerHardware port map(
		ClassroomInUse => sen1u,
		LightsAreOn => sen1l,
		ProjectorIsOn => sen1p,
		RX => '0',
		RoomID => net1RoomID,
		OurID => "000001",
		Clk_In => master_clock,
		ProjectorEnable => c1pen,
		LightsEnable => c1len,
		TX => net1tx,
		transmitting => trans1
	);
	
		Classroom2 : classroomControllerHardware port map(
		ClassroomInUse => sen2u,
		LightsAreOn => sen2l,
		ProjectorIsOn => sen2p,
		RX => '0',
		RoomID => net2RoomID,
		OurID => "000000",
		Clk_In => master_clock,
		ProjectorEnable => c2pen,
		LightsEnable => c2len,
		TX => net2tx,
		transmitting => trans2
	);
	
		Classroom3 : classroomControllerHardware port map(
		ClassroomInUse => sen3u,
		LightsAreOn => sen3l,
		ProjectorIsOn => sen3p,
		RX => '0',
		RoomID => net2RoomID,
		OurID => "000001",
		Clk_In => master_clock,
		ProjectorEnable => c3pen,
		LightsEnable => c3len,
		TX => net2tx,
		transmitting => trans3
	);

end a;

-- Begin Component Declarations

Library ieee;
use ieee.std_logic_1164.all;
Entity ClassroomControllerHardware is 
	port (	ClassroomInUse, LightsAreOn, ProjectorIsOn, RX : in std_logic;
				RoomID, OurID : in std_logic_vector(5 downto 0);
				Clk_In : in std_logic;
				projectorEnable, LightsEnable, TX, transmitting : out std_logic
			);
end ClassroomControllerHardware;

Architecture a of ClassroomControllerHardware is 
	
	-- declare signals and hardware components.
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
	
	component tri_state_buffer_top is
	Port (	A	: in  STD_LOGIC;    -- single buffer input
				EN	: in  STD_LOGIC;    -- single buffer enable
				Y	: out STD_LOGIC    -- single buffer output
			);
	end component;
	
	signal Equal, LoadShiftReg, txToBus, lastEqual : std_logic;
	Signal toLoad : std_logic_vector(15 downto 0);
	
begin
	
	-- for indication purposes, show when this classroom is transmitting
	transmitting <= Equal;
	
	-- Circuitry to determine when we are selected by the BuildingController to Transmit
	classroomComparator : comparator6b port map(
		op1 => OurID,
		op2 => RoomID,
		equal => Equal
	);
	
	-- Circuitry to determine when we should load our shift registers with new data to shift out over serial.
	-- we want to load the first clock cycle after being selected by the Building Controller (first equal cycle)
	RisingEqualDFF : ls74 port map(
		d => equal,
		clr => '1',
		pre => '1',
		clk => Clk_In,
		q => lastEqual
	);
	
	LoadShiftReg <= Not(lastEqual) and equal;
	
	-- Finally implement shift out register
	serialOutReg : piso16b port map(
		parallel_In => toLoad,
		SorL => Not(LoadShiftReg), -- Load is low state.
		clk => Clk_In,
		q => txToBus
	);
	
	-- wire txto bus to tx bus with a tristate buffer
	busBuffer : tri_state_buffer_top Port map (
		A => txToBus,
		En => Equal,
		Y => TX
	);
	
	ProjectorEnable <= ClassroomInUse;
	LightsEnable <= ClassroomInUse;
	
end a;
				

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

-- Tristate Buffer
Library ieee;
use ieee.std_logic_1164.all;
entity tri_state_buffer_top is
	Port( A : in std_logic;    -- single buffer input
			EN : in std_logic;    -- single buffer enable
			Y : out std_logic    -- single buffer output
	);
end tri_state_buffer_top;
architecture Behavioral of tri_state_buffer_top is
	begin
    -- single active low enabled tri-state buffer
	Y <= A when (EN = '1') else 'Z';
end Behavioral;