library ieee;
library work;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;
use work.fft_types.all;
use work.complexRam;

-- name is all lowercase to work around vivado bug
entity overlapstreambuffer3subunit is
	generic(frameSizeOrder, overlapOrder: integer;
			dataBits: integer);
	port(clk: in std_logic;
		we: in std_logic;
		din: in complex;
		dinIndex: in unsigned(frameSizeOrder-1 downto 0);
		phase: in unsigned(frameSizeOrder + overlapOrder downto 0);

		rAddr: in unsigned(frameSizeOrder downto 0);
		dout: out complex
		);
end entity;
architecture ar of overlapstreambuffer3subunit is
	constant ramDepthOrder: integer := frameSizeOrder + 1;

	-- outClk domain
	constant ramReadDelay: integer := 2;
	signal ramWAddr: unsigned(ramDepthOrder-1 downto 0);
	signal ramWEn: std_logic;
begin
	-- ram
	ram1: entity complexRam
		generic map(dataBits=>dataBits, depthOrder=>ramDepthOrder)
		port map(wrclk=>clk, rdclk=>clk,
				rdaddr=>rAddr, rddata=>dout,
				wraddr=>ramWAddr, wrdata=>din, wren=>ramWEn);

	ramWEn <= '1' when we='1' and phase(phase'left-1 downto frameSizeOrder) = 0	else '0';
	ramWAddr <= phase(phase'left) & dinIndex;
end ar;
