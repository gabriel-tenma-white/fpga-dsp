--  Hello world program
library ieee;
library work;
use std.textio.all; -- Imports the standard textio package.
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;
use work.fft_types.all;
use work.overlapStreamBuffer2;


--  Defines a design entity, without any ports.
entity test_overlapStreamBuffer2 is
end test_overlapStreamBuffer2;

architecture behaviour of test_overlapStreamBuffer2 is
	constant depthOrder: integer := 8;
	constant overlapOrder: integer := 3;
	constant depth: integer := 256;
	constant overlap: integer := 8;
	constant stepSize: integer := 256/8;
	
	constant inValues: integer := 2048;

	signal din: complex;
	signal inClk, outClk, doutValid: std_logic := '0';
	signal dout: complex;
	signal doutIndex, doutPhase, bitPermIn, bitPermOut: unsigned(depthOrder-1 downto 0);
	
	constant inClkHPeriod: time := 32 ns;
	constant outClkHPeriod: time := 1 ns;
	
	function perm(a: unsigned) return unsigned is
		variable ret: unsigned(a'range);
	begin
		for I in a'range loop
			ret(I) := a(a'left-I);
		end loop;
		return ret;
	end function;
begin
	inst: entity overlapStreamBuffer2
		generic map(depthOrder=>depthOrder,
					overlapOrder=>overlapOrder,
					dataBits=>16,
					bitPermDelay=>0)
		port map(inClk, outClk,
					din, '1',
					doutPhase, doutIndex, dout, doutValid,
					bitPermIn, bitPermOut);
	--bitPermOut <= bitPermIn when rising_edge(outClk);
	bitPermOut <= perm(bitPermIn);

	-- feed data in
	process
		variable l : line;
		variable inpValue: integer := 0;
	begin
		wait for 120 ns;
		for I in 0 to inValues-1 loop
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
		variable expectIndex, expectIndex0: unsigned(depthOrder-1 downto 0);
		variable dataBegin: integer;
		variable expectData: integer;
	begin
		wait for 60 ns;
		for I in 0 to 1000 loop
			while doutValid='0' loop
				wait for outClkHPeriod; outClk <= '1'; wait for outClkHPeriod; outClk <= '0';
			end loop;
			wait for outClkHPeriod; outClk <= '1'; wait for outClkHPeriod; outClk <= '0';
		end loop;
		-- wait until we reach the start of a frame with starting index 0
		for I in 0 to 10000 loop
			if doutValid='1' and doutIndex=0 and doutPhase=0 then
				exit;
			end if;
			wait for outClkHPeriod; outClk <= '1'; wait for outClkHPeriod; outClk <= '0';
		end loop;
		write(output, "start of frame: " & time'image(now) & LF);
		
		dataBegin := to_integer(dout.re);

		for P in 0 to (inValues/depth - 5) loop
			for offset in 0 to overlap-1 loop
				indexOffset := ((overlap-offset) mod overlap)*stepSize;
				expectIndex0 := to_unsigned(0, expectIndex'length);
				for I in 0 to depth-1 loop
					while doutValid='0' loop
						wait for outClkHPeriod; outClk <= '1'; wait for outClkHPeriod; outClk <= '0';
					end loop;
					expectIndex := perm(expectIndex0) + indexOffset;
					assert expectIndex = doutIndex
						report "expected doutIndex " & integer'image(to_integer(expectIndex))
								& " got " & integer'image(to_integer(doutIndex));
					
					expectData := dataBegin + to_integer(expectIndex);
					assert expectData = to_integer(dout.re)
						report "expected dout " & integer'image(expectData)
								& " got " & integer'image(to_integer(dout.re));
					
					expectIndex0 := expectIndex0 + 1;
					wait for outClkHPeriod; outClk <= '1'; wait for outClkHPeriod; outClk <= '0';
				end loop;
				-- end of one frame
				dataBegin := dataBegin + stepSize;
			end loop;
		end loop;
		wait;
	end process;
end behaviour;
