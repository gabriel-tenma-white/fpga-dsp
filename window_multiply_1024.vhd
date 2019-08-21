

library ieee;
library work;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;
use work.fft_types.all;

-- delay is 5 cycles

entity windowMultiply1024 is
	generic(dataBits, outBits: integer := 18);
	port(clk: in std_logic;
			din: in complex;
			index: in unsigned(10-1 downto 0);
			dout: out complex
			);
end entity;
architecture a of windowMultiply1024 is
	constant romDepthOrder: integer := 10;
	constant romDepth: integer := 2**romDepthOrder;
	constant romWidth: integer := 18;
	--ram
	type ram1t is array(0 to romDepth-1) of
		std_logic_vector(romWidth-1 downto 0);
	signal rom: ram1t;
	signal addr1: unsigned(romDepthOrder-1 downto 0);
	signal data0, data1, data2: std_logic_vector(romWidth-1 downto 0);
	signal coeff: signed(romWidth-1 downto 0);

	signal din1, din2, din3: complex;

	-- multiplier
	signal multOutRe, multOutIm: signed(dataBits+romWidth-1 downto 0);
	signal multOut, multOut1: complex;

	attribute keep: string;
	attribute keep of din2: signal is "true";
	attribute keep of data2: signal is "true";
begin
	-- coefficient rom
	addr1 <= index; -- when rising_edge(clk);
	data0 <= rom(to_integer(addr1));
	data1 <= data0 when rising_edge(clk);
	data2 <= data1 when rising_edge(clk);
	coeff <= signed(data2) when rising_edge(clk);

	-- delay data
	din1 <= din when rising_edge(clk);
	din2 <= din1 when rising_edge(clk);
	din3 <= din2 when rising_edge(clk);

	-- multiply
	multOutRe <= coeff * complex_re(din3, dataBits);
	multOutIm <= coeff * complex_im(din3, dataBits);

	multOut <= to_complex(multOutRe(multOutRe'left downto multOutRe'left-outBits+1),
						multOutIm(multOutIm'left downto multOutIm'left-outBits+1));
	multOut1 <= multOut when rising_edge(clk);
	dout <= multOut1 when rising_edge(clk);

	-- rom
	rom <= (

"111110010100011100" , "111111111100010111" , "111111111100010011" , "111111111100010001" , "111111111100001110" , "111111111100001110" , "111111111100001011" , "111111111100001100" , "111111111100001010" , "111111111100001100" ,
"111111111100001011" , "111111111100001110" , "111111111100001101" , "111111111100010001" , "111111111100010001" , "111111111100011111" , "111111111100101000" , "111111111100100011" , "111111111100101111" , "111111111100110100" ,
"111111111100111110" , "111111111101000101" , "111111111101010000" , "111111111101011001" , "111111111101100110" , "111111111101110001" , "111111111101111111" , "111111111110001101" , "111111111110011110" , "111111111110101110" ,
"111111111111000000" , "111111111111001110" , "111111111111100011" , "111111111111111000" , "000000000000001100" , "000000000000100011" , "000000000000111010" , "000000000001010010" , "000000000001101100" , "000000000010000111" ,
"000000000010100011" , "000000000011000000" , "000000000011011111" , "000000000011111110" , "000000000100011111" , "000000000101000000" , "000000000101100100" , "000000000110001010" , "000000000110101110" , "000000000111010110" ,
"000000000111111110" , "000000001000101000" , "000000001001010011" , "000000001001111111" , "000000001010101101" , "000000001011011100" , "000000001100001100" , "000000001100111110" , "000000001101110001" , "000000001110100101" ,
"000000001111011011" , "000000010000010011" , "000000010001001010" , "000000010010000100" , "000000010011000000" , "000000010011111100" , "000000010100111010" , "000000010101111001" , "000000010110111010" , "000000010111111100" ,
"000000011001000000" , "000000011010000100" , "000000011011001010" , "000000011100010010" , "000000011101011011" , "000000011110100101" , "000000011111110000" , "000000100000111100" , "000000100010001011" , "000000100011011001" ,
"000000100100101010" , "000000100101111011" , "000000100111001110" , "000000101000100010" , "000000101001111000" , "000000101011001110" , "000000101100100101" , "000000101101111110" , "000000101111011000" , "000000110000110010" ,
"000000110010001110" , "000000110011101011" , "000000110101001001" , "000000110110100111" , "000000111000000110" , "000000111001100111" , "000000111011001000" , "000000111100101010" , "000000111110001101" , "000000111111110000" ,
"000001000001010100" , "000001000010111001" , "000001000100011110" , "000001000110000100" , "000001000111101010" , "000001001001010001" , "000001001010111000" , "000001001100011111" , "000001001110000111" , "000001001111101111" ,
"000001010001010111" , "000001010011000000" , "000001010100101000" , "000001010110010000" , "000001010111111001" , "000001011001100001" , "000001011011001001" , "000001011100110001" , "000001011110011001" , "000001100000000000" ,
"000001100001100111" , "000001100011001101" , "000001100100110011" , "000001100110011001" , "000001100111111101" , "000001101001100001" , "000001101011000100" , "000001101100100110" , "000001101110001000" , "000001101111101000" ,
"000001110001001000" , "000001110010100110" , "000001110100000011" , "000001110101011110" , "000001110110111000" , "000001111000010001" , "000001111001101000" , "000001111010111110" , "000001111100010010" , "000001111101100100" ,
"000001111110110101" , "000010000000000011" , "000010000001010000" , "000010000010011010" , "000010000011100010" , "000010000100101001" , "000010000101101100" , "000010000110101110" , "000010000111101101" , "000010001000101001" ,
"000010001001100011" , "000010001010011010" , "000010001011001111" , "000010001100000000" , "000010001100101111" , "000010001101011010" , "000010001110000011" , "000010001110101001" , "000010001111001011" , "000010001111101010" ,
"000010010000000101" , "000010010000011101" , "000010010000110010" , "000010010001000011" , "000010010001010000" , "000010010001011010" , "000010010001011111" , "000010010001100001" , "000010010001011111" , "000010010001011001" ,
"000010010001001111" , "000010010001000001" , "000010010000101111" , "000010010000011000" , "000010001111111101" , "000010001111011110" , "000010001110111010" , "000010001110010010" , "000010001101100101" , "000010001100110011" ,
"000010001011111110" , "000010001011000011" , "000010001010000011" , "000010001000111111" , "000010000111110110" , "000010000110101000" , "000010000101010110" , "000010000011111110" , "000010000010100001" , "000010000001000000" ,
"000001111111011001" , "000001111101101101" , "000001111011111100" , "000001111010000111" , "000001111000001100" , "000001110110001011" , "000001110100000110" , "000001110001111100" , "000001101111101100" , "000001101101010111" ,
"000001101010111101" , "000001101000011110" , "000001100101111010" , "000001100011010000" , "000001100000100001" , "000001011101101101" , "000001011010110100" , "000001010111110110" , "000001010100110011" , "000001010001101011" ,
"000001001110011101" , "000001001011001011" , "000001000111110011" , "000001000100010111" , "000001000000110110" , "000000111101001111" , "000000111001100100" , "000000110101110100" , "000000110010000000" , "000000101110000111" ,
"000000101010001001" , "000000100110000110" , "000000100001111111" , "000000011101110100" , "000000011001100100" , "000000010101010000" , "000000010000111000" , "000000001100011100" , "000000000111111011" , "000000000011010111" ,
"111111111110101111" , "111111111010000011" , "111111110101010011" , "111111110000100000" , "111111101011101010" , "111111100110110000" , "111111100001110010" , "111111011100110010" , "111111010111101111" , "111111010010101001" ,
"111111001101100000" , "111111001000010100" , "111111000011000110" , "111110111101110110" , "111110111000100100" , "111110110011001111" , "111110101101111000" , "111110101000100000" , "111110100011000110" , "111110011101101011" ,
"111110011000001110" , "111110010010110001" , "111110001101010010" , "111110000111110010" , "111110000010010010" , "111101111100110001" , "111101110111010000" , "111101110001101111" , "111101101100001110" , "111101100110101110" ,
"111101100001001101" , "111101011011101110" , "111101010110001111" , "111101010000110001" , "111101001011010100" , "111101000101111001" , "111101000000011111" , "111100111011000111" , "111100110101110001" , "111100110000011101" ,
"111100101011001100" , "111100100101111101" , "111100100000110001" , "111100011011101001" , "111100010110100011" , "111100010001100001" , "111100001100100010" , "111100000111101000" , "111100000010110001" , "111011111101111111" ,
"111011111001010001" , "111011110100101001" , "111011110000000101" , "111011101011100110" , "111011100111001101" , "111011100010111001" , "111011011110101100" , "111011011010100100" , "111011010110100011" , "111011010010101000" ,
"111011001110110100" , "111011001011000111" , "111011000111100001" , "111011000100000011" , "111011000000101100" , "111010111101011110" , "111010111010010111" , "111010110111011000" , "111010110100100011" , "111010110001110101" ,
"111010101111010001" , "111010101100110110" , "111010101010100101" , "111010101000011101" , "111010100110011110" , "111010100100101010" , "111010100011000000" , "111010100001100000" , "111010100000001100" , "111010011111000001" ,
"111010011110000010" , "111010011101001110" , "111010011100100110" , "111010011100001001" , "111010011011111000" , "111010011011110011" , "111010011011111010" , "111010011100001101" , "111010011100101101" , "111010011101011001" ,
"111010011110010011" , "111010011111011001" , "111010100000101100" , "111010100010001101" , "111010100011111011" , "111010100101110111" , "111010101000000001" , "111010101010011000" , "111010101100111110" , "111010101111110001" ,
"111010110010110011" , "111010110110000100" , "111010111001100011" , "111010111101010000" , "111011000001001101" , "111011000101011000" , "111011001001110010" , "111011001110011011" , "111011010011010011" , "111011011000011011" ,
"111011011101110010" , "111011100011011000" , "111011101001001101" , "111011101111010011" , "111011110101100111" , "111011111100001011" , "111100000010111111" , "111100001010000011" , "111100010001010110" , "111100011000111001" ,
"111100100000101100" , "111100101000101110" , "111100110001000001" , "111100111001100011" , "111101000010010101" , "111101001011010110" , "111101010100101000" , "111101011110001001" , "111101100111111001" , "111101110001111010" ,
"111101111100001010" , "111110000110101001" , "111110010001011000" , "111110011100010111" , "111110100111100101" , "111110110011000010" , "111110111110101110" , "111111001010101010" , "111111010110110101" , "111111100011001110" ,
"111111101111110110" , "111111111100101101" , "000000001001110011" , "000000010111000111" , "000000100100101001" , "000000110010011010" , "000001000000011001" , "000001001110100101" , "000001011100111111" , "000001101011100111" ,
"000001111010011100" , "000010001001011110" , "000010011000101110" , "000010101000001010" , "000010110111110011" , "000011000111101000" , "000011010111101001" , "000011100111110110" , "000011111000010000" , "000100001000110100" ,
"000100011001100100" , "000100101010011111" , "000100111011100101" , "000101001100110101" , "000101011110010000" , "000101101111110101" , "000110000001100011" , "000110010011011011" , "000110100101011100" , "000110110111100110" ,
"000111001001111001" , "000111011100010100" , "000111101110111000" , "001000000001100010" , "001000010100010101" , "001000100111001110" , "001000111010001110" , "001001001101010101" , "001001100000100010" , "001001110011110101" ,
"001010000111001101" , "001010011010101010" , "001010101110001100" , "001011000001110011" , "001011010101011110" , "001011101001001100" , "001011111100111110" , "001100010000110011" , "001100100100101011" , "001100111000100100" ,
"001101001100100000" , "001101100000011110" , "001101110100011100" , "001110001000011100" , "001110011100011011" , "001110110000011011" , "001111000100011011" , "001111011000011010" , "001111101100011000" , "010000000000010100" ,
"010000010100001110" , "010000101000000111" , "010000111011111100" , "010001001111101111" , "010001100011011110" , "010001110111001001" , "010010001010110000" , "010010011110010011" , "010010110001110001" , "010011000101001001" ,
"010011011000011011" , "010011101011100111" , "010011111110101101" , "010100010001101100" , "010100100100100011" , "010100110111010011" , "010101001001111011" , "010101011100011010" , "010101101110110000" , "010110000000111101" ,
"010110010011000001" , "010110100100111010" , "010110110110101001" , "010111001000001110" , "010111011001100111" , "010111101010110101" , "010111111011110110" , "011000001100101100" , "011000011101010101" , "011000101101110010" ,
"011000111110000001" , "011001001110000010" , "011001011101110101" , "011001101101011010" , "011001111100110001" , "011010001011111000" , "011010011010110001" , "011010101001011001" , "011010110111110010" , "011011000101111011" ,
"011011010011110011" , "011011100001011010" , "011011101110110000" , "011011111011110100" , "011100001000100111" , "011100010101001000" , "011100100001010111" , "011100101101010011" , "011100111000111100" , "011101000100010010" ,
"011101001111010101" , "011101011010000101" , "011101100100100001" , "011101101110101000" , "011101111000011100" , "011110000001111011" , "011110001011000101" , "011110010011111010" , "011110011100011011" , "011110100100100110" ,
"011110101100011100" , "011110110011111100" , "011110111011000110" , "011111000001111011" , "011111001000011001" , "011111001110100001" , "011111010100010011" , "011111011001101111" , "011111011110110011" , "011111100011100001" ,
"011111100111111000" , "011111101011111001" , "011111101111100010" , "011111110010110100" , "011111110101101111" , "011111111000010011" , "011111111010011111" , "011111111100010101" , "011111111101110010" , "011111111110111001" ,
"011111111111101000" , "011111111111111111" , "011111111111111111" , "011111111111101000" , "011111111110111001" , "011111111101110010" , "011111111100010101" , "011111111010011111" , "011111111000010011" , "011111110101101111" ,
"011111110010110100" , "011111101111100010" , "011111101011111001" , "011111100111111000" , "011111100011100001" , "011111011110110011" , "011111011001101111" , "011111010100010011" , "011111001110100001" , "011111001000011001" ,
"011111000001111011" , "011110111011000110" , "011110110011111100" , "011110101100011100" , "011110100100100110" , "011110011100011011" , "011110010011111010" , "011110001011000101" , "011110000001111011" , "011101111000011100" ,
"011101101110101000" , "011101100100100001" , "011101011010000101" , "011101001111010101" , "011101000100010010" , "011100111000111100" , "011100101101010011" , "011100100001010111" , "011100010101001000" , "011100001000100111" ,
"011011111011110100" , "011011101110110000" , "011011100001011010" , "011011010011110011" , "011011000101111011" , "011010110111110010" , "011010101001011001" , "011010011010110001" , "011010001011111000" , "011001111100110001" ,
"011001101101011010" , "011001011101110101" , "011001001110000010" , "011000111110000001" , "011000101101110010" , "011000011101010101" , "011000001100101100" , "010111111011110110" , "010111101010110101" , "010111011001100111" ,
"010111001000001110" , "010110110110101001" , "010110100100111010" , "010110010011000001" , "010110000000111101" , "010101101110110000" , "010101011100011010" , "010101001001111011" , "010100110111010011" , "010100100100100011" ,
"010100010001101100" , "010011111110101101" , "010011101011100111" , "010011011000011011" , "010011000101001001" , "010010110001110001" , "010010011110010011" , "010010001010110000" , "010001110111001001" , "010001100011011110" ,
"010001001111101111" , "010000111011111100" , "010000101000000111" , "010000010100001110" , "010000000000010100" , "001111101100011000" , "001111011000011010" , "001111000100011011" , "001110110000011011" , "001110011100011011" ,
"001110001000011100" , "001101110100011100" , "001101100000011110" , "001101001100100000" , "001100111000100100" , "001100100100101011" , "001100010000110011" , "001011111100111110" , "001011101001001100" , "001011010101011110" ,
"001011000001110011" , "001010101110001100" , "001010011010101010" , "001010000111001101" , "001001110011110101" , "001001100000100010" , "001001001101010101" , "001000111010001110" , "001000100111001110" , "001000010100010101" ,
"001000000001100010" , "000111101110111000" , "000111011100010100" , "000111001001111001" , "000110110111100110" , "000110100101011100" , "000110010011011011" , "000110000001100011" , "000101101111110101" , "000101011110010000" ,
"000101001100110101" , "000100111011100101" , "000100101010011111" , "000100011001100100" , "000100001000110100" , "000011111000010000" , "000011100111110110" , "000011010111101001" , "000011000111101000" , "000010110111110011" ,
"000010101000001010" , "000010011000101110" , "000010001001011110" , "000001111010011100" , "000001101011100111" , "000001011100111111" , "000001001110100101" , "000001000000011001" , "000000110010011010" , "000000100100101001" ,
"000000010111000111" , "000000001001110011" , "111111111100101101" , "111111101111110110" , "111111100011001110" , "111111010110110101" , "111111001010101010" , "111110111110101110" , "111110110011000010" , "111110100111100101" ,
"111110011100010111" , "111110010001011000" , "111110000110101001" , "111101111100001010" , "111101110001111010" , "111101100111111001" , "111101011110001001" , "111101010100101000" , "111101001011010110" , "111101000010010101" ,
"111100111001100011" , "111100110001000001" , "111100101000101110" , "111100100000101100" , "111100011000111001" , "111100010001010110" , "111100001010000011" , "111100000010111111" , "111011111100001011" , "111011110101100111" ,
"111011101111010011" , "111011101001001101" , "111011100011011000" , "111011011101110010" , "111011011000011011" , "111011010011010011" , "111011001110011011" , "111011001001110010" , "111011000101011000" , "111011000001001101" ,
"111010111101010000" , "111010111001100011" , "111010110110000100" , "111010110010110011" , "111010101111110001" , "111010101100111110" , "111010101010011000" , "111010101000000001" , "111010100101110111" , "111010100011111011" ,
"111010100010001101" , "111010100000101100" , "111010011111011001" , "111010011110010011" , "111010011101011001" , "111010011100101101" , "111010011100001101" , "111010011011111010" , "111010011011110011" , "111010011011111000" ,
"111010011100001001" , "111010011100100110" , "111010011101001110" , "111010011110000010" , "111010011111000001" , "111010100000001100" , "111010100001100000" , "111010100011000000" , "111010100100101010" , "111010100110011110" ,
"111010101000011101" , "111010101010100101" , "111010101100110110" , "111010101111010001" , "111010110001110101" , "111010110100100011" , "111010110111011000" , "111010111010010111" , "111010111101011110" , "111011000000101100" ,
"111011000100000011" , "111011000111100001" , "111011001011000111" , "111011001110110100" , "111011010010101000" , "111011010110100011" , "111011011010100100" , "111011011110101100" , "111011100010111001" , "111011100111001101" ,
"111011101011100110" , "111011110000000101" , "111011110100101001" , "111011111001010001" , "111011111101111111" , "111100000010110001" , "111100000111101000" , "111100001100100010" , "111100010001100001" , "111100010110100011" ,
"111100011011101001" , "111100100000110001" , "111100100101111101" , "111100101011001100" , "111100110000011101" , "111100110101110001" , "111100111011000111" , "111101000000011111" , "111101000101111001" , "111101001011010100" ,
"111101010000110001" , "111101010110001111" , "111101011011101110" , "111101100001001101" , "111101100110101110" , "111101101100001110" , "111101110001101111" , "111101110111010000" , "111101111100110001" , "111110000010010010" ,
"111110000111110010" , "111110001101010010" , "111110010010110001" , "111110011000001110" , "111110011101101011" , "111110100011000110" , "111110101000100000" , "111110101101111000" , "111110110011001111" , "111110111000100100" ,
"111110111101110110" , "111111000011000110" , "111111001000010100" , "111111001101100000" , "111111010010101001" , "111111010111101111" , "111111011100110010" , "111111100001110010" , "111111100110110000" , "111111101011101010" ,
"111111110000100000" , "111111110101010011" , "111111111010000011" , "111111111110101111" , "000000000011010111" , "000000000111111011" , "000000001100011100" , "000000010000111000" , "000000010101010000" , "000000011001100100" ,
"000000011101110100" , "000000100001111111" , "000000100110000110" , "000000101010001001" , "000000101110000111" , "000000110010000000" , "000000110101110100" , "000000111001100100" , "000000111101001111" , "000001000000110110" ,
"000001000100010111" , "000001000111110011" , "000001001011001011" , "000001001110011101" , "000001010001101011" , "000001010100110011" , "000001010111110110" , "000001011010110100" , "000001011101101101" , "000001100000100001" ,
"000001100011010000" , "000001100101111010" , "000001101000011110" , "000001101010111101" , "000001101101010111" , "000001101111101100" , "000001110001111100" , "000001110100000110" , "000001110110001011" , "000001111000001100" ,
"000001111010000111" , "000001111011111100" , "000001111101101101" , "000001111111011001" , "000010000001000000" , "000010000010100001" , "000010000011111110" , "000010000101010110" , "000010000110101000" , "000010000111110110" ,
"000010001000111111" , "000010001010000011" , "000010001011000011" , "000010001011111110" , "000010001100110011" , "000010001101100101" , "000010001110010010" , "000010001110111010" , "000010001111011110" , "000010001111111101" ,
"000010010000011000" , "000010010000101111" , "000010010001000001" , "000010010001001111" , "000010010001011001" , "000010010001011111" , "000010010001100001" , "000010010001011111" , "000010010001011010" , "000010010001010000" ,
"000010010001000011" , "000010010000110010" , "000010010000011101" , "000010010000000101" , "000010001111101010" , "000010001111001011" , "000010001110101001" , "000010001110000011" , "000010001101011010" , "000010001100101111" ,
"000010001100000000" , "000010001011001111" , "000010001010011010" , "000010001001100011" , "000010001000101001" , "000010000111101101" , "000010000110101110" , "000010000101101100" , "000010000100101001" , "000010000011100010" ,
"000010000010011010" , "000010000001010000" , "000010000000000011" , "000001111110110101" , "000001111101100100" , "000001111100010010" , "000001111010111110" , "000001111001101000" , "000001111000010001" , "000001110110111000" ,
"000001110101011110" , "000001110100000011" , "000001110010100110" , "000001110001001000" , "000001101111101000" , "000001101110001000" , "000001101100100110" , "000001101011000100" , "000001101001100001" , "000001100111111101" ,
"000001100110011001" , "000001100100110011" , "000001100011001101" , "000001100001100111" , "000001100000000000" , "000001011110011001" , "000001011100110001" , "000001011011001001" , "000001011001100001" , "000001010111111001" ,
"000001010110010000" , "000001010100101000" , "000001010011000000" , "000001010001010111" , "000001001111101111" , "000001001110000111" , "000001001100011111" , "000001001010111000" , "000001001001010001" , "000001000111101010" ,
"000001000110000100" , "000001000100011110" , "000001000010111001" , "000001000001010100" , "000000111111110000" , "000000111110001101" , "000000111100101010" , "000000111011001000" , "000000111001100111" , "000000111000000110" ,
"000000110110100111" , "000000110101001001" , "000000110011101011" , "000000110010001110" , "000000110000110010" , "000000101111011000" , "000000101101111110" , "000000101100100101" , "000000101011001110" , "000000101001111000" ,
"000000101000100010" , "000000100111001110" , "000000100101111011" , "000000100100101010" , "000000100011011001" , "000000100010001011" , "000000100000111100" , "000000011111110000" , "000000011110100101" , "000000011101011011" ,
"000000011100010010" , "000000011011001010" , "000000011010000100" , "000000011001000000" , "000000010111111100" , "000000010110111010" , "000000010101111001" , "000000010100111010" , "000000010011111100" , "000000010011000000" ,
"000000010010000100" , "000000010001001010" , "000000010000010011" , "000000001111011011" , "000000001110100101" , "000000001101110001" , "000000001100111110" , "000000001100001100" , "000000001011011100" , "000000001010101101" ,
"000000001001111111" , "000000001001010011" , "000000001000101000" , "000000000111111110" , "000000000111010110" , "000000000110101110" , "000000000110001010" , "000000000101100100" , "000000000101000000" , "000000000100011111" ,
"000000000011111110" , "000000000011011111" , "000000000011000000" , "000000000010100011" , "000000000010000111" , "000000000001101100" , "000000000001010010" , "000000000000111010" , "000000000000100011" , "000000000000001100" ,
"111111111111111000" , "111111111111100011" , "111111111111001110" , "111111111111000000" , "111111111110101110" , "111111111110011110" , "111111111110001101" , "111111111101111111" , "111111111101110001" , "111111111101100110" ,
"111111111101011001" , "111111111101010000" , "111111111101000101" , "111111111100111110" , "111111111100110100" , "111111111100101111" , "111111111100100011" , "111111111100101000" , "111111111100011111" , "111111111100010001" ,
"111111111100010001" , "111111111100001101" , "111111111100001110" , "111111111100001011" , "111111111100001100" , "111111111100001010" , "111111111100001100" , "111111111100001011" , "111111111100001110" , "111111111100001110" ,
"111111111100010001" , "111111111100010011" , "111111111100010111" , "111110010100011100" 
);
end a;

