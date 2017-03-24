----------------------------------------------------------------------------
--	test_top.vhd -- Top level component for peak detector
----------------------------------------------------------------------------
-- Author:  Vlad Ellis
----------------------------------------------------------------------------
-- Version:			1.0
-- Revision History:
--  15/03/2017 (Vlad Ellis): Initial file from supplied block-level design
----------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use work.common_pack.all;

entity PEAK_DETECTOR_TOP is
	port(
		CLK : in std_logic;
		RESET : in std_logic;
		RX_DATA : in std_logic;
		TX_DATA : out std_logic;
		OUT_SegSel : out std_logic_vector (3 downto 0);
		OUT_SegData : out std_logic_vector (7 downto 0)
	);
end;

architecture STRUCT of PEAK_DETECTOR_TOP is

	component UART_RX_CTRL is
		port(
			sysclk : in std_logic;
			reset: in std_logic;
			
			RxD : in std_logic;
			
			setFE : out std_logic;	-- active high (frame error)
			setOE : out std_logic; -- active high (overrun error)
			dataReady : out std_logic;
			rcvDataReg : out std_logic_vector(7 downto 0);
			rxDone : in std_logic -- active high
		);
	end component;

	component UART_TX_CTRL is
		port(
			CLK : in std_logic;
			
			UART_TX : out std_logic;
			
			READY : out std_logic; -- active high
			SEND : in std_logic; -- active high
			DATA : in std_logic_vector(7 downto 0)
		);
	end component;

	component CMDPROC is
		port(
			CLK : in std_logic;
			RESET : in std_logic;
			
			SEQDONE : in std_logic;
			DATARESULTS : in CHAR_ARRAY_TYPE(0 to RESULT_BYTE_NUM-1);
			MAXINDEX : in BCD_ARRAY_TYPE(2 downto 0);
			BYTE : in std_logic_vector(7 downto 0);
			DATAREADY : in std_logic;
			NUMWORDS_bcd : out BCD_ARRAY_TYPE(2 downto 0);
			START: out std_logic;
			
			RXDONE : out std_logic;
			RXDATA : in std_logic_vector(7 downto 0);
			rxnow : in std_logic;
			ovErr : in std_logic; -- active high (overrun error)
			framErr : in std_logic; -- active high (frame error)
			
			TXDATA : out std_logic_vector(7 downto 0);
			TXNOW : out std_logic;
			TXDONE : in std_logic;
			
			SegOut0: out Character;
			SegOut1: out Character;
			SegOut2: out Character;
			SegOut3: out Character
		);
	end component;

	component dataConsume is
		port(
			CLK : in std_logic;
			RESET : in std_logic;
			
			START: in std_logic;
			NUMWORDS_BCD : in BCD_ARRAY_TYPE(2 downto 0);
			DATAREADY : out std_logic;
			BYTE : out std_logic_vector(7 downto 0);
			MAXINDEX : out BCD_ARRAY_TYPE(2 downto 0);
			DATARESULTS : out CHAR_ARRAY_TYPE(0 to RESULT_BYTE_NUM-1);
			SEQDONE : out std_logic;
			
			ctrlOut : out std_logic;
			ctrlIn : in std_logic;
			data : in std_logic_vector(7 downto 0)
		);
	end component;

	component DATAGEN is
		port(
			CLK : in std_logic;
			RESET : in std_logic;
			
			ctrlOut : out std_logic;
			ctrlIn : in std_logic;
			data : out std_logic_vector(7 downto 0)
		);
	end component;
	
	component Debugger is
		port(
			clk: in std_logic;
			SegSel : out std_logic_vector (3 downto 0);
			SegData : out std_logic_vector (7 downto 0);
			SegIn0: in Character;
			SegIn1: in Character;
			SegIn2: in Character;
			SegIn3: in Character
		);
	end component;

	signal sig_rx_frame_err, sig_rx_over_err, sig_rx_valid, sig_rx_done, sig_tx_done, sig_tx_now, sig_seqdone, sig_dataready, sig_start, sig_dp_ctrl1, sig_dp_ctrl2 : std_logic;
	signal sig_rx_data, sig_tx_data, sig_byte, sig_dp_data : std_logic_vector(7 downto 0);
	signal sig_data_results : CHAR_ARRAY_TYPE(0 to RESULT_BYTE_NUM-1);
	signal sig_maxindex, sig_numwords : BCD_ARRAY_TYPE(2 downto 0);
	signal sig_debug0, sig_debug1, sig_debug2, sig_debug3 : Character;

begin

rx : UART_RX_CTRL
	port map (
		sysclk => CLK,
		reset => RESET,
		
		RxD => RX_DATA,
		
		setFE => sig_rx_frame_err,
		setOE => sig_rx_over_err,
		dataReady => sig_rx_valid,
		rcvDataReg => sig_rx_data,
		rxDone => sig_rx_done
	);
	
tx: UART_TX_CTRL
	port map (
		CLK => CLK,
		
		UART_TX => TX_DATA,
		
		READY => sig_tx_done,
		SEND => sig_tx_now,
		DATA => sig_tx_data
	);

controller : CMDPROC
	port map (
		CLK => CLK,
		RESET => RESET,
		
		SEQDONE => sig_seqdone,
		DATARESULTS => sig_data_results,
		MAXINDEX => sig_maxindex,
		BYTE => sig_byte,
		DATAREADY => sig_dataready,
		NUMWORDS_bcd => sig_numwords,
		START => sig_start,
		
		RXDONE => sig_rx_done,
		RXDATA => sig_rx_data,
		rxnow => sig_rx_valid,
		ovErr => sig_rx_over_err, -- active high (overrun error)
		framErr => sig_rx_frame_err, -- active high (frame error)
		
		TXDATA => sig_tx_data,
		TXNOW => sig_tx_now,
		TXDONE => sig_tx_done,
		
		SegOut0 => sig_debug0,
		SegOut1 => sig_debug1,
		SegOut2 => sig_debug2,
		SegOut3 => sig_debug3
	);

data_processor : dataConsume
	port map (
		CLK => CLK,
		RESET => RESET,
		
		START => sig_start,
		NUMWORDS_BCD => sig_numwords,
		DATAREADY => sig_dataready,
		BYTE => sig_byte,
		MAXINDEX => sig_maxindex,
		DATARESULTS => sig_data_results,
		SEQDONE => sig_seqdone,
		
		CtrlIn => sig_dp_ctrl2,
		CtrlOut => sig_dp_ctrl1,
		Data => sig_dp_data
	);

data_generator : DATAGEN
	port map (
		CLK => CLK,
		RESET => RESET,
		
		ctrlIn => sig_dp_ctrl1,
		ctrlOut => sig_dp_ctrl2,
		data => sig_dp_data
	);

debuggerInst: debugger
	port map (
		clk => clk,
		SegSel => OUT_SegSel,
		SegData => OUT_SegData,
		SegIn0 => sig_debug0,
		SegIn1 => sig_debug1,
		SegIn2 => sig_debug2,
		SegIn3 => sig_debug3
	);
	
end;