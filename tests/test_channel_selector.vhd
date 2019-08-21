--  Hello world program
library ieee;
library work;
use std.textio.all; -- Imports the standard textio package.
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;
use ieee.math_real.all;
use work.fft_types.all;
use work.channelSelector;

--  Defines a design entity, without any ports.
entity test_channelSelector is
end test_channelSelector;

architecture behaviour of test_channelSelector is
	constant channelBits: integer := 6;
	constant ramDepthOrder: integer := 5;
	constant channels: integer := integer(2**channelBits);

	signal din: complex;
	signal dinChannel: unsigned(channelBits-1 downto 0);
	signal clk, ramWClk: std_logic := '0';
	signal dout: complex;
	signal doutValid, doutLast: std_logic;

	signal ramWEn: std_logic := '0';
	signal ramWAddr: unsigned(ramDepthOrder-1 downto 0);
	signal ramWData: unsigned(channelBits downto 0);

	constant clkHPeriod: time := 0.5 ns;
	constant ramClkHPeriod: time := 1 ns;
begin
	inst: entity channelSelector
		generic map(dataBits=>16,
					channelBits=>channelBits,
					ramDepthOrder=>ramDepthOrder)
		port map(clk, din, dinChannel, '1',
					dout, doutValid, doutLast,
					ramWClk, ramWEn, ramWAddr, ramWData);

	-- feed data in
	process
		variable l : line;
		variable index, inpValue, inpChannel: integer := 0;
	begin
		wait for 120 ns;
		for I in 0 to 1000 loop
			inpChannel := index mod channels;
			inpValue := integer(index / channels) * 100 + inpChannel;

			din <= to_complex(inpValue, -inpValue);
			dinChannel <= to_unsigned(inpChannel, channelBits);
			index := index + 1;
			wait for clkHPeriod; clk <= '1'; wait for clkHPeriod; clk <= '0';
		end loop;
		
		wait;
	end process;

	-- write to ram
	process
		variable l : line;
		procedure writeWord (
			constant addr,val: integer
		) is
		begin
			ramWEn <= '1';
			ramWAddr <= to_unsigned(addr, ramDepthOrder);
			ramWData <= to_unsigned(val, channelBits + 1);
			wait for ramClkHPeriod; ramWClk <= '1'; wait for ramClkHPeriod; ramWClk <= '0';
		end writeWord;
	begin
		wait for 60 ns;
		for I in 0 to 10 loop
			wait for ramClkHPeriod; ramWClk <= '1'; wait for ramClkHPeriod; ramWClk <= '0';
		end loop;
		
		writeWord(0, 13);
		writeWord(1, 17);
		writeWord(2, 54);
		writeWord(3, 56 + 64); -- 64 sets the tlast bit
		
		for I in 0 to 10 loop
			wait for ramClkHPeriod; ramWClk <= '1'; wait for ramClkHPeriod; ramWClk <= '0';
		end loop;
		
		wait;
	end process;
	
end behaviour;
