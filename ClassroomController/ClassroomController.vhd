Library ieee;

use ieee.std_logic_1164.all;

-- This program is written for the 2017 Spring DLD class at Grove City College. The goal is to create a system which polls classrooms around campus to clooect information from them.
-- Information collected is ClassroomInUse, LightsAreOn, and ProjectorIsOn.
-- ClassroomInUse being a 1 represents that the classroom is being used, all of these signals come from sensors in the classroom that are explained in the writup attached with this code.

-- This VHDL program is written by Theo Stangebye, stangebyeTO1@gcc.edu, April 2017.

-- The classroomController Entity is the component which is being polled. Each classroom will have a classroomController which communicates with at campusController when it's id is selected by the campus controller for polling.  The classroomController will then connect to the communication line and transmit its data in serial to the campus controller.
entity ClassroomController is -- we'll ue classroomControllerHardware as our actual classroomController Simulator
port(	gpio : inout std_logic_vector(39 downto 0);
		ledr : out std_logic_vector(17 downto 0);
		ledg : out std_logic_vector(8 downto 0);
		sw : in std_logic_vector(17 downto 0);
		key : in std_logic_vector (3 downto 0)
	);
end ClassroomController;

-- Our architecture instantiates 4 classroomController components, simulating 4 classrooms which will be polled by a campusController
architecture a of ClassroomController is

	-- Declare the components that we created below.
	Component ClassroomControllerHardware is -- ClassroomControllerHardware is the model which simulates the hardware to be placed in each classroom.
		port (	ClassroomInUse, LightsAreOn, ProjectorIsOn, RX : in std_logic; -- ClassroomInUse, LightsAreOn, and ProjectorIsOn are boolean signals from sensors in the room which give infromation about that classroom's current condition.
					RoomID, OurID : in std_logic_vector(1 downto 0); -- here we are simulating 4 classrooms, so the classroom IDs, only need to be 2 bits wides.  -- RoomID is broadcasted by the CampusController, and OurID is set to the the unique ID of a classroomController in a specific classroom.
					Clk_In : in std_logic; -- the clock signal.
					projectorEnable, LightsEnable, TX, transmitting : out std_logic -- each classroomController has outputs which can disable the lights or projector in a classroom.
					-- The TX bit is used to communicate with the campusController, it is directly connected to the connection line, and is internally set to highZ when it is not a classroomController's turn to communicate with the campusController, (a classroomController communicates when it is polled by the campusController or when it's OURID = RoomId.)
				);
	end Component;

	signal master_clock : std_logic; -- the master signal of the alera board - this is read from another altera board in our case through gpio pin. (see GPIO below)
	signal c0len, c0pen, c1len, c1pen, c2len, c2pen, c3len, c3pen : std_logic; -- c0len is Classroom0, lignts, enable. c2pen is Classroom2, Projector, Enable.  these signals are used internally to interact with the altera board's physical hardware for IO purposes.
	signal sen0u, sen0l, sen0p, sen1u, sen1l, sen1p, sen2u, sen2l, sen2p, sen3u, sen3l, sen3p : std_logic; -- sensor associated with classroom #, sensing use, lights, projector - these repsresent the input sensors to a classroom.
	signal net1RoomID : std_logic_vector(1 downto 0); -- the RoomId on network 1, (in this case, this is the default network since there is only one network.)
	signal net1tx : std_logic; -- the communication line for network 1.
	signal trans0, trans1, trans2, trans3 : std_logic; -- we'll use to display LEDs on the baord when a specific classroomControllerHardware is transmitting, (when it is being polled by the campusController)

begin
	-- GPIO
	-- Read clock from external source.
	master_clock <= gpio(8);
	-- Read roomIds from other altera board using GPIO ports.
	net1RoomID <= gpio(1 downto 0);
	-- TX bit for communicating with CampusController
	gpio(6) <= net1tx;

	-- flash ledg8 with clock signal.
	ledg(8) <= master_clock;

	-- input switches - used to simulate classrom sensor values.
	-- Class 0:
	sen0u <= sw(0); -- classroom0 in Use
	sen0l <= sw(1); -- classroom0 lightsAreOn
	sen0p <= sw(2); -- classroom0 projectorIsOn
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
	ledr(0) <= c0len; -- classroom0 lightsEnabled
	ledr(1) <= c0pen; -- classroom0 projectorEnabled
	ledr(2) <= trans0; -- classroom0 is being polled.
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

	-- we will plot network 1 room id and network 1 tx on ledg
	ledg(1 downto 0) <= net1RoomID;
	ledg(7) <= net1tx;

	-- Instantiate our classrooms.
	Classroom0 : classroomControllerHardware port map(
		ClassroomInUse => sen0u, -- sensor representing whether or not someone is in the room.
		LightsAreOn => sen0l, -- sensor representing whether or not the lights are on the room
		ProjectorIsOn => sen0p, -- sensor representing whether or not the projector is on in the room.
		RX => '0', -- for now, we are not recieving serial from the campusController.
		RoomID => net1RoomID, -- set the roomID in this classroomControllerHardware to be the ID recieved on the GPIO pins.
		OurID => "00", -- set the unique ID of this specific classroomControllerHardware
		Clk_In => master_clock, -- pass our clock signal
		ProjectorEnable => c0pen, -- output enabling the projector
		LightsEnable => c0len, -- ouput enabling the lights.
		TX => net1tx, -- classroom0's communication line.
		transmitting => trans0 -- this signal is true if classroom0 is online on the communication line and is transmitting it's data to the campusController.
	);

		Classroom1 : classroomControllerHardware port map(
		ClassroomInUse => sen1u,
		LightsAreOn => sen1l,
		ProjectorIsOn => sen1p,
		RX => '0',
		RoomID => net1RoomID,
		OurID => "01",
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
		RoomID => net1RoomID,
		OurID => "10",
		Clk_In => master_clock,
		ProjectorEnable => c2pen,
		LightsEnable => c2len,
		TX => net1tx,
		transmitting => trans2
	);

		Classroom3 : classroomControllerHardware port map(
		ClassroomInUse => sen3u,
		LightsAreOn => sen3l,
		ProjectorIsOn => sen3p,
		RX => '0',
		RoomID => net1RoomID,
		OurID => "11",
		Clk_In => master_clock,
		ProjectorEnable => c3pen,
		LightsEnable => c3len,
		TX => net1tx,
		transmitting => trans3
	);

