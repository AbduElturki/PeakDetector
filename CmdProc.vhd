library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.common_pack.all;
library UNISIM;
use UNISIM.VCOMPONENTS.ALL;

entity cmdProc is
  port (
    clk: in std_logic;
    reset: in std_logic;
    rxnow: in std_logic;
    rxData: in std_logic_vector (7 downto 0);
    txData: out std_logic_vector (7 downto 0);
    rxdone: out std_logic;
    ovErr: in std_logic;
    framErr: in std_logic;
    txnow: out std_logic;
    txdone: in std_logic;
    start: out std_logic;
    numWords_bcd: out BCD_ARRAY_TYPE(2 downto 0);
    dataReady: in std_logic;
    byte: in std_logic_vector(7 downto 0);
    maxIndex: in BCD_ARRAY_TYPE(2 downto 0);
    dataResults: in CHAR_ARRAY_TYPE(0 to RESULT_BYTE_NUM-1);
    seqDone: in std_logic;
	 
		SegOut0: out Character;
		SegOut1: out Character;
		SegOut2: out Character;
		SegOut3: out Character
  );
end entity;

architecture commands of cmdProc is
  type state_type is (CommandLetter, Number0, Number1, Number2, StartCountingSendBreak, Waitfordata, Sendfirstbyte, SendSecondbyte, SendSpacebyte);
  signal curState, nextState: state_type;
  signal n0, n1, n2: std_logic_vector(7 downto 0);
  signal breakProgress: integer range 0 to 7;
  signal rxNowEdge, canStateChange: std_logic:='0';
  
	function charToVector(char:character) return std_logic_vector is 
	begin 
		return std_logic_vector(to_unsigned(character'pos(char),8)); 
	end charToVector;

	function mainMenuInput(val:std_logic_vector (7 downto 0)) return state_type is
	begin
		if val="01000001" or val="01100001" then -- a or A
        return Number0;
		else
		  return CommandLetter;
		end if;
	end mainMenuInput;
begin
	sendDebugging: process(curState, n0, n1, n2)
	begin
	case curState is
		when CommandLetter=>
			SegOut0<='-';
			SegOut1<='-';
			SegOut2<='-';
			SegOut3<='-';
		when Number0=>
			SegOut0<='A';
			SegOut1<=' ';
			SegOut2<=' ';
			SegOut3<=' ';
		when Number1=>
			SegOut0<='A';
			SegOut1<=CHARACTER'VAL(53);
			SegOut2<=' ';
			SegOut3<=' ';
		when Number2=>
			SegOut0<='A';
			SegOut1<=CHARACTER'VAL(to_integer(unsigned(n0)));
			SegOut2<=CHARACTER'VAL(to_integer(unsigned(n1)));
			SegOut3<=' ';
		when StartCountingSendBreak=>
			SegOut0<='C';
			SegOut1<=CHARACTER'VAL(to_integer(unsigned(n0)));
			SegOut2<=CHARACTER'VAL(to_integer(unsigned(n1)));
			SegOut3<=CHARACTER'VAL(to_integer(unsigned(n2)));
		when Waitfordata=>
			SegOut0<='-';
			SegOut1<=CHARACTER'VAL(to_integer(unsigned(n0)));
			SegOut2<=CHARACTER'VAL(to_integer(unsigned(n1)));
			SegOut3<=CHARACTER'VAL(to_integer(unsigned(n2)));
		when others=>
			SegOut0<='9';
			SegOut1<='9';
			SegOut2<='9';
			SegOut3<='9';
	end case;
	end process;
	
  combi_nextState: process(curState, canStateChange)
  begin
   start <= '0';
	rxDone <= '0';
	txData <= "00000000";
	txNow<='0';
	breakProgress <= 0;
	
	if (canStateChange='1') then
		case curState is
		 when CommandLetter =>
			rxDone <= '1';
			txNow <= '1';
			txData <= rxdata;
			nextState <= mainMenuInput(rxData);
		 
		 when Number0 => --00110000 48 |   00111001 57
			rxDone <= '1';
			if rxdata>="00110000" and rxdata<="00111001" then --Number
			  nextState <= Number1;
			  n0 <= rxdata;
				txNow <= '1';
				txData <= rxdata;
			else
				nextState <= mainMenuInput(rxData);
			end if;
		
		when Number1 => --00110000 48 |   00111001 57
			rxDone <= '1';
			if rxdata>="00110000" and rxdata<="00111001" then --Number
			  nextState <= Number2;
			  n1 <= rxdata;
				txNow <= '1';
				txData <= rxdata;
			else
				nextState <= mainMenuInput(rxData);
			end if;
		
		when Number2 => --00110000 48 |   00111001 57
			rxDone <= '1';
			if rxdata>="00110000" and rxdata<="00111001" then --Number
			  nextState <= StartCountingSendBreak;
			  n2 <= rxdata;
				txNow <= '1';
				txData <= rxdata;
			else
				nextState <= mainMenuInput(rxData);
			end if;
      
		when StartCountingSendBreak =>
			txNow <= '1';
			
			case breakProgress is
				when 0|6 =>		txData <= "00001101"; -- CR
				when 1|7 =>		txData <= "00001010"; -- LF
				when 2 to 5 =>	txData <= "00111101"; -- =
				when others =>	txData <= "00111111"; -- ?
			end case;
			txData <= "01000010"; 
			
			if (breakProgress=7) then
				nextState <= StartCountingSendBreak;
				breakProgress <= 7;
			else
				nextState <= StartCountingSendBreak;
				breakProgress <= breakProgress+1;
			end if;
      
		-- To be continued here with sending and receiving data to dataproc
      when others =>
			nextState <= CommandLetter;
		end case;
	else
		nextState <= CommandLetter;
	end if;
end process;

seq_state: process (clk, reset)
  begin
    if reset = '1' then
      curState <= CommandLetter;
    elsif clk'event AND clk='1' then
      curState <= nextState;
	 end if;
  end process; -- seq

	canStateChange <= ((rxNow) and (txDone));
end;
