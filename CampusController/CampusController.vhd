Library ieee;

use ieee.std_logic_1164.all;

entity CampusController is
port(	gpio : inout std_logic_vector(7 downto 0);
		ledr : out std_logic_vector(17 downto 0);
		ledg : out std_logic_vector(8 downto 0);
		sw : in std_logic_vector(17 downto 0);
		key : in std_logic_vector (3 downto 0)
	);
end CampusController;

architecture a of CampusController is

	-- COMPONENT DECLARATIONS
	component ls74 is
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

	component register_file is
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
	end component;


	-- SIGNALS
	Signal rxin : std_logic_vector(15 downto 0);
	Signal BuildingID, allignmentCounterOut : std_logic_vector(3 downto 0);
	Signal tx, Master_Clock, rx : std_logic;
	Signal StartFlag, EndFlag, BitStringAlligned : std_logic;

begin

	-- TESTING output pins:
	--gpio(3) <= sw(0);
	--ledr(0) <= sw(0);
	--ledr(1) <= gpio(2);

	-- GPIO INPUTS AND OUTPUTS
		rx <= gpio(4);		-- input
		gpio(3) <= tx;		-- rest are outputs
		--gpio(5) <= Master_Clock;
		gpio(2 downto 0) <= BuildingID(2 downto 0);
		-- for testing, we'll let the Arduino Create the Clock signal.
		Master_Clock <= gpio(7);
		ledg(8) <= Master_Clock;


		-- Hook up RX to shift Regerister
		inputReg : sipo port map (clk => Master_Clock, Clear => '0', Input_Data => rx, q => rxin);

		-- Create And gates for counter logic
		StartFlag <= (rxin(15) and rxin(13) and rxin(11) and rxin(9) and rxin(7) and rxin(5) and rxin(3) and rxin(1)) and Not(rxin(14) OR rxin(12) OR rxin(10) Or rxin(8) or rxin(6) or rxin(4) or rxin(2) or rxin(0));
		EndFlag <= (rxin(15) and rxin(14) and rxin(12) and rxin(11) and rxin(10) and rxin(9) and rxin(8) and rxin(7) and rxin(6) and rxin(5) and rxin(4) and rxin(3) and rxin(2) and rxin(1) and rxin(0));

		-- Implement our model for a 74x161 with asynchronous clear.  This counter drives our buildingID Count.
		BuildingIdCounter : vhdl_binary_counter port map (
				C => EndFlag,
				CLR => BuildingID(2),  -- Normally, we would reset when the buildingID is x9, however, since in this demo there are only 2 building,s we need to roll over to the first building when b_1 goes hot..
				Q => BuildingID
		);

		-- Implement Bit string allignment Counter
		AllignmentCounter : ls163 port map (
				C => Master_Clock,
				CLR => StartFlag,
				Q => allignmentCounterOut
		);

		-- Because this chip does not have an RCO, implement some combinational logic to simulate the RCO, when this simulation triggers RCO, we know that the we are ready to read from our input shift regerister into our memory circuitry.
		BitStringAlligned <= allignmentCounterOut(0) and allignmentCounterOut(1) and allignmentCounterOut(2) and allignmentCounterOut(3) and not(endFlag) and not(startflag);


		-- Implement Memory Component:
		-- A note on the memory component, in a full system where we have as many as 8 classrooms with 64 classrooms a piece, we would need 512 register, since we are only demonstrating 4 classrooms across two buildings, we are going to use a 4 register register file.
		-- This specific register file has 4 bit wide registers, we will wire '0' to the MSB of the register.
		Database : register_file port map(
			src_s0 => sw(16), -- since we don't need to read from the register file, these can be Zero.
			src_s1 => sw(17),
			des_A0 => Rxin(9), -- let this bit be the lsb on the classroom identifier since we only have 4 classrooms total in the demo, we don't need to use all 9 indexing bits like is done in the circuit diagram.
			des_A1 => BuildingID(0), -- this will be the LSB on the building identifier (the building that we are currently talking to)
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
		
		Ledg(6) <= BitStringAlligned;
		Ledg(7) <= StartFlag;
		Ledg(5) <= EndFlag;


		-- TESTING COMPONENT CODES:::
	-- test74: ls74  port map (d => sw(7), clr => sw(8), pre => sw(9), clk => key(0), q => ledr(5));
	-- Test asynchronous clear 4 bit counter
	-- testASchro : vhdl_binary_counter port map (C => key(0), CLR => sw(17), q => ledr(17 downto 14)); -- test asynchronous clear
	-- testSchro : ls163 port map (C => key(0), CLR => sw(17), q => ledr(13 downto 10)); -- tests synchronous clear
	-- Test synchronous clear 4 bit counter
	-- Testing Regerister File:
	-- 	testRegFile : register_file port map(
	-- 			src_s0 => sw(16),
	-- 			src_s1 => sw(17),
	-- 			des_A0 => sw(14),
	-- 			des_A1 => sw(15),
	-- 			writeToReg => sw(13),
	-- 			Clk => key(0),
	-- 			data_src => '0',
	-- 			data => sw(3 downto 0),
	-- 			reg0 => ledr(3 downto 0),
	-- 			reg1 => ledr(7 downto 4),
	-- 			reg2 => ledr(11 downto 8),
	-- 			reg3 => ledr(15 downto 12),
	-- 			selectedData => ledg( 3 downto 0)
	-- 	);

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

-- Create 4 bit counters.
-- BASIC 4 bit counter:
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

entity vhdl_binary_counter is
	port(C, CLR : in std_logic;
	Q : out std_logic_vector(3 downto 0));
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

entity sipo is
 port(
 clk, clear : in std_logic;
 Input_Data: in std_logic;
 Q: out std_logic_vector(15 downto 0) );
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
 temp(15 downto 1) <= temp(14 downto 0);
 temp(0) <= Input_Data;
 Q <= temp;
 end if;
 end process;
end arch;

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
