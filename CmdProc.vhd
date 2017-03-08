library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.common_pack.all;
library UNISIM;
use UNISIM.VCOMPONENTS.ALL;
use UNISIM.VPKG.ALL;

entity cmdProc is
  port (
      clk:		in std_logic;
      reset:		in std_logic;
      rxnow:		in std_logic;
      rxData:			in std_logic_vector (7 downto 0);
      txData:			out std_logic_vector (7 downto 0);
      rxdone:		out std_logic;
      ovErr:		in std_logic;
      framErr:	in std_logic;
      txnow:		out std_logic;
      txdone:		in std_logic;
      start: out std_logic;
      numWords_bcd: out BCD_ARRAY_TYPE(2 downto 0);
      dataReady: in std_logic;
      byte: in std_logic_vector(7 downto 0);
      maxIndex: in BCD_ARRAY_TYPE(2 downto 0);
      dataResults: in CHAR_ARRAY_TYPE(0 to RESULT_BYTE_NUM-1);
      seqDone: in std_logic
    );
end;

architecture commands of cmdProc is
  type state_type is (CommandLetter, Cmd0, Cmd1, Cmd2, StartCountingBitches, ConvertNumbers);
  signal curState, nextState: state_type;
  signal n0, n1, n2: std_logic_vector(7 downto 0);
begin
  combi_nextState: process(curState, rxdata)
  begin
    
    start <= '0';
    
    case curState is
    when CommandLetter =>
      if rxdata="01000001" or rxdata="01100001" then -- if data = a or A
        nextState <= Cmd0;
    else
      nextState <= CommandLetter;
    end if;
    
    when Cmd0 =>
      if rxdata(3 downto 0) > "1001" or rxdata(7 downto 4) /= "0011" then
        nextState <= CommandLetter;
      else
        n0 <= rxdata;
        nextState <= Cmd1;
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
        nextState <= ConvertNumbers;
        numWords_bcd(0)<=n0(3 downto 0);
        numWords_bcd(1)<=n1(3 downto 0);
        numWords_bcd(2)<=n2(3 downto 0);
        start <= '1'
      
      
      when WaitForData =>
        if dataready = '1' then 
          NextState <= ConvertNumbers;
        else
          nextState => WaitForData;
        end if;
        
      when ConvertNumbers => 
        if (byte(7 downto 4)>"1001") then
          txData1<="0100" & byte(7 downto 4)-"1001"; -- A-F
        else
          txData1<="0011" & byte(7 downto 4); -- 0-9
        end if;
        if (hex(3 downto 0)>"1001") then
          txData2<="0100" & byte(3 downto 0)-"1001"; -- A-F
        else
          txData2<="0011" & byte(3 downto 0); -- 0-9
        end if;
        
  end case;
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