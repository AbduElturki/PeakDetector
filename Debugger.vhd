library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.common_pack.all;
library UNISIM;
use UNISIM.VCOMPONENTS.ALL;

entity Debugger is
	Port (
		clk: in std_logic;
		SegSel : out std_logic_vector (3 downto 0);
		SegData : out std_logic_vector (7 downto 0);
		SegIn0: in Character;
		SegIn1: in Character;
		SegIn2: in Character;
		SegIn3: in Character
	);
end Debugger;

architecture Behavioral of Debugger is
	signal curState: INTEGER range 0 to 3:=0;
	signal timer: integer range 0 to 1000000:=0;
	
	function makeSegment(char:character) return std_logic_vector is 
	begin 
		case char is
			when '0'=> return "00000011";
			when '1'=> return "10011111";
			when '2'=> return "00100101";
			when '3'=> return "00001101";
			when '4'=> return "10011001";
			when '5'=> return "01001001";
			when '6'=> return "01000001";
			when '7'=> return "00011111";
			when '8'=> return "00000001";
			when '9'=> return "00001001";
			when 'A'=> return "00010001";
			when 'C'=> return "01100011";
			when 'L'=> return "11100011";
			when 'P'=> return "00110001";
			when '-'=> return "11111101";
			when ' '=> return "11111111";
			when others=> return "11111110";
		end case;
	end makeSegment;
	
begin

	segUpdate: process (curState)
	begin
		case curState is
			when 0 =>
				SegSel <= "1110";
				SegData <= makeSegment(SegIn0);
			when 1 =>
				SegSel <= "1101";
				SegData <= makeSegment(SegIn1);
			when 2 =>
				SegSel <= "1011";
				SegData <= makeSegment(SegIn2);
			when 3 =>
				SegSel <= "0111";
				SegData <= makeSegment(SegIn3);
			
		end case;
	end process;
	
	stepper: process (clk)
	begin
		if clk'event AND clk='1' then
			if timer=10000 then
				timer<=0;
				curState <= curState+1;
			else
				timer<=timer+1;
				curState <= curState;
			end if;
		end if;
	end process;

end Behavioral;

