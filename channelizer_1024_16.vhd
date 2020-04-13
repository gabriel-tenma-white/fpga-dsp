library ieee;
library work;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;
use work.fft_types.all;
use work.sr_complex;
use work.overlapStreamBuffer2;
use work.windowMultiply1024_64;
use work.fft1024_scaled;
use work.clockGating;

-- 1024 channels, overlap factor 16; passband 0.5, stopband 0.95
entity channelizer1024_16 is
	generic(inBits, outBits: integer := 18);
	port(inClk, outClk, outClk_unbuffered: in std_logic;
			din: in complex;
			dinValid: in std_logic := '1';
			dout: out complex;
			doutValid: out std_logic;
			doutChannel: out unsigned(9 downto 0)
			);
end entity;
architecture a of channelizer1024_16 is
	constant depthOrder: integer := 10;
	constant twBits: integer := 17;
	constant windowDelay: integer := 6;
	signal window_dout, fft_din: complex;

	signal bpIn, bpOut: unsigned(depthOrder-1 downto 0);

	-- gated clock domain
	signal outClk_gated: std_logic;
	signal gated_din, gated_dout: complex;
	signal gated_phase, gated_index: unsigned(depthOrder-1 downto 0);
	signal gated_ce0, gated_ce, gated_ce_dup: std_logic;
	signal fft_phase: unsigned(depthOrder-1 downto 0);
	signal oPh, oPh0: unsigned(depthOrder-1 downto 0);

	attribute clock_buffer_type: string;
	attribute clock_buffer_type of outClk_unbuffered:signal is "NONE";
	attribute keep: string;
	attribute keep of gated_ce:signal is "TRUE";
	attribute keep of gated_ce_dup:signal is "TRUE";
begin
	overlap: entity overlapStreamBuffer2
		generic map(depthOrder=>10,
					overlapOrder=>4,
					dataBits=>inBits,
					bitPermDelay=>0,
					doutValidAdvance=>1,
					extraRegister=>0)
		port map(inClk=>inClk,
				outClk=>outClk,
				din=>din,
				dinValid=>dinValid,
				doutPhase=>gated_phase,
				doutIndex=>gated_index,
				dout=>gated_din,
				doutValid=>gated_ce0,
				bitPermIn=>bpIn,
				bitPermOut=>bpOut);

	-- bit order permutation for fft input reordering
	--bpOut <= bpIn(1)&bpIn(0)&bpIn(3)&bpIn(2)&bpIn(7)&bpIn(6)&bpIn(5)&bpIn(4)&bpIn(9)&bpIn(8);
	--bpOut <= bpIn(1)&bpIn(0)&bpIn(3)&bpIn(2)&bpIn(5)&bpIn(4)&bpIn(9)&bpIn(8)&bpIn(7)&bpIn(6);
	--bpOut <= bpIn(1)&bpIn(0)&bpIn(3)&bpIn(2)&bpIn(5)&bpIn(4)&bpIn(9)&bpIn(8)&bpIn(7)&bpIn(6);

	-- data input bit order: (9 downto 0) [0,1,2,3,4,5,9,8,7,6]
	bpOut <= bpIn(0)&bpIn(1)&bpIn(2)&bpIn(3)&bpIn(4)&bpIn(5)&bpIn(9)&bpIn(8)&bpIn(7)&bpIn(6);
	--bpOut <= bpIn;

	gated_ce <= gated_ce0 when rising_edge(outClk);
	gated_ce_dup <= gated_ce0 when rising_edge(outClk);
	cg: entity clockGating
		port map(clkInUnbuffered=>outClk_unbuffered,
				ce=>gated_ce_dup,
				clkOutGated=>outClk_gated);

	window: entity windowMultiply1024_64
		generic map(dataBits=>inBits, outBits=>outBits)
		port map(clk=>outClk_gated,
				din=>gated_din,
				index=>gated_index,
				dout=>window_dout);

	fft_phase <= gated_phase-windowDelay+1 when rising_edge(outClk_gated);
	fft_din <= window_dout;

	fft: entity fft1024_scaled
		generic map(dataBits=>outBits,
					twBits=>twBits)
		port map(clk=>outClk_gated,
					din=>fft_din,
					phase=>fft_phase,
					dout=>dout);
	oPh0 <= fft_phase-1191+2 when rising_edge(outClk_gated);
	oPh <= oPh0 when rising_edge(outClk_gated);
	doutValid <= gated_ce;

	doutChannel <= oPh(0)&oPh(1)&oPh(2)&oPh(3)&oPh(4)&oPh(5)&oPh(6)&oPh(7)&oPh(8)&oPh(9);
	--doutChannel <= oPh(1)&oPh(0)&oPh(3)&oPh(2)&oPh(5)&oPh(4)&oPh(7)&oPh(6)&oPh(9)&oPh(8);
	--doutChannel <= oPh(0)&oPh(1)&oPh(3)&oPh(2)&oPh(4)&oPh(5)&oPh(7)&oPh(6)&oPh(8)&oPh(9);
	--doutChannel <= oPh;
end a;
