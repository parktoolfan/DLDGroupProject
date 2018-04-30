Library ieee;

use ieee.std_logic_1164.all;

-- This program is written for the 2017 Spring DLD class at Grove City College. The goal is to create a system which polls classrooms around campus to clooect information from them.
-- Information collected is ClassroomInUse, LightsAreOn, and ProjectorIsOn.
-- ClassroomInUse being a 1 represents that the classroom is being used, all of these signals come from sensors in the classroom that are explained in the writup attached with this code.

-- This VHDL program is written by Theo Stangebye, stangebyeTO1@gcc.edu, April 2017.

entity CampusController is
port(	gpio : inout std_logic_vector(7 downto 0);	-- We clear all of the io on the baord so that the LEDs are not "Ghosted on".
		ledr : out std_logic_vector(17 downto 0);
		ledg : out std_logic_vector(8 downto 0);
		sw : in std_logic_vector(17 downto 0);
		key : in std_logic_vector (3 downto 0)
	);
end CampusController;

-- The campus Controller will poll classrooms (which are simulated on another VHDL board). It will output a 2 bit integer which represents the ID of 1 of 4 classrooms.
-- When a classroom's id is broadcasted on the RoomID bits, that classroom will connect to the communication bus (1 bit wide) and send it's information over a serial connection to this campus controller.
architecture a of CampusController is

	-- COMPONENT DECLARATIONS
	component ls74 is -- This is a standard DFF.
		port(	d, clr, pre, clk : in std_logic;
				q : out std_logic
		);
	end component;

	-- Delcare Asynchronous clear 4 bit counter
	component vhdl_binary_counter is
		port (	C, CLR : in std_logic;
					Q : out std_logic_vector(3 downto 0)
				);
	end component;

	-- Synchronous 4 bit counter
	component ls163 is
		port(	C, CLR : in std_logic;
				Q : out std_logic_vector(3 downto 0)
		);
	end component;

	-- SIPO Shift Regerister.
	component sipo is
		port ( 	clk, clear : in std_logic;
					Input_Data: in std_logic;
					Q: out std_logic_vector(15 downto 0)
				);
	end component;

	-- Much of the register file code is derived from online lecture slides, see entity declaration for more.
	component register_file is
		Port (	src_s0 : in std_logic; -- src_s0 and src_s0 are the selection bits which decide which register the selectedData out gets its bits from.
				src_s1 : in std_logic;
				des_A0 : in std_logic; -- address of register file for writing to.
				des_A1 : in std_logic;
				writeToReg : in std_logic; -- when we want to write to the Register.
				Clk : in std_logic; -- clock signal.
				data_src : in std_logic; -- this is an artifact from the walkthrough slides.
				data : in std_logic_vector(3 downto 0); -- Data input that we want to write.
				reg0 : out std_logic_vector(3 downto 0); -- register 0 contents
				reg1 : out std_logic_vector(3 downto 0); -- register 1 contents, etc.
				reg2 : out std_logic_vector(3 downto 0);
				reg3 : out std_logic_vector(3 downto 0);
				selectedData : out std_logic_vector(3 downto 0) -- the data selected by src_s1 and src_s0
		);
	end component;

	-- SIGNALS
	Signal rxin : std_logic_vector(15 downto 0); -- this signal represents the last 16 bits recieved on the RX input.
	Signal RoomID : std_logic_vector(3 downto 0); -- RoomID will be the binary number of the classroom that we are talking to,
	Signal tx, Master_Clock, rx : std_logic; -- tx can be used to communicate in serial on, Master_Clock is the main clock signal, and RX is our recieving bit.
	Signal StartFlag, EndFlag, BitStringAlligned : std_logic; -- the startFlag is thrown after a predetermined serial stream is recieved which represeents a ClassroomController Coming Online.
	-- the ENd is thrown after a predetermined serial stream is recieved which represeents a ClassroomController Coming Online.
	-- BitStringAlligned is thrown when we are ready to load the bitstream from RX into our DB.

