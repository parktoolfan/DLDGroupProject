Library ieee;
use ieee.std_logic_1164.all;

entity BuildingController is
port(	gpio : inout std_logic_vector(39 downto 0);
		ledr : out std_logic_vector(17 downto 0);
		sw : in std_logic_vector(17 downto 0);
		key : in std_logic_vector (3 downto 0);
		ledg : out std_logic_vector(8 downto 0)
	);
end BuildingController;

architecture a of BuildingController is

	-- SIPO shift register for reading in from ClassroomInUse
	component SIPO_A_shift is
		port(clk, clr, A : in std_logic;
	      PO : out std_logic_vector(15 downto 0)
				);
	end component SIPO_A_shift;

	-- ls 161, a 4 bit counter with asynchronous clears
	component asynch_counter is
		port(clk, CLR, EN, Load_L : in std_logic;
			load_in: in std_logic_vector(3 downto 0);
			RCO: out std_logic;
			Q: out std_logic_vector(3 downto 0));
	end component;

	-- DFFs
	component ls74 is
	port(	d, clr, pre, clk : IN std_logic;
		-- d is the data input
		-- clr: ACTIVE LOW: clears the output, q, asynchrnously.
		-- Pre: ACTIVE LOW: sets the output q to 1 asynchronously,
		-- clk is a clock signal (q is typically representitive of what d was 1 clock cycle ago)
			q : out std_logic -- single bit output which is d delayed by 1 clock cycle.
	);
	end component;

	-- comparator
	component Comparator is
			port(A, B: in std_logic_vector(3 downto 0);
					A_EQ_B: out std_logic
			);
	end component Comparator;

	-- 16 bit wide multiplexer
	component Mux is
			port(S0, S1 : in std_logic;
				 A, B, C, D: in std_logic_vector(15 downto 0);
				  Y: out std_logic_vector(15 downto 0)
				);
	end component Mux;

	-- our PISO output shift register
	component PISO_shift is
		port(S_L, SI, clk, clr  : in std_logic;
			 PI: in std_logic_vector(15 downto 0);
			  SO: out std_logic);
	end component PISO_shift;

	-- tristate Buffer
	component tri_state_buffer_top is
		Port (	A	: in  STD_LOGIC;    -- single buffer input
					EN	: in  STD_LOGIC;    -- single buffer enable
					Y	: out STD_LOGIC    -- single buffer output
		);
	end component;

	-- Register file component for our Database
	component register_file is
		port(	src_s0 : in std_logic; --read select bits, room ids least significant bits
				src_s1 : in std_logic;
				des_A0 : in std_logic; --write select bits
				des_A1 : in std_logic;
				writeToReg : in std_logic;	--write command
				Clk : in std_logic;
				data_src : in std_logic; -- wire to 0
				data : in std_logic_vector(3 downto 0); --0 and three bits of room data (data in)
				reg0 : out std_logic_vector(3 downto 0);
				reg1 : out std_logic_vector(3 downto 0);
				reg2 : out std_logic_vector(3 downto 0);
				reg3 : out std_logic_vector(3 downto 0);
				selectedData : out std_logic_vector(3 downto 0) --data of selected register
				);
	end component register_file;

	-- SIGNALS for external IO
	signal rx1, rx2, tx1, tx2, master_clock: std_logic;
	signal buildingID, ourID : std_logic_vector(2 downto 0);
	signal roomID : std_logic_vector(5 downto 0);

	-- Internal Signals
	Signal ClassroomStream : std_logic_vector(15 downto 0);
	Signal aux, writeToDB, state_inc : std_logic;
		-- aux is anded from parallel inputs and tells when the input from the classroomController is ready for reading.
		-- write to DB tells when to write to the Reg file.
		-- use state_inc to increment the FSM
	Signal RisingEqual, rco_2, rco_1, load, equal, lastEqual, txToBus : std_logic;
	Signal Rst_State_count : std_logic; -- when state is greater than 0011.
	Signal state, clockCycle, regDataOut : std_logic_vector(3 downto 0);
	Signal multiplexedOutput : std_logic_vector(15 downto 0);

	-- Test SIGNALS
	Signal r0, r1, r2, r3 : std_logic_vector(3 downto 0);
