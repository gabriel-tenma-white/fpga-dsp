library ieee;
library work;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;
use work.fft_types.all;
use work.channelizer1024_8;
use work.clockGating;

entity synthtest_channelizer1024_8 is
	port(
			inClk, outClk_unbuffered: in std_logic;
			din: in std_logic;
			dout: out std_logic);
end entity;
architecture a of synthtest_channelizer1024_8 is
	constant inBits: integer := 36;
	constant outBits: integer := 24*2 + 10 + 1;
	constant selBits: integer := 7;

	signal outClk: std_logic;
	signal sr1, srIn: signed(inBits-1 downto 0);
	signal din1, din2, din3, dout1, dout2, dout3: std_logic;

	signal ch_din, ch_dout: complex;
	signal ch_doutValid: std_logic;
	signal ch_doutChannel: unsigned(9 downto 0);

	signal moduleOut, moduleOut1, srOut, srOutNext: signed(outBits-1 downto 0);
	signal sel: unsigned(selBits-1 downto 0);
begin
	clkb: entity clockGating
		port map(clkInUnbuffered=>outClk_unbuffered,
				ce=>'1',
				clkOutGated=>outClk);

	-- input shift register
	din1 <= din when rising_edge(inClk);
	din2 <= din1 when rising_edge(inClk);
	din3 <= din2 when rising_edge(inClk);
	sr1 <= sr1(sr1'left-1 downto 0) & din3 when rising_edge(inClk);
	srIn <= sr1 when rising_edge(inClk);


	ch_din <= to_complex(srIn(17 downto 0), srIn(35 downto 18));
	inst: entity channelizer1024_8
		generic map(inBits=>18, outBits=>24)
		port map(
			inClk=>inClk, outClk=>outClk, outClk_unbuffered=>outClk_unbuffered,
			din=>ch_din, dinValid=>'1',
			dout=>ch_dout, doutValid=>ch_doutValid, doutChannel=>ch_doutChannel);

	moduleOut(23 downto 0) <= complex_re(ch_dout, 24);
	moduleOut(47 downto 24) <= complex_im(ch_dout, 24);
	moduleOut(57 downto 48) <= signed(ch_doutChannel);
	moduleOut(58) <= ch_doutValid;


	moduleOut1 <= moduleOut when rising_edge(outClk);


	sel <= sel+1 when rising_edge(outClk);
	srOutNext <= moduleOut1 when sel=0 else
				"0" & srOut(srOut'left downto 1);
	srOut <= srOutNext when rising_edge(outClk);
	dout1 <= srOut(0) when rising_edge(outClk);
	dout2 <= dout1 when rising_edge(outClk);
	dout3 <= dout2 when rising_edge(outClk);
	dout <= dout3 when rising_edge(outClk);
end a;