begin

	-- GPIO INPUTS AND OUTPUTS
		rx <= gpio(4);		-- input from classroomController
		gpio(3) <= tx;		-- we could talk to classroomControllers on this.
		gpio(1 downto 0) <= RoomID(1 downto 0); -- Broadcast RoomID to ClassroomControllers
		Master_Clock <= gpio(7); -- Read clock from arduino.
		ledg(8) <= Master_Clock; -- flash LEDG(8) with clock signal.
		-- share clock signal with children.
		gpio(5) <= Master_clock; -- Tranmit clock signal to connected classroomContorllers.

		-- Hook up RX to shift Regerister - this takes a serial stream in and produces a parallel output representing the last 16 bits that came through on the shift register.
		inputReg : sipo port map (clk => Master_Clock, Clear => '0', Input_Data => rx, q => rxin); -- rxin is the 16bit history of what came in on RX.
		-- rxin(0) should be the newest bit recieved, rxin(15) the oldest.

		-- This is some combinational logic that sets StartFlag to '1' when rxin is "1010101010101010"
		StartFlag <= (rxin(15) and rxin(13) and rxin(11) and rxin(9) and rxin(7) and rxin(5) and rxin(3) and rxin(1)) and Not(rxin(14) OR rxin(12) OR rxin(10) Or rxin(8) or rxin(6) or rxin(4) or rxin(2) or rxin(0));
		-- End flag when rxin is "1111111111111111"
		EndFlag <= (rxin(15) and rxin(14) and rxin(12) and rxin(11) and rxin(10) and rxin(9) and rxin(8) and rxin(7) and rxin(6) and rxin(5) and rxin(4) and rxin(3) and rxin(2) and rxin(1) and rxin(0));

		-- Implement our model for a 74x161 with asynchronous clear.  This counter drives our RoomID Count.
		RoomIDCounter : vhdl_binary_counter port map (
				C => EndFlag,
				CLR => RoomID(2),  -- since we are only talking two 4 classrooms, we will reset the counter as soon as the binar number changes from 0011 to 0100
				Q => RoomID
		);

		-- Because this chip does not have an RCO, implement some combinational logic to simulate the RCO, when this simulation triggers RCO, we know that the we are ready to read from our input shift regerister into our memory circuitry.
		BitStringAlligned <= Not(rxin(15) or rxin(14) or rxin(13) or rxin(12) or rxin(11) or rxin(10) or rxin(9) or rxin(8) or rxin(0) or rxin(1) or rxin(2) or rxin(3) or rxin(4));

		-- Implement Memory Component:
		-- A note on the memory component, in a full system where we have as many as 8 classrooms with 64 classrooms a piece, we would need 512 register, since we are only demonstrating 4 classrooms across two buildings, we are going to use a 4 register register file.
		-- This specific register file has 4 bit wide registers, we will wire '0' to the MSB of the register.
		Database : register_file port map(
			src_s0 => sw(16), -- since we don't need to read from the register file, these can be Zero.
			src_s1 => sw(17),
			des_A0 => RoomID(0), -- we index our data based on what classroom we are reading from
			des_A1 => RoomID(1), -- we index our data based on what classroom we are reading from
			writeToReg => bitStringAlligned, -- just like the circuit diagram, this is wired to execute when the bit string is alligned.
			Clk => Master_Clock,
			data_src => '0', -- we always want our data to flow from the input bus.
			data => '0' & Rxin(7 downto 5),  -- Here we assign our 4 bits of Data, zero padded on the MSB to arrange the 3 bits of data in a 4 bit register.
			reg0 => ledr(3 downto 0), -- here we put the contents of our registers onto LEDs.
			reg1 => ledr(7 downto 4),
			reg2 => ledr(11 downto 8),
			reg3 => ledr(15 downto 12),
			selectedData => ledg( 3 downto 0)
		);

		-- update leds with information as to what our circuit is doing.
		Ledg(6) <= BitStringAlligned; -- this implies we're writing to the register file.
		Ledg(7) <= StartFlag; -- this means we got the start flag
		Ledg(5) <= EndFlag; -- we got the end flag.

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

