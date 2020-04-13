library ieee;
library work;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;
use work.fft_types.all;
use work.sr_unsigned;
use work.sr_bit;
use work.complexRam;
use work.greyCDCSync;
use work.cdcSyncBit;

entity overlapStreamBuffer2 is
	generic(depthOrder, overlapOrder: integer;
			dataBits: integer;
			bitPermDelay: integer := 0;
			-- removes 1 or 2 registers from the doutIndex pipeline
			doutIndexAdvance: integer := 0;
			-- removes 1 or 2 registers from the doutValid pipeline
			doutValidAdvance: integer := 0;
			-- add an extra register to dout, doutValid, doutIndex, and doutPhase
			extraRegister: integer := 0);
	port(inClk, outClk: in std_logic;
		din: in complex;
		dinValid: in std_logic := '1';

		doutPhase, doutIndex: out unsigned(depthOrder-1 downto 0);
		dout: out complex;
		doutValid: out std_logic;

		-- external bit permutor
		bitPermIn: out unsigned(depthOrder-1 downto 0);
		bitPermOut: in unsigned(depthOrder-1 downto 0);

		-- internal control signals, for overlapStreamBuffer3 use only
		doutRAddr: out unsigned(depthOrder downto 0);
		doutCounter: out unsigned(depthOrder + overlapOrder downto 0)
		);
end entity;
architecture ar of overlapStreamBuffer2 is
	constant ramDepthOrder: integer := depthOrder + 1;
	constant upperDepthOrder: integer := overlapOrder + 1;
	constant lowerDepthOrder: integer := depthOrder-overlapOrder;

	function moveIntoWindow(i: unsigned; windowEnd: unsigned) return unsigned is
		variable ret: unsigned(i'left+1 downto i'right);
		variable iUpper, diff1: unsigned(windowEnd'range);
	begin
		-- only msb is changed, the rest are the same as original
		ret(i'range) := i;
		iUpper := "0" & i(i'left downto i'left-windowEnd'length+2);
		diff1 := iUpper - windowEnd;

		-- if (i - windowEnd) is larger than the window size (half of the numeric range)
		-- then we are in the window, so msb should be unchanged (set to 0);
		-- otherwise invert msb
		ret(ret'left) := not diff1(diff1'left);
		return ret;
	end function;

	-- inClk domain
	signal counterA: unsigned(ramDepthOrder-1 downto 0) := (others=>'0');
	signal counterAUpper: unsigned(upperDepthOrder-1 downto 0);

	-- outClk domain
	constant ramReadDelay: integer := 3;
	signal ramRAddr: unsigned(ramDepthOrder-1 downto 0);
	signal ramRData: complex;

	-- counter B consists of the read marker concatenated with the read index
	signal counterB: unsigned(depthOrder+upperDepthOrder-1 downto 0) := (others=>'0');
	signal counterBP1: unsigned(depthOrder+upperDepthOrder-1 downto 0) := (0=>'1', others=>'0');
	signal counterBIndex, index, readLogicalOffset: unsigned(depthOrder-1 downto 0) := (others=>'0');
	signal counterAUpper_outClk, readMarker, readMarker1: unsigned(upperDepthOrder-1 downto 0) := (others=>'0');
	signal outCE: std_logic := '0';
begin
	-- input side
	counterA <= counterA+1 when dinValid='1' and rising_edge(inClk);
	counterAUpper <= counterA(counterA'left downto lowerDepthOrder);

	-- ram
	ram1: entity complexRam
		generic map(dataBits=>dataBits, depthOrder=>ramDepthOrder)
		port map(wrclk=>inClk, rdclk=>outClk,
				rdaddr=>ramRAddr, rddata=>ramRData,
				wraddr=>counterA, wrdata=>din, wren=>dinValid);

	-- cdc
	sync_counter: entity greycdcsync
		generic map(width=>upperDepthOrder)
		port map(srcclk=>inClk, dstclk=>outClk,
			datain=>counterAUpper, dataout=>counterAUpper_outClk);

	-- outClk domain
	counterBP1 <= counterBP1+1 when outCE='1' and rising_edge(outClk);
	counterB <= counterBP1 when outCE='1' and rising_edge(outClk);
	readMarker <= counterB(counterB'left downto counterB'left-upperDepthOrder+1);
	counterBIndex <= counterB(counterBIndex'range);
	bitPermIn <= counterBIndex;

	-- delay readMarker by the same amount as counterBIndex
	sr_readMarker: entity sr_unsigned
		generic map(bits=>upperDepthOrder, len=>bitPermDelay)
		port map(clk=>outClk, din=>readMarker, dout=>readMarker1);
	ramRAddr <= moveIntoWindow(bitPermOut, readMarker1) when rising_edge(outClk);
	
	
	outCE <= '1' when counterAUpper_outClk /= readMarker else '0';
	readLogicalOffset <= readMarker1(overlapOrder-1 downto 0) & (lowerDepthOrder-1 downto 0=>'0');
	index <= bitPermOut - readLogicalOffset;

	sr_phase: entity sr_unsigned
		generic map(bits=>depthOrder, len=>bitPermDelay + ramReadDelay + extraRegister)
		port map(clk=>outClk, din=>counterBIndex, dout=>doutPhase);

	sr_index: entity sr_unsigned
		generic map(bits=>depthOrder, len=>ramReadDelay - doutIndexAdvance + extraRegister)
		port map(clk=>outClk, din=>index, dout=>doutIndex);

	sr_valid: entity sr_bit
		generic map(len=>bitPermDelay + ramReadDelay - doutValidAdvance + extraRegister, forceRegisters=>true)
		port map(clk=>outClk, din=>outCE, dout=>doutValid);

g1: if extraRegister = 0 generate
		dout <= ramRData;
	end generate;
g2: if extraRegister = 1 generate
		dout <= ramRData when rising_edge(outClk);
	end generate;

	-- output internal control signals
	sr_counter: entity sr_unsigned
		generic map(bits=>depthOrder+upperDepthOrder, len=>bitPermDelay + ramReadDelay)
		port map(clk=>outClk, din=>counterB, dout=>doutCounter);
	doutRAddr <= ramRAddr;
end ar;
