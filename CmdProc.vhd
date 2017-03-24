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
  type state_type is (CommandLetter, Number0, Number1, Number2, StartCountingSendBreak, Waitfordata, Sendfirstbyte, SendSecondbyte, SendSpacebyte, ListVals, ShowPeaks);
  signal curState, nextState: state_type;
  signal n0, n1, n2: integer range 0 to 9:=0;
  signal triggerNStore: integer range -1 to 2:=-1;
  signal breakProgress: integer range 0 to 7:=0;
  signal canStateChange, updatedBreak: std_logic:='0';
  
	function charToVector(char:character) return std_logic_vector is 
	begin 
		return std_logic_vector(to_unsigned(character'pos(char),8)); 
	end charToVector;

	function mainMenuInput(val:std_logic_vector (7 downto 0)) return state_type is
	begin
		if val="01000001" or val="01100001" then -- A or a
        return Number0;
		elsif val="01001100" or val="01101100" then -- L or l
        return ListVals;
		elsif val="01010000" or val="01110000" then -- P or p
        return ShowPeaks;
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
			SegOut1<=CHARACTER'VAL(48 + n0);
			SegOut2<=' ';
			SegOut3<=' ';
		when Number2=>
			SegOut0<='A';
			SegOut1<=CHARACTER'VAL(48 + n0);
			SegOut2<=CHARACTER'VAL(48 + n1);
			SegOut3<=' ';
		when StartCountingSendBreak=>
			SegOut0<='C';
			SegOut1<=CHARACTER'VAL(48 + n0);
			SegOut2<=CHARACTER'VAL(48 + n1);
			SegOut3<=CHARACTER'VAL(48 + n2);
		when Waitfordata=>
			SegOut0<='-';
			SegOut1<=CHARACTER'VAL(48 + n0);
			SegOut2<=CHARACTER'VAL(48 + n1);
			SegOut3<=CHARACTER'VAL(48 + n2);
		when ListVals=>
			SegOut0<='L';
			SegOut1<=CHARACTER'VAL(48 + 5);
			SegOut2<=CHARACTER'VAL(48 + 5);
			SegOut3<=CHARACTER'VAL(48 + 5);
		when ShowPeaks=>
			SegOut0<='P';
			SegOut1<=CHARACTER'VAL(48 + 1);
			SegOut2<=CHARACTER'VAL(48 + 3);
			SegOut3<=CHARACTER'VAL(48 + 2);
		when others=>
			SegOut0<='9';
			SegOut1<='9';
			SegOut2<='9';
			SegOut3<='9';
	end case;
	end process;
	
  combi_nextState: process(curState, canStateChange, breakProgress)
  begin
   start <= '0';
	rxDone <= '0';
	txData <= "00000000";
	txNow<='0';
	triggerNStore<=-1;
	
	case curState is
	 when CommandLetter =>
		if (canStateChange='1') then
			rxDone <= '1';
			txNow <= '1';
			txData <= rxdata;
			nextState <= mainMenuInput(rxData);
		else
			nextState <= CommandLetter;
		end if;
	 when Number0 => --00110000 48 |   00111001 57
		if (canStateChange='1') then
			rxDone <= '1';
			if rxdata>="00110000" and rxdata<="00111001" then --Number
				nextState <= Number1;
				rxDone <= '1';
				triggerNStore<=0;
				txNow <= '1';
				txData <= rxdata;
			else
				nextState <= mainMenuInput(rxData);
			end if;
		else
			nextState <= Number0;
		end if;
	
	when Number1 => --00110000 48 |   00111001 57
		if (canStateChange='1') then
			if rxdata>="00110000" and rxdata<="00111001" then --Number
				nextState <= Number2;
				rxDone <= '1';
				triggerNStore<=1;
				txNow <= '1';
				txData <= rxdata;
			else
				nextState <= mainMenuInput(rxData);
			end if;
		else
			nextState <= Number1;
		end if;
	
	when Number2 => --00110000 48 |   00111001 57
		if (canStateChange='1') then
			if rxdata>="00110000" and rxdata<="00111001" then --Number
				nextState <= StartCountingSendBreak;
				rxDone <= '1';
				triggerNStore<=2;
				txNow <= '1';
				txData <= rxdata;
			else
				nextState <= mainMenuInput(rxData);
			end if;
		else
			nextState <= Number2;
		end if;
	
	when StartCountingSendBreak =>
		if (canStateChange='1') then
			txNow <= '1';
			
			case breakProgress is
				when 0|6 =>		txData <= "00001101"; -- CR
				when 1|7 =>		txData <= "00001010"; -- LF
				when 2 to 5 =>	txData <= "00111101"; -- =
				when others =>	txData <= "00111111"; -- ?
			end case;
		
			if (breakProgress=7) then
				nextState <= WaitForData;
				start <= '1';
			else
				nextState <= StartCountingSendBreak;
			end if;
		else
			nextState <= StartCountingSendBreak;
		end if;
		
	when WaitForData =>
	  if dataready = '1' then 
		 NextState <= Sendfirstbyte;
	  else
		 nextState <= WaitForData;
	  end if;
	  
	when Sendfirstbyte => 
	  if (byte(7 downto 4)>"1001") then
		 txData<="0100" & std_logic_vector(unsigned(byte(7 downto 4))-"1001"); -- A-F
	  else
		 txData<="0011" & byte(7 downto 4); -- 0-9
	  end if;
	  txNow <='1';
	  nextState <= Sendsecondbyte;
	  
	when Sendsecondbyte =>
	  if (byte(3 downto 0)>"1001") then
		 txData<="0100" & std_logic_vector(unsigned(byte(3 downto 0))-"1001"); -- A-F
	  else
		 txData<="0011" & byte(3 downto 0); -- 0-9
	  end if;
	  txNow <='1';
	  nextState <= Sendspacebyte;
	  
	when Sendspacebyte =>
	  txData<="00100000";
	  txNow <='1';
	  if seqDone = '1' then
		 nextState <= CommandLetter;
	  else
		 start <= '1';
		 nextState <= WaitForData;
	  end if;
	  
	when ListVals =>
		nextState <= ListVals;
		
	when ShowPeaks =>
		nextState <= showPeaks;
		
	when others =>
		nextState <= CommandLetter;
	end case;
end process;

breakProgressSwitcher: process (clk)
  begin
	if (curState = StartCountingSendBreak) then
		if clk'event AND clk='1' AND canStateChange='1' then
			breakProgress<=breakProgress+1;
		end if;
	else
		breakProgress<=0;
	end if;
  end process;

seq_state: process (clk, reset)
  begin
    if reset = '1' then
      curState <= CommandLetter;
    elsif clk'event AND clk='1' then
		case triggerNStore is
			when 0 => n0 <= to_integer(signed(rxdata(3 downto 0)));
			when 1 => n1 <= to_integer(signed(rxdata(3 downto 0)));
			when 2 => n2 <= to_integer(signed(rxdata(3 downto 0)));
			when others =>
		end case;
		
      curState <= nextState;
	 end if;
  end process;

	canStateChange <= ((rxNow) and (txDone));

end;
