--  Hello world program
library ieee;
library work;
use std.textio.all; -- Imports the standard textio package.
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;
use work.fft_types.all;
use work.overlapStreamBuffer;


--  Defines a design entity, without any ports.
entity test_overlapStreamBuffer is
end test_overlapStreamBuffer;

architecture behaviour of test_overlapStreamBuffer is
	constant depthOrder: integer := 8;
	constant overlapOrder: integer := 3;
	
	signal din: complex;
	signal inClk, intClk, outClk, doutValid: std_logic := '0';
	signal dout: complex;
	signal doutIndex, doutPhase, bitPermIn, bitPermOut: unsigned(depthOrder-1 downto 0);
	
	constant inClkHPeriod: time := 8 ns;
	constant intClkHPeriod: time := 1 ns;
	constant outClkHPeriod: time := 1 ns;
begin
	inst: entity overlapStreamBuffer
		generic map(depthOrder=>depthOrder,
					overlapOrder=>overlapOrder,
					dataBits=>12)
		port map(inClk, intClk, outClk,
					din, '1',
					doutPhase, doutIndex, dout, doutValid,
					bitPermIn, bitPermOut);
	bitPermOut <= bitPermIn;

	-- feed data in
	process
		variable l : line;
		variable inpValue: integer := 0;
	begin
		wait for 120 ns;
		for I in 0 to 10000 loop
			din <= to_complex(inpValue, -inpValue);
			inpValue := inpValue+1;
			wait for inClkHPeriod; inClk <= '1'; wait for inClkHPeriod; inClk <= '0';
		end loop;
		
		wait;
	end process;
	
	process
		variable l : line;
		variable inpValue: integer := 0;
	begin
		wait for 30 ns;
		for I in 0 to 80000 loop
			wait for intClkHPeriod; intClk <= '1'; wait for intClkHPeriod; intClk <= '0';
		end loop;
		
		wait;
	end process;

	-- retrieve data
	process
		variable l : line;
		variable expectValue: integer := 0;
		variable expectData: unsigned(15 downto 0) := (others=>'0');
	begin
		wait for 60 ns;
		for I in 0 to 15 loop
			wait for outClkHPeriod; outClk <= '1'; wait for outClkHPeriod; outClk <= '0';
		end loop;
		for I2 in 2 to 80000 loop
			--expectData := to_unsigned(expectValue, 16);
			if doutValid='1' then
				--assert expectData=unsigned(outData);
				expectValue := expectValue+1;
			end if;
			wait for outClkHPeriod; outClk <= '1'; wait for outClkHPeriod; outClk <= '0';
		end loop;
		
		wait;
	end process;
end behaviour;
