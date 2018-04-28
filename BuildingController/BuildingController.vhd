Library ieee;

use ieee.std_logic_1164.all;

entity BuildingController is
port(	gpio : inout std_logic_vector(14 downto 0);
		ledr : out std_logic_vector(17 downto 0);
		sw : in std_logic_vector(17 downto 0);
		key : in std_logic_vector (3 downto 0)
	);
end BuildingController;

architecture a of BuildingController is
	begin
	
	
	--two building hardwares go here
	--
	
	
	end a;



	
--Building hardware, one for each building	
library ieee;
use ieee.std_logic_1164.all;
Entity BuildingHardware is
	port(Rx1, Rx2, clk_in : IN std_logic;
			Building_ID : IN std_logic_vector(2 downto 0);
			clk_out, Tx1, Tx2 : out std_logic;
			Room_ID : out std_logic_vector(5 downto 0);
	);
end BuildingHardware;

architcture b of BuildingHardware is
	begin
	
	
	-- circuit diagram inplementation goes here
	
	
	end b;






-- Create a 74x74 chip a DFF
Library ieee;
use ieee.std_logic_1164.all;

Entity ls74 is

	port(	d, clr, pre, clk : IN std_logic;
			q : out std_logic
	);
end ls74;

Architecture c of ls74 is

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
	
End c;


--8 bit Serial in/Parallel out with asynchronous clear 74x164 chip
library ieee; 
use ieee.std_logic_1164.all; 

entity SIPO_A_shift is 		

	port(clk, clr, A, : in std_logic; 
      PO : out std_logic_vector(7 downto 0)); 
end SIPO_A_shift; 

architecture d of shift is 

  signal tmp: std_logic_vector(7 downto 0); 
  
  begin 
    process (clk, clr) 
      begin 
		
			if (clr = '1') then
				tmp <= "00000000";
				
        if (clk'event and Clk='1') then 
		  
          --if (LEFT_RIGHT='0') then 
            tmp <= tmp(6 downto 0) & A; 
				
         -- end if; 
			 
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
 
entity counter is 
  port(clk, CLR, EN, Load_L : in std_logic; 
		 load_input: in std_logic_vector(3 downto 0);
		  Q: out std_logic_vector(3 downto 0)); 
end counter; 
architecture e of counter is 
  signal tmp, tmp_in: std_logic_vector(3 downto 0); 
  begin 
    process (clk, CLR) 
      begin 
        if (CLR='1') then 
          tmp <= "0000"; 
			 
        elsif (clk'event and clk='1') then 
		  
          if (EN='1') then 
            tmp <= tmp + 1; 
				
			 elsif ( tmp = "0011") then
				tmp <= "0000";	
				
			 elsif (Load_L ='0') then
				tmp <= tmp_in;
				
          end if; 
		
        end if; 
    end process; 
   Q <= tmp;
	Load_input< tmp_in; 
end e; 

-- 4-to-1, 2-bit wide MUX 74x153
library ieee; 
use ieee.std_logic_1164.all; 
use ieee.std_logic_unsigned.all; 
 
entity Mux is 
  port(S0, S1 : in std_logic; 
		 A, B, C, D: in std_logic_vector(1 downto 0);
		  Y: out std_logic_vector(1 downto 0)); 
end Mux; 

architecture f of Mux is
	
	signal tmp: std_logic_vector(1 downto 0);

	begin
		
		process(S0, S1)
		
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
		
		process(S_L, clk, clr)
			
			 begin 
		
				if (clr = '1') then
				tmp <= "0000000000000000";
				
				elsif (clk'event and Clk='1') then 

					if (S_L ='1') then 
					tmp <= tmp(14 downto 0) & SI; 
			
					elsif (S_L = '0') then
					tmp <= PI;
				
					end if; 
				
				end if;
			 
			 SO <= PI(15);
			 
				end if; 
    end process; 
	
		
		
		
		
		
		
		
		


