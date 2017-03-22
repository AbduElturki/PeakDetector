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
    seqDone: in std_logic
  );
end entity;

architecture commands of cmdProc is
  type state_type is (CommandLetter, Number0, Cmd1, Cmd2, StartCountingBitches, Waitfordata, Sendfirstbyte, SendSecondbyte, SendSpacebyte);
  signal curState, nextState: state_type;
  signal n0, n1, n2: std_logic_vector(7 downto 0);
begin
  combi_nextState: process(curState, rxNow)
  begin
    start <= '0';
	 txNow <= '0';
    
    
	if rxnow='1' then
	case curState is
    when CommandLetter =>
      if rxdata="01000001" or rxdata="01100001" then -- a or A
        nextState <= Number0;
		  txData <= "01010010";
		  txNow <= '1';
		else
			nextState <= CommandLetter;
		end if;
    
    when Number0 => --00110000 48 |   00111001 57
      if rxdata>="00110000" and rxdata<="00111001" then --Number
        nextState <= Number0;
        n0 <= rxdata;
		  txData <= "01010000";
		  txNow <= '1';
      else
        nextState <= CommandLetter;
		  txData <= "01010001";
		  txNow <= '1';
      end if;
      
    when Cmd1 =>
      if rxdata(3 downto 0) > "1001" or rxdata(7 downto 4) /= "0011" then
        nextState <= CommandLetter;
      else
        n1 <= rxdata;
        nextState <= Cmd2;
      end if;
      
    when Cmd2 =>
      if rxdata(3 downto 0) > "1001" or rxdata(7 downto 4) /= "0011" then
        nextState <= CommandLetter;
      else
        n0 <= rxdata;
        nextState <= StartCountingBitches;
        start <= '1';
      end if;
      
      when StartCountingBitches =>
        nextState <= Waitfordata;
        --numWords_bcd(0)<=n0(3 downto 0);
        --numWords_bcd(1)<=n1(3 downto 0);
        --snumWords_bcd(2)<=n2(3 downto 0);
        start <= '1';
      
      
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
  end case;
  end if;
end process;

seq_state: process (clk, reset)
  begin
    if reset = '0' then
      curState <= CommandLetter;
    elsif clk'event AND clk='1' then
      curState <= nextState;
    end if;
  end process; -- seq
end;