begin

	-- Serial in from Classrooms
	Data_in: SIPO_A_SHIFT port Map(
		clk => master_clock,
		A => Rx1,
		PO => ClassroomStream, -- ClassroomStream(15 is newest, 0 is the oldest)
		clr => '0'
	);

	-- combinational logic to tell when bitstrings are alligned
	--aux <= ClassroomStream(4 downto 0) = "11100" and ClassroomStream(14 downto 8) = "1111111"; <- this is what we expect
	aux <= ClassroomStream(4) and ClassroomStream(3) and ClassroomStream(2) and
		Not(ClassroomStream(1)) and Not(ClassroomStream(0)) and
		ClassroomStream(14) and ClassroomStream(13) and ClassroomStream(12) and
		ClassroomStream(11) and ClassroomStream(10) and ClassroomStream(9) and
		ClassroomStream(8);

	-- Combinational logic to determine when we should write to our db
	-- write when aux and state 0001.
	writeToDB <= aux and Not(state(3)) and Not(state(2)) and Not(state(1)) and state(0);

	-- Implement State counter
	StateCounter : asynch_counter port map (
		clk => state_inc,
		CLR => RisingEqual,
		EN => '1',
		Load_L => Not(Rst_State_count),
		load_in => "0011",
		Q => state
	);

	-- reset state counter when we enter a state greater than "0011"
	Rst_State_count <= state(3) or state(2);

	--State_inc combinational logic
	state_inc <= (RCO_2 and not(state(0)) and not(state(1)) and not(state(2)) and not(state(3)))
		or (rco_1) or (rco_2 and not(state(0)) and not(state(1)) and state(2) and not(state(3)));

	-- comb for load
	load <= state_inc or RCO_2;

	-- we want to load the first clock cycle after being selected by the Building Controller (first equal cycle)
	RisingEqualDFF : ls74 port map(
		d => equal,
		clr => '1',
		pre => '1',
		clk => master_clock,
		q => lastEqual
	);

	RisingEqual <= equal and Not(lastEqual);

	-- Clock cycle counter
	clockCounter : asynch_counter port map (
		clk => master_clock,
		CLR => RisingEqual,
		EN => equal,
		Load_L => '1',
		load_in => "0000",
		Q => clockCycle
	);

	-- combinational logic for RCO2
	rco_2 <= clockCycle(3) and clockCycle(2) and clockCycle(1) and clockCycle(0);

	-- comparator for equals
	selectedForTransmission : comparator port map(
		A => OurID & '0',
		B => BuildingId & '0',
		A_EQ_B => equal
	);

	-- 16 bit multiplexer
	outputMux : Mux port map(
		s0 => state(0),
		s1 => state(1),
		A => "1010101010101010",
		B => '0' & RoomID & '0' & regDataOut(2 downto 0) & "00000",
		C => "1111111111111111",
		D => "1010101010101010",
		Y => multiplexedOutput
	);

-- output shift reg
	outputShifter : PISO_shift Port map (
		S_L => Not(load), -- load is the active low state
		SI => '0',
		clk => master_clock,
		clr => '0',
		PI => multiplexedOutput,
		SO => txToBus
	);

	-- wire output to bus
	-- wire txto bus to tx bus with a tristate buffer
	busBuffer : tri_state_buffer_top Port map (
			A => txToBus,
			En => equal,
			Y => TX2
	);

	-- Database
	database : register_file port map (
		src_s0 => RoomID(0),
		src_s1 => RoomID(1),
		des_A0 => RoomID(0),
		des_A1 => RoomID(1),
		writeToReg => writeToDB,
		Clk => master_clock,
		data_src => '0',
		data => '0' & ClassroomStream(11 downto 9),
		reg0 => r0,
		reg1 => r1,
		reg2 => r2,
		reg3 => r3,
		selectedData => regDataOut
	);