-- Create 4 bit counters.
-- BASIC 4 bit counter:
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

-- this 4 bit counter has an asynchronous clear.
entity vhdl_binary_counter is
	port(C, CLR : in std_logic; -- C is the clock signal.
	Q : out std_logic_vector(3 downto 0)); -- 4 bit integer output.
end vhdl_binary_counter;

architecture bhv of vhdl_binary_counter is
	signal tmp: std_logic_vector(3 downto 0);
begin
	process (C, CLR)
	begin
	if (CLR='1') then
		tmp <= "0000";
	elsif (C'event and C='1') then
		tmp <= tmp + 1;
	end if;
	end process;
	Q <= tmp;
end bhv;

-- 4 bit counter with Synchronous clear:
-- Note that a 163 would normally include a load function.
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
entity ls163 is
	port(C, CLR : in std_logic;
	Q : out std_logic_vector(3 downto 0));
end ls163;
architecture bhv of ls163 is
	signal tmp: std_logic_vector(3 downto 0);
begin
	process (C, CLR)
	begin
	if (C'event and C='1' and CLR='1') then
		tmp <= "0000";
	elsif (C'event and C='1') then
		tmp <= tmp + 1;
	end if;
	end process;
	Q <= tmp;
end bhv;

-- Begin SIPO Shift Register - adapted from https://allaboutfpga.com/vhdl-code-for-4-bit-shift-register/
library ieee;
use ieee.std_logic_1164.all;
entity sipo is -- the SIPO register takes data in in serial and produces a parallel string representing the last so many values that appeared in its bitstream input.
 port(
 clk, clear : in std_logic;
 Input_Data: in std_logic;
 Q: out std_logic_vector(15 downto 0) ); -- this one remembers 16 bits.
end sipo;

architecture arch of sipo is
 Signal temp : std_logic_vector(15 downto 0);
begin

 process (clk)
 begin
 if clear = '1' then
 Q <= "0000000000000000";
 temp <= "0000000000000000";
 elsif (CLK'event and CLK='1') then
 temp(15 downto 1) <= temp(14 downto 0); -- 15 is going to be the oldest data, 0 will be the newest.
 temp(0) <= Input_Data;
 Q <= temp;
 end if;
 end process;
end arch;

-- Create RegisterFile Components:
-- This code comes from the guide at https://www.scss.tcd.ie/Michael.Manzke/CS2022/CS2022_vhdl_eighth.pdf
-- from here to the end of this file, the contents are created from the lecture slides at the URL above. As such, this code is implemented with sparse comments as the author of the lecture materials above neglected to comment his code.
-- 2 to 4 decoder
-- NOTE THIS IS ONLY ONE HALF of a ls139 chip.
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
entity decoder_2to4 is
	Port (
		Enable : IN std_logic; -- I'm adding an enable signal that we can turn high to write to the regerister file.  Disabling the decoder writes 0 to all of the outputs.
		A0 : in std_logic;
		A1 : in std_logic;
		Q0 : out std_logic;
		Q1 : out std_logic;
		Q2 : out std_logic;
		Q3 : out std_logic);
end decoder_2to4;
architecture Behavioral of decoder_2to4 is
	begin
		Q0<= ((not A0) and (not A1)) and Enable; -- and enable to implement 0 out of m when the enable bit is '0'
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

-- Finally, here is the register component -- this register is 4 bits wide and simulates 4 DFFs wired in parallel.
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
entity reg4 is
	port ( D : in std_logic_vector(3 downto 0); -- input data to register.
		load, Clk : in std_logic;
		Q : out std_logic_vector(3 downto 0) -- output of the register (4 bits in parallel)
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
