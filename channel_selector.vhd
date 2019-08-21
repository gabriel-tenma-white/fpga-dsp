library ieee;
library work;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;
use work.fft_types.all;
use work.dcram;

-- select specific channels from the output of a channelizer;
-- an internal ram contains the selected channel numbers
-- (which must be sorted by the same order as the channelizer output).
-- The MSB of each ram word controls doutLast when that channel is output.

entity channelSelector is
	generic(dataBits, channelBits, ramDepthOrder: integer);
	port(clk: in std_logic;
			din: in complex;
			dinChannel: in unsigned(channelBits-1 downto 0);
			dinValid: in std_logic := '1';
			dout: out complex;
			doutValid, doutLast: out std_logic;

		-- channels ram access
			ramWClk: in std_logic;
			ramWEn: in std_logic;
			ramWAddr: in unsigned(ramDepthOrder-1 downto 0);
			ramWData: in unsigned(channelBits downto 0)
			);
end entity;
architecture a of channelSelector is
	-- counter and ram pipeline
	signal counterCE, counterRst: std_logic;
	signal currChannelValid, currChannelIsLast: std_logic;
	signal counterValid, counterValidNext: std_logic_vector(1 downto 0);
	signal currChannel: unsigned(channelBits-1 downto 0);
	signal ramRData: std_logic_vector(channelBits downto 0);
	signal counter, counterNext: unsigned(ramDepthOrder-1 downto 0);

	-- compare & capture
	signal compEq, doAdvance, doAdvanceNext: std_logic;
begin
	channelsRam: entity dcram
		generic map(width=>channelBits+1,
					depthOrder=>ramDepthOrder,
					outputRegistered=>true)
		port map(rdclk=>clk, wrclk=>ramWClk,
				rden=>counterCE,
				rdaddr=>counter,
				rddata=>ramRData,
				wren=>ramWEn,
				wraddr=>ramWAddr,
				wrdata=>std_logic_vector(ramWData));
	currChannel <= unsigned(ramRData(currChannel'range));
	currChannelIsLast <= ramRData(ramRData'left);


	-- counter & ram pipeline

	counterNext <= (others=>'0') when counterRst='1' else
					counter+1 when counterCE='1' else
					counter;
	counter <= counterNext when rising_edge(clk);

	counterValidNext <=
			(others=>'0') when counterRst='1' else
			counterValid(0 downto 0) & "1" when counterCE='1' else
			counterValid;
	counterValid <= counterValidNext when rising_edge(clk);
	currChannelValid <= counterValid(1);

	counterCE <= (not currChannelValid) or doAdvance;
	counterRst <= '1' when dinValid='1' and dinChannel=(dinChannel'range=>'1') else '0';

	-- compare & capture
	compEq <= '1' when dinChannel=currChannel else '0';
	doAdvanceNext <= compEq and dinValid and currChannelValid;
	doAdvance <= doAdvanceNext when rising_edge(clk);

	dout <= din when rising_edge(clk);
	doutValid <= doAdvance;
	doutLast <= currChannelIsLast when rising_edge(clk);
end a;
