library ieee;

use ieee.std_logic_1164.all;


entity keyboard is
	generic(freq       : integer := 50_000_000;
	        debCounter : integer := 8);
	port(
		clk50,  
		ps2Clk, 
		ps2Data    : in  std_logic;
		ps2Out     : out std_logic_vector(7 downto 0);
		ps2Flag    : out std_logic);
end keyboard;

architecture logic of keyboard is
component debounce is
	generic(count  : integer := 10); 
	port(
		clk50,  
		debIn      : in  std_logic;
		debOut     : out std_logic);
end component;
---------------------------------------------
signal syncFF : std_logic_vector(1 downto 0); --FF(0) = Clk : FF(1) = Data
signal debClk, debData : std_logic := '0';
signal word   : std_logic_vector(10 downto 0);
signal error  : std_logic := '0';
signal counter : natural range 0 to freq/18_000;
begin


	process(clk50)
	begin
	syncFF(0) <= ps2Clk;
	syncFF(1) <= ps2Data;
	end process;

	
	deb0   : debounce generic map(debCounter) port map(clk50, syncFF(0), debClk);
	deb1   : debounce generic map(debCounter) port map(clk50, syncFF(1), debData);

	
	process(debClk)
	begin
	
		if(rising_edge(debClk)) then
		word <= debData & word(10 downto 1);
		end if;
	end process;
	
	error <= (not (not word(0) and word(10) and (word(9) xor word(8) xor word(7) xor word(6) xor word(5) xor word(4) xor word(3) xor word(2) xor word(1))));
	
	process(clk50)
	
	begin
	
		if(rising_edge(clk50)) then 
			if(debClk = '0') then counter <= 0;
			elsif(counter /= freq/18_000) then counter <= counter + 1;
			end if;
				
			if(counter = freq/18_000 and error = '0') then ps2Flag <= '1';
														   ps2Out  <= word(8 downto 1);
			else										   ps2Flag <= '0';
			end if;
		end if;
	
	end process;
end logic;