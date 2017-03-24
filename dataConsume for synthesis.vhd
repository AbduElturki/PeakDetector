library ieee;
use ieee.std_logic_1164.all;
use work.common_pack.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;


entity dataConsume is
  port (
		clk:		in std_logic;
		reset:		in std_logic; -- synchronous reset
		start: in std_logic; -- goes high to signal data transfer
		numWords_bcd: in BCD_ARRAY_TYPE(2 downto 0);
		ctrlIn: in std_logic;
		ctrlOut: out std_logic;
		data: in std_logic_vector(7 downto 0);
		dataReady: out std_logic;
		byte: out std_logic_vector(7 downto 0);
		seqDone: out std_logic;
		maxIndex: out BCD_ARRAY_TYPE(2 downto 0);
		dataResults: out CHAR_ARRAY_TYPE(0 to RESULT_BYTE_NUM-1) -- index 3 holds the peak
  	);
end dataConsume;

architecture myArch of dataConsume is
  -- State declaration
  type STATE_TYPE is (idle, startProc, dataRequest, dataReceived, dataDone);
  signal curState, nextState : STATE_TYPE;
  signal ctrlIn_delayed, ctrlIn_detected, ctrlOut_reg: std_logic := '0';--------signal used in handshaking protocol
  signal cvalue, index_register, indexStore: BCD_ARRAY_TYPE(2 downto 0);---------cvalue is counter value and index_register temporally stores maxIndex value
  signal ctrlOut_changed, enCounter, resCounter, en_shifter, resShifter, en_peak, resPeak, bigReset, enBig, indexReset: boolean:=false;
  signal s_register, peak_register : CHAR_ARRAY_TYPE (0 to RESULT_BYTE_NUM-1);------s_register is shift register and peak_register temporally store 7 bytes with peak in the middle
  signal m_register, biggest_register : std_logic_vector(7 downto 0) := "00000000";
  signal startCheck: std_logic := '0';

begin
  
-----------------------------------------
--------------State Machine--------------
nextStateLogic: process(curState,start,cvalue,numWords_bcd,ctrlIn_detected, peak_register, index_register, data) 
begin
  seqDone <= '0';
  dataReady <= '0';
  resCounter <= false;
	startCheck <= '0';
	enCounter <= false;
  resPeak <= false;
  case curState is
     when idle =>     ----------refers to initial state
       bigReset <= true;           ----------reset every component
       resCounter <= true;
       resShifter <= true;
       resPeak <= true;
	     indexReset <= true;
	     enBig <= false;
       if start = '1' then
         nextState <= startProc;
       else
         nextState <= idle;
       end if;
       
     when startProc =>   ---------start the process for retrieving data        
       bigReset <= false;
       indexReset <= false;
       resShifter <= false;
			 if cvalue(0) = numWords_bcd(0) and cvalue(1) = numWords_bcd(1) and cvalue(2) = numWords_bcd(2) then       ------------- check if it got the requested number of data
					seqDone <= '1';
          bigReset <= true;           ----------reset every component
          resCounter <= true;
          resShifter <= true;
          resPeak <= true;
	        indexReset <= true;
  	       enBig <= false;
					nextState <= idle;   
			 else                           ------moves to request data step and tells ctrlout to change
					startCheck <= '1';
					ctrlOut_changed <= true;
					nextState <= dataRequest;
			 end if;

     when dataRequest =>          --------request data from data generator
        ctrlOut_changed <= false;
       if ctrlIn_detected = '0' then
        nextState <= dataRequest;
       else
        enCounter <= true;     --------------------------trigger the process for updating the counter and shifter and max peak
        en_shifter <= true;
        en_peak <= true;
        dataReady <= '1';              
        nextState <= dataReceived; 
       end if;

     when dataReceived =>       --------state means that system has received the data
        enBig <= true;
         --------disable every component
        en_shifter <= false;
        en_peak <= false;
        if start = '0' then    -------if start signal is low then halt 
            nextState <= dataReceived;
        else                   --------go back to startProc state to start a new retrieval cycle
            nextState <= startProc;
        end if;
     
     when OTHERS =>     -------avoid errors created from unknown state
        nextState <= idle;
                                                                  
  end case;