-- BEGIN IO
	-- fectch master clock signal, and flash clock LED
	master_clock <= gpio(5);
	ledg(8) <= master_clock;
	-- send clock signal to ClassroomInUse
	gpio(14) <= master_clock;

	-- wire our building to GPIO Pins
	rx1 <= gpio(13);
	gpio(12) <= tx1;
	gpio(11 downto 6) <= roomID;

	-- Show what roomID we're on
	ledg(5 downto 0) <= roomID;


	end a;

-- entity BuildingController is
-- port(	gpio : inout std_logic_vector(39 downto 0);
-- 		ledr : out std_logic_vector(17 downto 0);
-- 		sw : in std_logic_vector(17 downto 0);
-- 		key : in std_logic_vector (3 downto 0);
-- 		ledg : out std_logic_vector(8 downto 0)
-- 	);
-- end BuildingController;
--
-- architecture a of BuildingController is
--
-- 	component BuildingHardware is
-- 		port(Rx1, Rx2, clk_in : IN std_logic;
-- 			Building_ID : IN std_logic_vector(2 downto 0);
-- 			clk_out, Tx1, Tx2 : out std_logic;
-- 			room_data_out : out std_logic_vector(3 downto 0);
-- 			Room_ID : out std_logic_vector(5 downto 0);
-- 			RegisterContents : out std_logic_vector(7 downto 0)
-- 			);
-- 	end component BuildingHardware;
--
-- 	signal A_rx1, A_rx2, B_rx1, B_rx2, to_clk_in: std_logic;
-- 	signal to_building_id0, to_building_id1: std_logic_vector(2 downto 0);
-- 	signal net1roomID, net2roomID : std_logic_vector(5 downto 0);
--
-- begin
--
-- 		building_A: BuildingHardware Port map (	clk_in => to_clk_in ,
-- 										clk_out => gpio(14),
-- 										Tx1 => gpio(12),
-- 										Tx2 => gpio(3),
-- 										Rx1 => A_rx1,
-- 										Rx2 => A_rx2,
-- 										Building_ID => to_building_id0,
-- 										Room_ID => net1roomID,
-- 										room_data_out => ledr( 3 downto 0),
-- 										RegisterContents => ledr(17 downto 10)
-- 									);
--
-- 		building_B: BuildingHardware Port map (	clk_in => to_clk_in,
-- 										clk_out => gpio(23),
-- 										Tx1 => gpio(21),
-- 										Tx2 => gpio(3),
-- 										Rx1 => B_rx1,
-- 										Rx2 => B_rx2,
-- 										Building_ID => to_building_id1,
-- 										Room_ID => gpio(20 downto 15),
-- 										room_data_out => ledr( 7 downto 4));
-- 	-- get master clock signal
-- 	to_clk_in <= gpio(5);
--
-- 	-- wire up building a
-- 	A_rx1 <= gpio(13);
-- 	A_rx2 <= gpio(4);
-- 	gpio(11 downto 6) <= net1roomID;
--
-- 	-- wire up building b
-- 	B_rx1 <= gpio(22);
-- 	B_rx2 <= gpio(4);
--
-- 	Ledg(8) <= to_clk_in;
--
-- 	-- Testign LEDs
-- 	ledg(5 downto 0) <= net1roomID;
--
--
-- 	end a;