end a;

-- Begin Component Declarations

-- here we declare the classroomControllerHardware which represents the hardware placed in each classroom.
Library ieee;
use ieee.std_logic_1164.all;
Entity ClassroomControllerHardware is -- these signals are explained at line 25.
	port (	ClassroomInUse, LightsAreOn, ProjectorIsOn, RX : in std_logic;
				RoomID, OurID : in std_logic_vector(1 downto 0);
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

	component piso48b is -- this is a parallel input serial output shift register which is 48b wide.
	port (	parallel_In : in std_logic_vector(47 downto 0); -- the 16 bits of input for parallel loading
				SorL : in std_logic; -- the Shift/Load signal. 1 = shift, 0 = load
				clk : in std_logic; -- the clock signal for the DFFs contained in the shift reg.
				q : out std_logic -- we shift out through this bit.
			);
	end component;

	component comparator6b is -- a six bit comparator which only determines whether or not two six bit integers are equal.
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

	signal Equal, LoadShiftReg, txToBus, lastEqual, projectorIsEnabledAndOn, lightsEnabledAndOn: std_logic;
	Signal toLoad : std_logic_vector(47 downto 0);
	-- Equal is an internal signal which is true if the RoomID input matches OURID.
	-- LoadShiftReg tells the classroomControllerHardware when to load its PISO register.
	-- TX to bus stores our tx value for the bus before sending it through a tri_state_buffer.
	-- lastEqual is the equal signal 1 clock cycle ago.
	-- projectorIsEnabledAndOn and lightsEnabledAndOn are signals which are used to simulate the closed loop system created by this hardware's ability to disable the lights and projector.

begin

	-- for indication purposes, show when this classroom is transmitting
	transmitting <= Equal;

	-- Circuitry to determine when we are selected by the BuildingController to Transmit
	classroomComparator : comparator6b port map(
		op1 => "0000" & OurID,
		op2 => "0000" & RoomID,  -- the comparator expects 6b of input but roomId and ourID are only 2 bits now.
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

	-- Finally implement shift out register for parallel in and serial out - used to communicate with campusControllers in serial.
	serialOutReg : piso48b port map(
		parallel_In => toLoad,
		SorL => Not(LoadShiftReg), -- Load is low state.
		clk => Clk_In,
		q => txToBus
	);

	-- specify toLoad
	toLoad <= "1010101010101010" & "00000000" & projectorIsEnabledAndOn & lightsEnabledAndOn & ClassroomInUse & "00000" & "1111111111111111";
	-- these bitstrings come from predetermined serial communication flags.

	-- wire txto bus to tx bus with a tristate buffer
	busBuffer : tri_state_buffer_top Port map (
		A => txToBus,
		En => Equal,
		Y => TX
	);

	-- disable lights and projector when classroom is not in use.
	ProjectorEnable <= ClassroomInUse;
	LightsEnable <= ClassroomInUse;

		-- We simulate that the projector is on or off by doing the following:
	projectorIsEnabledAndOn <= ClassroomInUse and projectorIsOn;
	lightsEnabledAndOn <= ClassroomInUse and lightsAreOn;

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
-- 	in our circuit schematic, we wired two 8 bit shift regeristers together, but here, we can just create a 48b shift register.
Library ieee;
Use ieee.std_logic_1164.all;
Entity piso48b is
	port (	parallel_In : in std_logic_vector(47 downto 0); -- the 16 bits of input for parallel loading
				SorL : in std_logic; -- the Shift/Load signal. 1 = shift, 0 = load
				clk : in std_logic; -- the clock signal for the DFFs contained in the shift reg.
				q : out std_logic -- we shift out through this bit.
			);
end piso48b;
Architecture a of piso48b is
	signal temp : std_logic_vector(47 downto 0);
begin
	-- Note: in this shift regerister, elements are shifted "up" meaning that an item which enters at temp(0) is consecutively shifted down the register to temp(47) at which point it shows up on the output q.
	process(clk) -- 0ur register updates every clock cycle, nothing is asynchronous.
	begin
		if clk'EVENT and clk = '1' then
			if SorL = '0' then -- we should load from our parallel input
				temp <= parallel_In;
			else -- otherwise we should shift down the register.
				temp(47 downto 1) <= temp(46 downto 0);
				temp(0) <= '1';  -- we never need to shift in serial for this project component, so we can simply simulate shifting in a zero.
			end if;
		end if;
	end process;

	q <= temp(47); -- connect our temp vector (the zero element) to our output.
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