end process;
-----------------------------------------  
  
  
  
-----------------------------------------
-------------State change----------------
stateReg: process(clk, curState)                 ------seq of state change
begin
    if clk'event and clk = '1'  then
        if reset = '1' then
            curState <= idle;
        else
        curState <= nextState;
        end if;
    else
        curState <= curState;
  end if;    
end process;   
-----------------------------------------



-----------------------------------------
--------------Output results-------------

outputResults:process(clk, cvalue, numWords_bcd, startCheck)
begin
  
  if clk'event and clk = '1' then
    if startCheck = '1' then
        if cvalue(0) = numWords_bcd(0) and cvalue(1) = numWords_bcd(1) and cvalue(2) = numWords_bcd(2) then       
      					for i in 0 to 6 loop                                 ------------- check if it got the requested number of data and give them the final values
      					  dataResults(i) <= peak_register(i); 
      					end loop;
      					for i in 0 to 2 loop
      					  maxIndex(i) <= index_register(i);    
      					end loop;
        else					
      					for i in 0 to 6 loop
      					  dataResults(i) <= X"00"; 
      					end loop;
      					for i in 0 to 2 loop
      					  maxIndex(i) <= X"0";
 					 end loop;	
  	     end if;
	   else
	         for i in 0 to 6 loop
      					  dataResults(i) <= X"00"; 
      					end loop;
      					for i in 0 to 2 loop
      					  maxIndex(i) <= X"0";
 					 end loop;
 		 end if;	 
	end if;
end process;
-----------------------------------------



-----------------------------------------
---------Get data from generator---------
getData:process(clk, ctrlIn_detected, data)
begin
  if clk'event and clk = '1' then
      if ctrlIn_detected = '1' and start = '1' then
        for i in 7 downto 0 loop
               byte(i) <= data(i);         -------------- get data
        end loop;
      else
        for i in 7 downto 0 loop
               byte(i) <= '0';         -------------- if no data is given byte is 00000000
        end loop;
      end if;
  end if;
end process;
-----------------------------------------



-----------------------------------------
--------------BCD counter----------------
numberCounter:process(clk, cvalue)
  begin
    if clk'event and clk = '1' then
        if reset = '1' or resCounter = true then                               ----------- reset counter
              cvalue(2)<=X"0";
              cvalue(1)<=X"0";
              cvalue(0)<=X"0";
        else
          case enCounter is
              when false =>
                  cvalue(2)<=cvalue(2); 
                  cvalue(1)<=cvalue(1);
                  cvalue(0)<=cvalue(0);
              when true =>
                   if cvalue(0) = X"9" and cvalue(1) /= X"9" then ---------------------check for carry-out
                                cvalue(0)<= X"0";
                                cvalue(1)<=cvalue(1)+1;                                               ---- add 1 until it becomes 9 and move to next one if needed
                   elsif cvalue(0) = X"9" and cvalue(1) = X"9" and cvalue(2) /= X"9" then                
                                cvalue(0)<= X"0";
                                cvalue(1)<= X"0";
                                cvalue(2)<=cvalue(2)+1;                                                
                   else 
                                cvalue(0)<=cvalue(0)+1;                                                ---- just add 1 if there is no carry-out 
                   end if;
              when others =>
                  cvalue(2)<=cvalue(2); 
                  cvalue(1)<=cvalue(1);
                  cvalue(0)<=cvalue(0);
            end case;
          end if;
    else
      cvalue(2)<=cvalue(2); 
      cvalue(1)<=cvalue(1);
      cvalue(0)<=cvalue(0);
    end if;
end process;
-----------------------------------------



-----------------------------------------
-----------Handshaking protocol----------
delay_CtrlIn: process(clk, ctrlIn_delayed)     
begin
    if clk'event and clk = '1' then
      ctrlIn_delayed <= ctrlIn;
	  else
		  ctrlIn_delayed <= ctrlIn_delayed;
    end if;
end process;
  
  ctrlIn_detected <= ctrlIn xor ctrlIn_delayed;----------corresponding to ctrl_2