-- --Building hardware, one for each building
-- library ieee;
-- use ieee.std_logic_1164.all;
-- Entity BuildingHardware is
-- 	port(Rx1, Rx2, clk_in : IN std_logic;
-- 			Building_ID : IN std_logic_vector(2 downto 0);
-- 			clk_out, Tx1, Tx2 : out std_logic;
-- 			room_data_out : out std_logic_vector(3 downto 0);
-- 			Room_ID : out std_logic_vector(5 downto 0);
-- 			RegisterContents : out std_logic_vector(7 downto 0)
-- 	);
-- end BuildingHardware;
--
-- architecture b of BuildingHardware is
--
-- 	component SIPO_A_shift is
-- 		port(clk, clr, A : in std_logic;
-- 	      PO : out std_logic_vector(15 downto 0)
-- 				);
-- 	end component SIPO_A_shift;
--
-- 	component counter is
-- 		port(clk, CLR, EN : in std_logic;
-- 			 RCO: out std_logic;
-- 	       Q: out std_logic_vector(3 downto 0)
-- 				);
-- 	end component counter;
--
-- 	component register_file is
-- 		port(	src_s0 : in std_logic; --read select bits, room ids least significant bits
-- 				src_s1 : in std_logic;
-- 				des_A0 : in std_logic; --write select bits
-- 				des_A1 : in std_logic;
-- 				writeToReg : in std_logic;	--write command
-- 				Clk : in std_logic;
-- 				data_src : in std_logic; -- wire to 0
-- 				data : in std_logic_vector(3 downto 0); --0 and three bits of room data (data in)
-- 				reg0 : out std_logic_vector(3 downto 0);
-- 				reg1 : out std_logic_vector(3 downto 0);
-- 				reg2 : out std_logic_vector(3 downto 0);
-- 				reg3 : out std_logic_vector(3 downto 0);
-- 				selectedData : out std_logic_vector(3 downto 0) --data of selected register
-- 				);
-- 	end component register_file;
--
-- 	component tri_state_buffer_top is
-- 		Port (	A	: in  STD_LOGIC;    -- single buffer input
-- 					EN	: in  STD_LOGIC;    -- single buffer enable
-- 					Y	: out STD_LOGIC    -- single buffer output
-- 		);
-- 	end component;
--
-- 	component ls74 is
-- 		port(	d, clr, pre, clk : IN std_logic;
-- 				q : out std_logic
-- 				);
-- 	end component ls74;
--
-- 	component asynch_counter is
-- 		port(clk, CLR, EN, Load_L : in std_logic;
-- 			 	load_in: in std_logic_vector(3 downto 0);
-- 			 	RCO: out std_logic;
-- 			  Q: out std_logic_vector(3 downto 0)
-- 				);
-- 	end component asynch_counter;
--
-- 	component Comparator is
-- 			port(A, B: in std_logic_vector(3 downto 0);
-- 				  A_EQ_B: out std_logic
-- 			);
-- 	end component Comparator;
--
-- 	component Mux is
-- 			port(S0, S1 : in std_logic;
-- 				 A, B, C, D: in std_logic_vector(15 downto 0);
-- 				  Y: out std_logic_vector(15 downto 0)
-- 				);
-- 	end component Mux;
--
-- 	component PISO_shift is
-- 		port(S_L, SI, clk, clr  : in std_logic;
-- 			 PI: in std_logic_vector(15 downto 0);
-- 			  SO: out std_logic);
-- 	end component PISO_shift;
--
-- 	Signal room0Data, room1Data : std_logic_vector(3 downto 0);
-- 	signal aux_1, aux_2, write_sig, load, rco_1, rco_2, state_inc, equals,
-- 	old_equals, rising_equals, reset_st_count, roomcount_clock, tx2buffer: std_logic;
-- 	signal state: std_logic_vector(1 downto 0);
-- 	signal room_data, our_id, build_id : std_logic_vector(2 downto 0);
-- 	signal room_id_num, st_count_out, to_our_id, to_build_id: std_logic_vector(3 downto 0);
-- 	signal SIPO_out, mux_out: std_logic_vector(15 downto 0);
--
-- 	begin
--
-- 		-- send clock data out.
-- 		clk_out <= clk_in;
--
-- 		Data_in: SIPO_A_SHIFT port Map(
-- 			clk => clk_in,
-- 			A => Rx1,
-- 			PO => SIPO_out,
-- 			clr => '0'
-- 		); --clr?
-- 		room_counter: counter port Map(
-- 			clk => roomcount_clock, EN => '1',
-- 			CLR => state_inc, RCO => rco_1,
-- 			Q => room_id_num
-- 		);
-- 		data_storage: register_file port Map(
-- 			data =>  '0' & room_data,
-- 			Clk => clk_in,
-- 			src_s0 => room_id_num(0),
-- 			src_s1 => '0',
-- 			writeToReg => write_sig,
-- 			data_src => '0',
-- 			des_A0 => room_id_num(0),
-- 			des_A1 => '0',
-- 			reg0 => room0Data,
-- 			reg1 => room1Data
-- 		);	--dunno about other in/out
--
-- 		-- set register contents for testing:
-- 		RegisterContents <= room0Data & room1Data;
--
--
-- 		dff: ls74 port Map(
-- 			d => equals,
-- 			clk => clk_in,
-- 			q => old_equals,
-- 			clr => '0',
-- 			pre => '0'
-- 		);
-- 		state_counter: asynch_counter port map(
-- 			clk => state_inc,
-- 			Load_L => reset_st_count,
-- 			CLR => rising_equals,
-- 			EN => '1',
-- 			load_in => "1100",
-- 			Q => st_count_out
-- 		);
-- 		clockcycle_counter: asynch_counter port map(
-- 			clk => clk_in,
-- 			Load_L => '0',
-- 			CLR => rising_equals,
-- 			EN => equals,
-- 			load_in => "1100",
-- 			Q => st_count_out,
-- 			RCO => rco_2
-- 		);
--
-- 		-- the comparator wanted 4 bit signals
-- 		to_our_id <= '0' & our_id;
-- 		to_build_id <= '0' & build_id;
--
-- 		ID_comparator: Comparator port map(
-- 			A => to_our_id,
-- 			B => to_build_id,
-- 			A_EQ_B => equals
-- 		);
-- 		shift_load: Mux port map(
-- 			S0 => state(0),
-- 			S1 => state(1),
-- 			A => "1010101010101010",
-- 			B => "000" & room_id_num & "0" & room_data & "00000",
-- 			C => "0000000000000000",
-- 			D => "1010101010101010",
-- 			Y => mux_out
-- 		);
-- 		shift_output: PISO_shift port map (
-- 			S_L => load,
-- 			SI => '0',
-- 			clr =>'0',
-- 			clk => clk_in,
-- 			PI => mux_out,
-- 			SO => tx2buffer
-- 		);
--
-- 		-- wire txto bus to tx bus with a tristate buffer
-- 		busBuffer : tri_state_buffer_top Port map (
-- 				A => tx2buffer,
-- 				En => equals,
-- 				Y => TX2
-- 		);
--
-- 		--aux_1 <= SIPO_out(11) AND SIPO_out(12) AND SIPO_out(13) AND NOT(SIPO_out(14)) AND NOT(SIPO_out(15));
-- 		--aux_2 <= C
-- 		-- SIPO_out(1) AND SIPO_out(2) AND SIPO_out(3) AND SIPO_out(4) AND SIPO_out(5) AND SIPO_out(6) AND SIPO_out(7);
-- 	 	process(SIPO_out, aux_1,aux_2, state, write_sig, rco_2, rco_1, equals, old_equals,st_count_out, state_inc)
-- 			Begin
-- 				if (SIPO_out(15 downto 11) = "00111") then
-- 					aux_1 <= '1';
-- 				else
-- 					aux_1 <= '0';
-- 			  end if;
--
-- 				if ( SIPO_out (7 downto 1) = "1111111") then
-- 						aux_2 <= '1';
-- 				else
-- 					aux_2 <= '0';
-- 				end if;
--
-- 				if ( aux_1 = '1' AND aux_2 = '1' AND state = "01") then
-- 						write_sig <= '1';
-- 				else
-- 						write_sig <= '0';
-- 				end if;
--
-- 				if (write_sig = '1' OR (rco_2 = '1' AND state ="01")) then
-- 					roomcount_clock <= '1';
-- 				else
-- 					roomcount_clock <= '0';
-- 				end if;
--
-- 				if equals = '1' AND old_equals = '0' then
-- 					rising_equals <= '1';
-- 				else
-- 					rising_equals <= '0';
-- 				end if;
--
-- 				if (rco_2 = '1' AND state = "00") OR rco_1 = '1' OR (rco_2 = '1' AND state = "10") then
-- 					state_inc <= '1';
-- 				else
-- 					state_inc <= '0';
-- 				end if;
--
-- 				if st_count_out(3) = '1' OR st_count_out(2) = '1' then
-- 					reset_st_count <= '1';
-- 				else
-- 					reset_st_count <= '0';
-- 				end if;
--
-- 				if  state_inc = '1' OR rco_2 ='1' then
-- 					load <= '1';
-- 				else
-- 					load <= '0';
-- 				end if;
--
-- 		end process;

		--roomcount_clock <= write_sig OR (rco_2 And state = "01");

		--	rising_equals <= equals AND NOT(old_equals);

		--	state_inc <= (rco_2 AND state = "00") OR rco_1 OR (rco_2 AND state = "10");

		--reset_st_count <= st_count_out(3) OR st_count_out(2);

		--	load <= state_inc OR rco_2;

		-- circuit diagram inplementation goes here


