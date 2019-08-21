--  Hello world program
library ieee;
library work;
use std.textio.all; -- Imports the standard textio package.
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;
use ieee.math_real.all;
use work.fft_types.all;
use work.channelizer1024_8;
use work.clockGating;

--  Defines a design entity, without any ports.
entity test_channelizer1024_8 is
end test_channelizer1024_8;

architecture behaviour of test_channelizer1024_8 is
	constant depthOrder: integer := 10;
	constant overlapOrder: integer := 3;
	constant depth: integer := 1024;
	constant overlap: integer := 8;
	constant stepSize: integer := 1024/8;
	
	signal din: complex;
	signal inClk, outClk, outClkB, doutValid: std_logic := '0';
	signal dout: complex;
	signal doutChannel: unsigned(depthOrder-1 downto 0);
	signal ch0, ch1: complex;
	signal doutNorm: real;
	signal doutMag: integer;
	signal doutDB0, doutDB: integer;
	
	constant inClkHPeriod: time := 8 ns;
	constant outClkHPeriod: time := 1 ns;
begin
	inst: entity channelizer1024_8
		generic map(inBits=>16,
					outBits=>24)
		port map(inClk, outClkB, outClk,
					din, '1',
					dout, doutValid, doutChannel);

	cg: entity clockGating
		port map(clkInUnbuffered=>outClk,
				ce=>'1',
				clkOutGated=>outClkB);

	-- feed data in
	process
		variable l : line;
		variable inpValue: integer := 0;
	begin
		wait for 120 ns;
		for I in 0 to 3000 loop
			din <= to_complex(inpValue, -inpValue);
			inpValue := inpValue+1;
			wait for inClkHPeriod; inClk <= '1'; wait for inClkHPeriod; inClk <= '0';
		end loop;
		
		wait;
	end process;

	-- retrieve data
	process
		variable l : line;
		variable indexOffset: integer;
		variable expectIndex: unsigned(depthOrder-1 downto 0);
		variable dataBegin: integer;
		variable expectData: integer;
	begin
		wait for 60 ns;
		for I in 0 to 24000 loop
			wait for outClkHPeriod; outClk <= '1'; wait for outClkHPeriod; outClk <= '0';
		end loop;
		
		wait;
	end process;
	
	doutNorm <= real(to_integer(dout.re))*real(to_integer(dout.re))
				+ real(to_integer(dout.im))*real(to_integer(dout.im));
	doutMag <= integer(sqrt(real(doutNorm)));
	
	doutDB0 <= integer(log(base=>10.0, X=>doutNorm) * real(10));
	doutDB <= 0 when doutDB0 < 0 else doutDB0;

	ch0 <= dout when doutChannel=0 and doutValid='1' and rising_edge(outClkB);
	ch1 <= dout when doutChannel=1 and doutValid='1' and rising_edge(outClkB);
	
	
end behaviour;