Ctrl_Out: process(clk, ctrlOut_reg)
begin
    if clk'event and clk = '1' then
		    if reset = '1' then
            ctrlOut_reg <= '0';
        elsif clk'event and clk = '1' and ctrlOut_changed = true then
  	   		    ctrlOut_reg <= not ctrlOut_reg;
	   	  else
	   	      ctrlOut_reg <= ctrlOut_reg;
		    end if;
	  else
					  ctrlOut_reg <= ctrlOut_reg;
    end if;
end process;
  
ctrlOut <= ctrlOut_reg;-------------corresponding to ctrl_1
-----------------------------------------



-----------------------------------------
--------------Store Biggest Data---------
biggestReg : process (clk, reset, biggest_register, data, bigReset, enBig)
begin
  if clk'event and clk = '1' and biggest_register < data and (bigReset = false or reset = '0') and enBig = true  then
        for i in 7 downto 0 loop
              biggest_register(i) <= data(i);   --- get biggest data
        end loop; 
  elsif clk'event and clk = '1' and (reset = '1' or bigReset = true) then
              biggest_register <= X"00";
  else                                       -----when other condition keep register the same
        for i in 7 downto 0 loop
              biggest_register(i) <= biggest_register(i);
        end loop;      
 	end if;
end process;
-----------------------------------------



-----------------------------------------
---------Index of biggest data-----------
indexReg : process (clk, biggest_register, reset, indexStore, data, indexReset)
begin
  if clk'event and clk = '1' and biggest_register < data and indexReset = false then   ---- check if current data is smaller than next data
        for i in 0 to 2 loop
              indexStore(i) <= cvalue(i);                       ------------ get the index of the biggest data
        end loop;
  elsif reset  = '1' or indexReset = true then
        for i in 0 to 2 loop
              indexStore(i) <= X"0";
        end loop;
  else                                               -----when other condition keep register the same
        for i in 0 to 2 loop
              indexStore(i) <= indexStore(i);
        end loop; 
 	end if;
end process;
-----------------------------------------



-----------------------------------------
--------------Shift register-------------
shift : process (clk, reset, en_shifter, s_register, resShifter)
begin
  if clk'event and clk = '1' and (reset = '1' or resShifter = true) then
      for i in 0 to 6 loop
          s_register(i) <= X"00";
       end loop; 
  elsif clk'event and clk = '1' and en_shifter = true then -- FULLY SYNCHRONOUS AND ENABLED
       for i in 6 downto 1 loop
          s_register(i) <= s_register(i-1);  ---- SHIFT TOWARDS MSB
       end loop;
          s_register(0) <= data;      ---- insert data to LSB
  else
        for i in 0 to 6 loop          ----when other condition keep register the same
         s_register(i) <= s_register(i);
        end loop;
  end if;   
end process;
-----------------------------------------



-----------------------------------------
----------------MAX peak-----------------
max : process (clk, s_register, reset, en_peak, m_register, index_register, peak_register, resPeak)
begin
   if clk'event and clk = '1' and (reset = '1' or resPeak = true) then
              m_register <= X"00";
          for i in 0 to 2 loop
              index_register(i) <= X"0";
          end loop;
        
          for i in 0 to 6 loop
              peak_register(i) <= X"00";
          end loop;
   elsif clk'event and clk = '1' and en_peak = true and m_register < s_register(3) then         --- CHECK IF THE DATA IN THE MIDDLE IS PEAK
              m_register <= s_register(3); --- ASSIGN BIGGER PEAK TO MAX REGISTER
          for i in 0 to 6 loop
              peak_register(i) <= s_register(i);  --- send peaks to peak register
          end loop;
          
          for i in 0 to 2 loop
              index_register(i) <= indexStore(i);   --- get index of max peak
          end loop;                                                                 
   else                                         ----when other condition keep register the same
               m_register <= m_register;
          for i in 0 to 2 loop
               index_register(i) <= index_register(i);
          end loop;
          for i in 0 to 6 loop
               peak_register(i) <= peak_register(i);
          end loop;     
   end if;
end process;  
-----------------------------------------

end;