--	end b;



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


--16 bit Serial in/Parallel out with asynchronous clear, not this is 2 74x164 chips
library ieee;
use ieee.std_logic_1164.all;

entity SIPO_A_shift is

	port(clk, clr, A : in std_logic;
      PO : out std_logic_vector(15 downto 0));
end SIPO_A_shift;

architecture d of SIPO_A_shift is

	signal tmp: std_logic_vector(15 downto 0);

begin
	process (clk, clr)
		begin
			if (clr = '1') then
				tmp <= "0000000000000000";
			elsif (clk'event and Clk='1') then
				-- items are shifted from 15 towards 1 on the parallel side.
				tmp(14 downto 0) <= tmp(15 downto 1);
				tmp(15) <= A;
			end if;
	end process;
	PO <= tmp;
end d;

-- 4 bit up counter 74x163
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

entity counter is
  port(clk, CLR, EN : in std_logic;
		 RCO: out std_logic;
       Q: out std_logic_vector(3 downto 0));
end counter;
architecture e of counter is
  signal tmp: std_logic_vector(3 downto 0);
  begin
    process (clk, CLR)
      begin

        if (clk'event and clk='1') then

			if (CLR='1') then
          tmp <= "0000";

         elsif (EN='1') then
            tmp <= tmp + 1;

			elsif (tmp = "0001") then
				RCO <= '1';
				tmp <= "0000";

         end if;
		  end if;
    end process;
    Q <= tmp;
end e;


-- 4 bit up counter w asynchronous clears and load signal 74x161
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

entity asynch_counter is
  port(clk, CLR, EN, Load_L : in std_logic;
		load_in: in std_logic_vector(3 downto 0);
		RCO: out std_logic;
		Q: out std_logic_vector(3 downto 0));
end asynch_counter;
architecture e of asynch_counter is
  signal tmp, tmp_in: std_logic_vector(3 downto 0);
  begin
		process (clk, CLR)
		begin
			if CLR = '1' then
				tmp <= "0000";
			elsif (en = '1') then
				if (clk'event and clk = '1') then
					if Load_L = '0' then -- we should load
						tmp <= load_in;
					elsif tmp = "1111" then -- overflow
						tmp <= "0000";
					else
						tmp <= tmp + 1;
					end if;
				end if;
			end if;
			if tmp = "1111" then
				RCO <= '1';
			end if;
		end Process;
		Q <= tmp;

end e;

-- 64-to-16 mux, note this is 8 2-bit wide MUX 74x153
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

entity Mux is
  port(S0, S1 : in std_logic;
		 A, B, C, D: in std_logic_vector(15 downto 0);
		  Y: out std_logic_vector(15 downto 0));
end Mux;

architecture f of Mux is
	signal tmp: std_logic_vector(15 downto 0);
	begin
		process(S0, S1)
			begin
			if ( S1 = '0' AND S0 = '0') then
				tmp <= A;
			elsif ( S1 = '0' AND S0 = '1') then
				tmp <= B;
			elsif ( S1 = '1' AND S0 = '0') then
				tmp <= C;
			elsif ( S1 = '1' AND S0 = '1') then
				tmp <= D;
			end if;
		end process;
		Y <= tmp;
	end f;



-- 4-bit comparator 74x85
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
entity Comparator is
  port(A, B: in std_logic_vector(3 downto 0);
		  A_EQ_B: out std_logic);
end Comparator;
architecture g of Comparator is
	begin
		--signal tmp_A, tmp_B: std_logic_vector(3 downto 0);
		process(A, B)
			begin
				if ( A = B) then
					A_EQ_B <= '1';
				else
					A_EQ_B <= '0';
				end if;
			end process;
	end g;

-- 16 bit PISO shift register, note this is 2 74x166 chips
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

entity PISO_shift is
  port(S_L, SI, clk, clr  : in std_logic;
		 PI: in std_logic_vector(15 downto 0);
		  SO: out std_logic);
end PISO_shift;
architecture h of PISO_shift is
	signal tmp: std_logic_vector(15 downto 0);
	begin
		process(clk, clr)
			 begin
				if (clr = '1') then
				tmp <= "0000000000000000";
				elsif (clk'event and Clk='1') then
					if (S_L ='1') then
						tmp(14 downto 0) <= tmp(15 downto 1); -- items flow from 15 to 0
						tmp(15) <= SI;
					elsif (S_L = '0') then
					tmp <= PI;
					end if;
				end if;
			end process;
			SO <= PI(0);
	end h;


-- Add tristate buffer code
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

	-- ///////////////////////////////////\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
-- Create RegisterFile Components:
-- This code comes from the guide at https://www.scss.tcd.ie/Michael.Manzke/CS2022/CS2022_vhdl_eighth.pdf
-- 2 to 4 decoder
-- NOTE THIS IS ONLY ONE HALF of a ls139 chip.
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
entity decoder_2to4 is
	Port (
		Enable : IN std_logic; -- I'm adding an enable signal that we can turn high to write to the regerister file.
		A0 : in std_logic;
		A1 : in std_logic;
		Q0 : out std_logic;
		Q1 : out std_logic;
		Q2 : out std_logic;
		Q3 : out std_logic);
end decoder_2to4;
architecture Behavioral of decoder_2to4 is
	begin
		Q0<= ((not A0) and (not A1)) and Enable;
		Q1<= (A0 and (not A1)) and Enable;
		Q2<= ((not A0) and A1) and Enable;
		Q3<= (A0 and A1) and Enable;
end Behavioral;

-- 4 bit wide 2 to 1 mux
-- this is 1 half of a 74x157 mux
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
entity mux2_4bit is
	port (	In0 : in std_logic_vector(3 downto 0);
				In1 : in std_logic_vector(3 downto 0);
s : in std_logic;
				Z : out std_logic_vector(3 downto 0)
			);
end mux2_4bit;
architecture Behavioral of mux2_4bit is
begin
	Z <= In0 when S='0' else
	In1 when S='1'else
	"0000";
end Behavioral;

-- 4 bit wide 4 to 1 MUX
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
entity mux4_4bit is
Port (	In0, In1, In2, In3 : in std_logic_vector(3 downto 0);
			S0, S1 : in std_logic;
			Z : out std_logic_vector(3 downto 0)
		);
end mux4_4bit;
architecture Behavioral of mux4_4bit is
begin
	Z <= In0 when S0='0' and S1='0' else
	In1 when S0='1' and S1='0' else
	In2 when S0='0' and S1='1' else
	In3 when S0='1' and S1='1' else
	"0000";
end Behavioral;

-- Finally, here is the register component
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
entity reg4 is
	port ( D : in std_logic_vector(3 downto 0);
		load, Clk : in std_logic;
		Q : out std_logic_vector(3 downto 0)
	);
end reg4;
architecture Behavioral of reg4 is begin
	process(Clk)
	begin
		if (rising_edge(Clk)) then
			if load='1' then
				Q<=D;
			end if;
		end if;
	end process;
end Behavioral;

-- Use the register component to create a register file component:
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
entity register_file is
	Port (	src_s0 : in std_logic;
				src_s1 : in std_logic;
				des_A0 : in std_logic;
				des_A1 : in std_logic;
				writeToReg : in std_logic; -- I added an enable bit to the 2 to 4 decoder so that i can have a write signal here.
				Clk : in std_logic;
				data_src : in std_logic;
				data : in std_logic_vector(3 downto 0);
				reg0 : out std_logic_vector(3 downto 0);
				reg1 : out std_logic_vector(3 downto 0);
				reg2 : out std_logic_vector(3 downto 0);
				reg3 : out std_logic_vector(3 downto 0);
				selectedData : out std_logic_vector(3 downto 0)
			);
end register_file;
architecture Behavioral of register_file is
-- components
-- 4 bit Register for register file
	COMPONENT reg4 PORT(
		D : IN std_logic_vector(3 downto 0);
		load : IN std_logic;
		Clk : IN std_logic;
		Q : OUT std_logic_vector(3 downto 0)
	);
	END COMPONENT;

	-- 2 to 4 Decoder
	COMPONENT decoder_2to4 PORT(
		Enable : IN std_logic; -- I'm adding an enable signal that we can turn high to write to the regerister file.
		A0 : IN std_logic;
		A1 : IN std_logic;
		Q0 : OUT std_logic;
		Q1 : OUT std_logic;
		Q2 : OUT std_logic;
		Q3 : OUT std_logic
	);
	END COMPONENT;
	-- 2 to 1 line multiplexer
	COMPONENT mux2_4bit PORT(
		In0 : IN std_logic_vector(3 downto 0);
		In1 : IN std_logic_vector(3 downto 0);
		s : IN std_logic;
		Z : OUT std_logic_vector(3 downto 0)
	);
	END COMPONENT;

	-- 4 to 1 line multiplexer
	COMPONENT mux4_4bit PORT(
		In0 : IN std_logic_vector(3 downto 0); In1 : IN std_logic_vector(3 downto 0); In2 : IN std_logic_vector(3 downto 0); In3 : IN std_logic_vector(3 downto 0); S0 : IN std_logic;
		S1 : IN std_logic;
		Z : OUT std_logic_vector(3 downto 0)
	);
	END COMPONENT;

	-- signals
	signal load_reg0, load_reg1, load_reg2, load_reg3 : std_logic;
	signal reg0_q, reg1_q, reg2_q, reg3_q, data_src_mux_out, src_reg : std_logic_vector(3 downto 0);

begin

	-- port maps ;-)
	-- register 0
	reg00: reg4 PORT MAP(
		D => data_src_mux_out,
		load => load_reg0, Clk => Clk,
		Q => reg0_q
	);
	-- register 1
	reg01: reg4 PORT MAP(
		D => data_src_mux_out,
		load => load_reg1,
		Clk => Clk,
		Q => reg1_q
	);
	-- register 2
	reg02: reg4 PORT MAP(
		D => data_src_mux_out,
		load => load_reg2, Clk => Clk,
		Q => reg2_q
	);
	-- register 3
	reg03: reg4 PORT MAP(
		D => data_src_mux_out,
		load => load_reg3, Clk => Clk,
		Q => reg3_q
	);
	-- Destination register decoder
		des_decoder_2to4: decoder_2to4 PORT MAP( Enable => writeToReg,  A0 => des_A0,
		A1 => des_A1, Q0 => load_reg0, Q1 => load_reg1, Q2 => load_reg2, Q3 => load_reg3
	);
	-- 2 to 1 Data source multiplexer
	data_src_mux2_4bit: mux2_4bit PORT MAP( In0 => data,
		In1 => src_reg,
		s => data_src,
		Z => data_src_mux_out
	);
	-- 4 to 1 source register multiplexer
		Inst_mux4_4bit: mux4_4bit PORT MAP( In0 => reg0_q,
		In1 => reg1_q, In2 => reg2_q, In3 => reg3_q, S0 => src_s0, S1 => src_s1, Z => src_reg
	);

	selectedData <= src_reg ;-- Send Selected data to selectedData output

	reg0 <= reg0_q; reg1 <= reg1_q; reg2 <= reg2_q; reg3 <= reg3_q;
end Behavioral;

-- END REGISTER FILE
