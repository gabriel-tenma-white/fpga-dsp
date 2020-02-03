library ieee;
library work;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;
use work.fft_types.all;
use work.overlapStreamBuffer2;
use work.overlapStreamBuffer3SubUnit;

entity overlapStreamBuffer3 is
	generic(frameSizeOrder, overlapOrder, folding: integer;
			dataBits: integer;
			bitPermDelay: integer := 0);
	port(inClk, outClk: in std_logic;
		din: in complex;
		dinValid: in std_logic := '1';

		doutPhase, doutIndex: out unsigned(frameSizeOrder-1 downto 0);
		dout: out complexArray(folding-1 downto 0);
		doutValid: out std_logic;

		-- external bit permutor
		bitPermIn: out unsigned(frameSizeOrder-1 downto 0);
		bitPermOut: in unsigned(frameSizeOrder-1 downto 0)
		);
end entity;
architecture ar of overlapStreamBuffer3 is
	-- outputs of the first stage
	signal rAddr: unsigned(frameSizeOrder downto 0);
	signal iIndex: unsigned(frameSizeOrder-1 downto 0);
	signal iPhase: unsigned(frameSizeOrder+overlapOrder downto 0);
	signal doutPhase0: unsigned(frameSizeOrder-1 downto 0);
	signal iOut: complex;
	signal iValid: std_logic;

	-- outputs
	signal outputs: complexArray(folding-1 downto 0);
begin
	master: entity overlapStreamBuffer2
		generic map(
			depthOrder=>frameSizeOrder,
			overlapOrder=>overlapOrder,
			dataBits=>dataBits,
			bitPermDelay=>bitPermDelay)
		port map(
			inClk=>inClk,
			outClk=>outClk,
			din=>din,
			dinValid=>dinValid,
			doutPhase=>doutPhase0,
			doutIndex=>iIndex,
			dout=>iOut,
			doutValid=>iValid,
			bitPermIn=>bitPermIn,
			bitPermOut=>bitPermOut,
			doutRAddr=>rAddr,
			doutCounter=>iPhase);

	outputs(folding-1) <= iOut;

	-- subUnit chain
genChain:
	for I in 0 to folding-2 generate
		slave: entity overlapStreamBuffer3SubUnit
			generic map(
				frameSizeOrder=>frameSizeOrder,
				overlapOrder=>overlapOrder,
				dataBits=>dataBits)
			port map(
				clk=>outClk,
				we=>iValid,
				din=>outputs(I+1),
				dinIndex=>iIndex,
				phase=>iPhase,
				rAddr=>rAddr,
				dout=>outputs(I));
	end generate;

	doutValid <= iValid when rising_edge(outClk);
	doutIndex <= iIndex when rising_edge(outClk);
	doutPhase <= doutPhase0 when rising_edge(outClk);
	dout <= outputs when rising_edge(outClk);
end ar;
