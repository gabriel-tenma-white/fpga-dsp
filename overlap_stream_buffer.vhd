library ieee;
library work;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;
use work.fft_types.all;
use work.sr_unsigned;
use work.sr_bit;
use work.complexRam;
use work.dcfifo;
use work.greyCDCSync;
use work.cdcSyncBit;

entity overlapStreamBuffer is
	generic(depthOrder, overlapOrder: integer;
			dataBits: integer;
			bitPermDelay: integer := 0);
	port(inClk, intClk, outClk: in std_logic;
		din: in complex;
		dinValid: in std_logic := '1';

		doutPhase, doutIndex: out unsigned(depthOrder-1 downto 0);
		dout: out complex;
		doutValid: out std_logic;

		-- external bit permutor
		bitPermIn: out unsigned(depthOrder-1 downto 0);
		bitPermOut: in unsigned(depthOrder-1 downto 0)
		);
end entity;
architecture ar of overlapStreamBuffer is
	constant lowerDepthOrder: integer := depthOrder-overlapOrder;
	constant fifoDepthOrder: integer := depthOrder-overlapOrder+1;

	signal fifoIn, fifoOut: std_logic_vector(dataBits*2-1 downto 0);
	signal fifoRdLeft: unsigned(fifoDepthOrder-1 downto 0) := (others=>'0');

	-- intClk domain
	signal counterA: unsigned(depthOrder-1 downto 0) := (others=>'0');
	signal intCE: std_logic;
	signal fifoCanRead, fifoCanRead1: std_logic := '0';
	signal indicator_intClk, lastIndicator_intClk: std_logic := '0';
	signal ramWAddr: unsigned(depthOrder-1 downto 0);
	signal ramWData: complex;
	signal ramWEn: std_logic;
	type stateA_t is (WRITING, WAITING);
	signal stateA, stateANext: stateA_t := WRITING;

	-- outClk domain
	constant ramReadDelay: integer := 2;
	signal ramRAddr: unsigned(depthOrder-1 downto 0);
	signal counterB, index: unsigned(depthOrder-1 downto 0) := (others=>'0');
	signal counterA_outClk, counterAPrev_outClk: unsigned(depthOrder-1 downto 0) := (others=>'0');
	signal outCE, indicator, trigger, triggerNext: std_logic := '0';
	type stateB_t is (WAITING, RUNNING);
	signal stateB, stateBNext: stateB_t := WAITING;
begin
	-- input side
	fifo: entity dcfifo
		generic map(width=>dataBits*2, depthOrder=>fifoDepthOrder)
		port map(wrclk=>inClk, rdClk=>intClk,
				wrvalid=>dinValid,
				wrready=>open,
				wrdata=>fifoIn,
				rdvalid=>open,
				rdready=>intCE,
				rddata=>fifoOut,
				rdleft=>fifoRdLeft);
	fifoIn <= complex_pack(din, dataBits);
	fifoCanRead <= '1' when fifoRdLeft >= 4 else '0';
	fifoCanRead1 <= fifoCanRead when rising_edge(intClk);

	-- intClk domain
	counterA <= counterA+1 when intCE='1' and rising_edge(intClk);

	-- state machine
	stateANext <=
		WAITING when stateA=WRITING and intCE='1' and counterA(lowerDepthOrder-1 downto 0) = (lowerDepthOrder-1 downto 0=>'1') else
		WRITING when stateA=WAITING and lastIndicator_intClk /= indicator_intClk else
		stateA;
	stateA <= stateANext when rising_edge(intClk);

	intCE <= fifoCanRead1 when stateA=WRITING else '0';
	lastIndicator_intClk <= indicator_intClk when stateA=WRITING and stateANext=WAITING and rising_edge(intClk);

	ramWData <= complex_unpack(fifoOut);
	ramWAddr <= counterA;
	ramWEn <= intCE;

	-- ram
	ram1: entity complexRam
		generic map(dataBits=>dataBits, depthOrder=>depthOrder)
		port map(wrclk=>intClk, rdclk=>outClk,
				rdaddr=>ramRAddr, rddata=>dout,
				wraddr=>ramWAddr, wrdata=>ramWData, wren=>ramWEn);

	-- cdc
	sync_counter: entity greycdcsync
		generic map(width=>depthOrder)
		port map(srcclk=>intClk, dstclk=>outClk,
			datain=>counterA, dataout=>counterA_outClk);

	sync_indicator: entity cdcsyncbit
		port map(dstclk=>intClk, datain=>indicator, dataout=>indicator_intClk);

	-- outClk domain
	counterB <= counterB+1 when outCE='1' and rising_edge(outClk);
	bitPermIn <= counterB;
	ramRAddr <= bitPermOut;
	counterAPrev_outClk <= counterA_outClk when rising_edge(outClk);
	triggerNext <= '1' when counterAPrev_outClk(counterA'left downto lowerDepthOrder)
							/= counterA_outClk(counterA'left downto lowerDepthOrder)
							else '0';
	trigger <= triggerNext when rising_edge(outClk);
	
	stateBNext <= RUNNING when stateB=WAITING and trigger='1' else
					WAITING when stateB=RUNNING and counterB=(counterB'range=>'1') else
					stateB;
	stateB <= stateBNext when rising_edge(outClk);
	indicator <= not indicator when stateB=RUNNING and counterB=(counterB'range=>'1') and rising_edge(outClk);
	outCE <= '1' when stateB=RUNNING else '0';
	index <= bitPermOut + counterA_outClk;

	sr_phase: entity sr_unsigned
		generic map(bits=>depthOrder, len=>bitPermDelay + ramReadDelay)
		port map(clk=>outClk, din=>counterB, dout=>doutPhase);

	sr_index: entity sr_unsigned
		generic map(bits=>depthOrder, len=>ramReadDelay)
		port map(clk=>outClk, din=>index, dout=>doutIndex);

	sr_valid: entity sr_bit
		generic map(len=>bitPermDelay + ramReadDelay)
		port map(clk=>outClk, din=>outCE, dout=>doutValid);

end ar;
