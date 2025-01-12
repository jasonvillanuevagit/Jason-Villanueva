library ieee;
use ieee.std_logic_1164.all;
use work.shape_package.all;
use work.ttt_package.all;
use work.properties_package.all;
use work.counter_package.all;
use work.target_package.all;
use ieee.numeric_std.all;

entity tttGame is
	port(
	clk50,
	clk25,
	Up, Dn,
	Lt, Rt,
	button,
	inReplay, inToMenu,
	reset,
	dena,
	hsync, 
	hActive, vActive        : in  std_logic := '0';
	replay, toMenu          : out std_logic := '0';
	r, g, b                 : out std_logic_vector(9 downto 0) := (others => '0'));
end tttGame;

architecture FSM of tttGame is
-----------------------------
--Declare data types here----
-----------------------------

-----------------------------
--States---------------------
-----------------------------

	type yState is(yBot, yMid, yTop);
	signal prev_yState, next_yState : yState := yMid;
	
	type gameState is(Start, Play, Menu0, Menu1, Menu2);
	signal prev_gameState, next_gameState : gameState;
	
	
	type xState is(xLeft, xMid, xRight);
	signal prev_xState, next_xState : xState := xMid;
 
	
	type drawState is (Idle, Check, drawCross, drawO);
	signal next_drawState, prev_drawState : drawState := Idle;
	
-----------------------------

-----------------------------
--Data Types-----------------
-----------------------------

	--Game Pixels---------------
	signal xPix      : natural range 0 to 800;
	signal yPix      : natural range 0 to 525;
	----------------------------
	signal xTimer, yTimer : natural range 0 to 60;
	--Field and symbol-------------------------------
	constant Cross : std_logic_vector(1 downto 0) := "01";
	constant O     : std_logic_vector(1 downto 0) := "10";
	constant U     : std_logic_vector(1 downto 0) := "11";
	type field is array(0 to 2, 0 to 2) of std_logic_vector(1 downto 0);
	signal fieldMap : field := (others => (others => U));
	-------------------------------------------------
	--Win Conditions---------------------------------
	signal p1, p2 : std_logic := '0';
	signal drawCounter  : natural range 0 to 9 := 0;
	--Player Data-----------------------
	signal player    : std_logic := '0';
	------------------------------------
	--Reticule Data-------------
	signal xPos      : natural range 0 to 640;
	signal yPos      : natural range 0 to 480;
	----------------------------		
	
	--Box Locations-------------
	type xcordinate is array(2 downto 0) of integer range 0 to 640;
	type ycordinate is array(2 downto 0) of integer range 0 to 480;
	type xcoordinate is array(8 downto 0) of integer range -200 to 800;
	
	signal xCoord    : xcordinate := (205, 320, 425);
	signal yCoord    : ycordinate := (360, 250, 140);
	-----------------------------
	--Shape Locations------------
	constant x_xCoordR  : xcoordinate := (	280, 170,   60,
											170,  60,  -50,
										    60,  -50,  -160);
										
	constant x_xCoordL  : xcoordinate := (	560, 450, 340,
											670, 560, 450,
											780, 670, 560);
										--
	constant y_xCoord   : xcordinate := (335, 225, 115);
	--
	constant x_oCoord  : xcordinate := (205, 320, 425);
	constant y_oCoord  : ycordinate := (360, 250, 140);
	----------------------------
	--Cursor Data---------------
	signal yTrigger, yRefresh,
		   xTrigger, xRefresh   : std_logic := '0';
	signal cursorTimer     		: natural range 0 to 60;
	-----------------------------
	
	--Draw Data------------------
	signal drawTrigger,
		   drawRefresh     : std_logic := '0';
	signal drawTimer       : natural range 0 to 60;
	signal index           : natural range 0 to 8 := 4;
	signal allow           : std_logic := '0';
	-----------------------------
	
	--Game Data-----------------
	signal startGame     : std_logic := '0';
	signal gameTime     : natural range 0 to 60;
	----------------------------

	--Temp----------------------
	-----------------------------
	signal xCounter, yCounter : natural range 0 to 2;
	signal drawTrig           : std_logic := '0';
begin
	--Pixel Counters-------
	
	process(clk25) --Counts columns
	begin
	pos_edgeCounter(clk25, Hactive, xPix);
	end process;
	
	process(hsync)
	begin
	pos_edgeCounter(hsync, Vactive, yPix); --Counts rows
	end process;
	-----------------------
---------------------------------------------------------------------------------------------
--Timer for cursorConroller------------------------------------------------------------------
---------------------------------------------------------------------------------------------

----------------------------------------------------------------------------------------------
--Timer for YConroller-----------------------------------------------------------------------
----------------------------------------------------------------------------------------------	
	process(clk50, yTimer, yRefresh)	
	variable yRefreshTime   : integer range 0 to 50_000_000 := 0;
	begin
 
	if(yTrigger = '1') then 
									yTimer        <= 0;
									yRefreshTime  := 0;
	elsif(rising_edge(clk50)) then 
			if(yRefreshTime = 25_000_000) then yRefreshTime := yRefreshTime;							   
			                                   yTimer <= 1;
			else                               yRefreshTime := yRefreshTime + 1;
			end if;
	end if;
	end process;

----------------------------------------------------------------------------------------------
--Timer for XConroller-----------------------------------------------------------------------
----------------------------------------------------------------------------------------------	
	process(clk50, xTimer, xRefresh)	
	variable xRefreshTime   : integer range 0 to 50_000_000 := 0;
	begin
 
	if(xTrigger = '1') then 
									xTimer        <= 0;
									xRefreshTime  := 0;
	elsif(rising_edge(clk50)) then 
			if(xRefreshTime = 25_000_000) then xRefreshTime := xRefreshTime;
											   xTimer <= 1;
			else                               xRefreshTime := xRefreshTime + 1;							   
			end if;
	end if;
	end process;
----------------------------------------------------------------------------------------------
--Cursor Controllers-------------------------------------------------------------------------
----------------------------------------------------------------------------------------------	
----------------------------------------------------------------------------------------------
--FSM for YController-------------------------------------------------------------------------
----------------------------------------------------------------------------------------------	
	process(clk50)
	begin
	if(rising_edge(clk50)) then 
		if(reset = '1') then prev_yState <= yMid;
		else                 prev_yState <= next_yState;
		end if;
	end if;
	end process;
	
	process(prev_yState, yRefresh, yCounter, Up, Dn, yTimer, yTrigger)
	begin
		
		case (prev_yState) is 
			when yBot => 
						yCounter <= 2;
						yRefresh <= '0';
						if(yTimer = 1) then
							if(Up = '1' and Dn = '0') then next_yState <= yMid; yRefresh <= '1';
							else                             next_yState <= yBot;
							end if;
						else                                 next_yState <= yBot;
						end if;

					
			when yMid => 
						yCounter <= 1;
						yRefresh <= '0';
						if(yTimer = 1) then
							if   (Up = '1' and Dn = '0') then next_yState <= yTop; yRefresh <= '1';
							elsif(Up = '0' and Dn = '1') then next_yState <= yBot; yRefresh <= '1';
							else                                next_yState <= yMid;
							end if;
						else next_yState <= yMid;
						end if;
					 
								                
			when yTop => 
						yCounter <= 0;
						yRefresh <= '0';
						if(yTimer = 1) then
							if(Up = '0' and Dn = '1') then next_yState <= yMid; yRefresh <= '1';
							else                             next_yState <= yTop;
							end if;
						else next_yState <= yTop;
						end if;
	
    end case;
	
 	end process;
 
	-------------------------------
	--Delay to prevent glitch when switching from state to state
	process(clk50, yTrigger, yRefresh)
	begin
	if(rising_edge(clk50)) then yTrigger <= yRefresh;
	end if;	
	end process;	
---------------------------------------------------------------------------------------------
--FSM for XController-------------------------------------------------------------------------
----------------------------------------------------------------------------------------------	
	process(clk50)
	begin
	if(rising_edge(clk50)) then 
		if(reset = '1') then prev_xState <= xMid;
		else                 prev_xState <= next_xState;
		end if;
	end if;
	end process;
	
	process(prev_xState, xRefresh, xCounter, Up, Dn, xTimer, xTrigger)
	begin
		
		case (prev_xState) is 
			when xLeft => 
						xCounter <= 2;
						xRefresh <= '0';
						if(xTimer = 1) then
							if(Lt = '0' and Rt = '1') then next_xState <= xMid; xRefresh <= '1';
							else                             next_xState <= xLeft;
							end if;
						else                                 next_xState <= xLeft;
						end if;

					
			when xMid => 
						xCounter <= 1;
						xRefresh <= '0';
						if(xTimer = 1) then
							if   (Lt = '1' and Rt = '0') then next_xState <= xLeft; xRefresh <= '1';
							elsif(Lt = '0' and Rt = '1') then next_xState <= xRight; xRefresh <= '1';
							else                              next_xState <= xMid;
							end if;
						else next_xState <= xMid;
						end if;
					 
								                
			when xRight => 
						xCounter <= 0;
						xRefresh <= '0';
						if(xTimer = 1) then
							if(Lt = '1' and Rt = '0') then next_xState <= xMid; xRefresh <= '1';
							else                           next_xState <= xRight;
							end if;
						else next_xState <= xRight;
						end if;
						
			when others =>
					next_xState <= xRight;
	
    end case;
	
 	end process;
 
	-------------------------------
	--Delay to prevent glitch when switching from state to state
	process(clk50, xTrigger, xRefresh)
	begin
	if(rising_edge(clk50)) then xTrigger <= xRefresh;
	end if;	
	end process;	
	
--------------------------------------------------------------------------------------------
--Timer for Draw FSM------------------------------------------------------------------------
--------------------------------------------------------------------------------------------	
	process(clk50, drawTimer, drawRefresh)	
	variable drawRefreshTime   : integer range 0 to 50_000_000 := 0;
	begin
	if(drawTrigger = '1') then 
									drawTimer        <= 0;
									drawRefreshTime  := 0;
	elsif(rising_edge(clk50)) then 
			
			if(drawRefreshTime = 15_000_000) then drawRefreshTime := drawRefreshTime;							   
											      drawTimer <= 1;
			else                                  drawRefreshTime := drawRefreshTime + 1;
			end if;
	end if;
	end process;
--------------------------------------------------------------------------------------------
--Draw FSM----------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------
	 
	process(clk50)
	begin
	if(rising_edge(clk50)) then 
		if(reset = '1') then prev_drawState <= Idle;
		else                 prev_drawState <= next_drawState;
		end if;
	end if;
	end process;
	
	process(prev_drawState)
	begin
	
		drawRefresh <= '0';
		
		case (prev_drawState) is 
			when Idle => 
				
						if(drawTimer = 1 and allow = '1') then
							if(Up = '0' and Dn = '0' and Lt = '0' and Rt = '0' and Button = '1') then next_drawState <= Check; drawRefresh <= '1';
							else                  next_drawState <= Idle;
							end if;
						else                      next_drawState <= Idle;
						end if;
			
			when Check => 
				
						if   (fieldMap(xCounter,yCounter) = U and player = '0') then next_drawState <= drawCross; drawRefresh <= '1';
						elsif(fieldMap(xCounter,yCounter) = U and player = '1') then next_drawState <= drawO;     drawRefresh <= '1';
						else                                             next_drawState <= Idle;      drawRefresh <= '1';
						end if;
						
						 
			when drawCross =>
							next_drawState  <= Idle;
						
			when drawO => 
							next_drawState  <= Idle;
						
		end case;	
	end process;
	
	--Glitch prevention for state tranfer--	
	process(clk50)
	begin
	if(rising_edge(clk50)) then drawTrigger <= drawRefresh;
	end if;	
	end process;
	---------------------------------------

	process(clk50)
	variable drawFlag         : std_logic := '0';
	begin
	
	if(reset = '1') then 
							drawCounter <= 0;
							
							fieldMap <= (others => (others => U));
							
	elsif(rising_edge(clk50)) then
		
		case (prev_drawState) is
					when Idle 	   => drawFlag := '0';
					when Check 	   => null;
					when drawCross => 
										if(drawFlag = '0') then
										fieldMap(xCounter, yCounter) <= Cross; 
										player <= not player; 
										drawCounter <= drawCounter + 1;
										drawFlag := '1'; 
										end if;
					when drawO     => 
										if(drawFlag = '0') then
										fieldMap(xCounter, yCounter) <= O;
										player <= not player; 
										drawCounter <= drawCounter + 1;
										drawFlag := '1'; 
										end if;
		end case;
	end if;	
	end process;
	
---------------------------------------------------------------------------------------
--Timer for game-----------------------------------------------------------------------
---------------------------------------------------------------------------------------

	process(clk50)	
	variable gameCounter	 : integer range 0 to 50_000_000 := 0;
	begin
 
	if(startGame = '1') then 
		if(rising_edge(clk50)) then gameCounter := gameCounter + 1;
			if(gameCounter = 50_000_000) then gameCounter   := 0;
										      gameTime <= gameTime + 1;
			end if;
		end if;
	else
		gameTime     <= 0;
		gameCounter  := 0;
	end if;
	end process;

-----------------------------------------------------
--Tic-Tac-Toe Game-----------------------------------
-----------------------------------------------------		
	process(clk50)
	begin
	
	if(reset = '1') then prev_gameState <= Start;
	elsif(rising_edge(clk50)) then 
		                 prev_gameState <= next_gameState;
	end if;
	end process;

	process (prev_gameState)
	variable x  : natural range 0 to 800;
	variable y  : natural range 0 to 525;
	begin
	
		x := xPix;
		y := yPix;
		case(prev_gameState) is
		when Start =>  
					allow <= '0';
					if (dena = '1') then
						r <= (others => '1');
						g <= (others => '1');
						b <= (others => '0');
					else
						r <= (others => '0');
						g <= (others => '0');
						b <= (others => '0');
					end if;
					
					if(reset = '1') then startGame <= '0';
					else                 startGame <= '1';
					end if;
					if (gameTime = 3) then next_gameState    <= Play;
					else                   next_gameState    <= Start;
					end if;
				
		when Play  =>
		
					allow <= '1';
					startGame <= '0';
						
					--Counter:------------------------------
					if (dena = '1') then
						r <= (others => '1');
						g <= (others => '0');
						b <= (others => '1');
					--
					drawXorO(x, y, fieldMap(0,0), x_xCoordL(8), x_xCoordR(8), y_xCoord(0), x_oCoord(0), y_oCoord(0), r, g, b);
					drawXorO(x, y, fieldMap(1,0), x_xCoordL(7), x_xCoordR(7), y_xCoord(0), x_oCoord(1), y_oCoord(0), r, g, b);
					drawXorO(x, y, fieldMap(2,0), x_xCoordL(6), x_xCoordR(6), y_xCoord(0), x_oCoord(2), y_oCoord(0), r, g, b);
					--
					drawXorO(x, y, fieldMap(0,1), x_xCoordL(5), x_xCoordR(5), y_xCoord(1), x_oCoord(0), y_oCoord(1), r, g, b);
					drawXorO(x, y, fieldMap(1,1), x_xCoordL(4), x_xCoordR(4), y_xCoord(1), x_oCoord(1), y_oCoord(1), r, g, b);
					drawXorO(x, y, fieldMap(2,1), x_xCoordL(3), x_xCoordR(3), y_xCoord(1), x_oCoord(2), y_oCoord(1), r, g, b);
					--
					drawXorO(x, y, fieldMap(0,2), x_xCoordL(2), x_xCoordR(2), y_xCoord(2), x_oCoord(0), y_oCoord(2), r, g, b);
					drawXorO(x, y, fieldMap(1,2), x_xCoordL(1), x_xCoordR(1), y_xCoord(2), x_oCoord(1), y_oCoord(2), r, g, b);
					drawXorO(x, y, fieldMap(2,2), x_xCoordL(0), x_xCoordR(0), y_xCoord(2), x_oCoord(2), y_oCoord(2), r, g, b);
					--
					
					drawPound(x, y, color(0), r, g, b);
						if(player = '0') then
						drawReticule(x, y, xCoord(xCounter), yCoord(yCounter), 3, 20, color(1), r, g, b);
						else
						drawReticule(x, y, xCoord(xCounter), yCoord(yCounter), 3, 20, color(4), r, g, b);
						end if;  
					else
						r <= (others => '0');
						g <= (others => '0');
						b <= (others => '0');
					end if;
					
					
					if   (p1 = '1')   		then next_gameState <= Menu0;
					elsif(p2 = '1')   		then next_gameState <= Menu1;
					elsif(drawTrig = '1')  then next_gameState <= Menu2;
					else                 		 next_gameState <= Play;
					end if;
			
						
		when Menu0 => 
				
					allow <= '0';
					startGame <= '0';
					
					if (dena = '1') then
						r <= (others => '0');
						g <= (others => '0');
						b <= (others => '1');
							--
					drawXorO(x, y, fieldMap(0,0), x_xCoordL(8), x_xCoordR(8), y_xCoord(0), x_oCoord(0), y_oCoord(0), r, g, b);
					drawXorO(x, y, fieldMap(1,0), x_xCoordL(7), x_xCoordR(7), y_xCoord(0), x_oCoord(1), y_oCoord(0), r, g, b);
					drawXorO(x, y, fieldMap(2,0), x_xCoordL(6), x_xCoordR(6), y_xCoord(0), x_oCoord(2), y_oCoord(0), r, g, b);
					--
					drawXorO(x, y, fieldMap(0,1), x_xCoordL(5), x_xCoordR(5), y_xCoord(1), x_oCoord(0), y_oCoord(1), r, g, b);
					drawXorO(x, y, fieldMap(1,1), x_xCoordL(4), x_xCoordR(4), y_xCoord(1), x_oCoord(1), y_oCoord(1), r, g, b);
					drawXorO(x, y, fieldMap(2,1), x_xCoordL(3), x_xCoordR(3), y_xCoord(1), x_oCoord(2), y_oCoord(1), r, g, b);
					--
					drawXorO(x, y, fieldMap(0,2), x_xCoordL(2), x_xCoordR(2), y_xCoord(2), x_oCoord(0), y_oCoord(2), r, g, b);
					drawXorO(x, y, fieldMap(1,2), x_xCoordL(1), x_xCoordR(1), y_xCoord(2), x_oCoord(1), y_oCoord(2), r, g, b);
					drawXorO(x, y, fieldMap(2,2), x_xCoordL(0), x_xCoordR(0), y_xCoord(2), x_oCoord(2), y_oCoord(2), r, g, b);
					--
						
						
						drawPound(x, y, color(0), r, g, b);
					else
						r <= (others => '0');
						g <= (others => '0');
						b <= (others => '0');
					end if;
					
					next_gameState <= Menu0;
					
		when Menu1 => 
			
					allow <= '0';
					startGame <= '0';
		
					if (dena = '1') then
						r <= (others => '1');
						g <= (others => '0');
						b <= (others => '0');
						
							--
					drawXorO(x, y, fieldMap(0,0), x_xCoordL(8), x_xCoordR(8), y_xCoord(0), x_oCoord(0), y_oCoord(0), r, g, b);
					drawXorO(x, y, fieldMap(1,0), x_xCoordL(7), x_xCoordR(7), y_xCoord(0), x_oCoord(1), y_oCoord(0), r, g, b);
					drawXorO(x, y, fieldMap(2,0), x_xCoordL(6), x_xCoordR(6), y_xCoord(0), x_oCoord(2), y_oCoord(0), r, g, b);
					--
					drawXorO(x, y, fieldMap(0,1), x_xCoordL(5), x_xCoordR(5), y_xCoord(1), x_oCoord(0), y_oCoord(1), r, g, b);
					drawXorO(x, y, fieldMap(1,1), x_xCoordL(4), x_xCoordR(4), y_xCoord(1), x_oCoord(1), y_oCoord(1), r, g, b);
					drawXorO(x, y, fieldMap(2,1), x_xCoordL(3), x_xCoordR(3), y_xCoord(1), x_oCoord(2), y_oCoord(1), r, g, b);
					--
					drawXorO(x, y, fieldMap(0,2), x_xCoordL(2), x_xCoordR(2), y_xCoord(2), x_oCoord(0), y_oCoord(2), r, g, b);
					drawXorO(x, y, fieldMap(1,2), x_xCoordL(1), x_xCoordR(1), y_xCoord(2), x_oCoord(1), y_oCoord(2), r, g, b);
					drawXorO(x, y, fieldMap(2,2), x_xCoordL(0), x_xCoordR(0), y_xCoord(2), x_oCoord(2), y_oCoord(2), r, g, b);
					--
						drawPound(x, y, color(0), r, g, b);
					else
						r <= (others => '0');
						g <= (others => '0');
						b <= (others => '0');
					end if;
					
					next_gameState <= Menu1;
			
		when Menu2 => 
					allow <= '0';
					startGame <= '0';
		
					if (dena = '1') then
						r <= (others => '0');
						g <= (others => '1');
						b <= (others => '1');
						--
							--
					drawXorO(x, y, fieldMap(0,0), x_xCoordL(8), x_xCoordR(8), y_xCoord(0), x_oCoord(0), y_oCoord(0), r, g, b);
					drawXorO(x, y, fieldMap(1,0), x_xCoordL(7), x_xCoordR(7), y_xCoord(0), x_oCoord(1), y_oCoord(0), r, g, b);
					drawXorO(x, y, fieldMap(2,0), x_xCoordL(6), x_xCoordR(6), y_xCoord(0), x_oCoord(2), y_oCoord(0), r, g, b);
					--
					drawXorO(x, y, fieldMap(0,1), x_xCoordL(5), x_xCoordR(5), y_xCoord(1), x_oCoord(0), y_oCoord(1), r, g, b);
					drawXorO(x, y, fieldMap(1,1), x_xCoordL(4), x_xCoordR(4), y_xCoord(1), x_oCoord(1), y_oCoord(1), r, g, b);
					drawXorO(x, y, fieldMap(2,1), x_xCoordL(3), x_xCoordR(3), y_xCoord(1), x_oCoord(2), y_oCoord(1), r, g, b);
					--
					drawXorO(x, y, fieldMap(0,2), x_xCoordL(2), x_xCoordR(2), y_xCoord(2), x_oCoord(0), y_oCoord(2), r, g, b);
					drawXorO(x, y, fieldMap(1,2), x_xCoordL(1), x_xCoordR(1), y_xCoord(2), x_oCoord(1), y_oCoord(2), r, g, b);
					drawXorO(x, y, fieldMap(2,2), x_xCoordL(0), x_xCoordR(0), y_xCoord(2), x_oCoord(2), y_oCoord(2), r, g, b);
					--
						drawPound(x, y, color(0), r, g, b);
					else
						r <= (others => '0');
						g <= (others => '0');
						b <= (others => '0');
					end if;
					
					next_gameState <= Menu2;
					
			
						
		end case;
	end process;
--
	process(clk50)
	begin
	
		if(rising_edge(clk50)) then
						if(prev_gameState = Start) then p1 <= '0';
													    p2 <= '0';
														replay <= '0'; toMenu <= '0';
														drawTrig <= '0';
						elsif(prev_gameState = Play) then

							
							if(player = '1') then
								
								if   (fieldMap(0,0) = fieldMap(1,0) and fieldMap(1, 0) = fieldMap(2, 0) and fieldMap(0,0) = Cross) then p1 <= '1';
								elsif(fieldMap(0,1) = fieldMap(1,1) and fieldMap(1, 1) = fieldMap(2, 1) and fieldMap(0,1) = Cross) then p1 <= '1';
								elsif(fieldMap(0,2) = fieldMap(1,2) and fieldMap(1, 2) = fieldMap(2, 2) and fieldMap(0,2) = Cross) then p1 <= '1';
							
								elsif(fieldMap(0,0) = fieldMap(0,1) and fieldMap(0, 1) = fieldMap(0, 2) and fieldMap(0,0) = Cross) then p1 <= '1';
								elsif(fieldMap(1,0) = fieldMap(1,1) and fieldMap(1, 1) = fieldMap(1, 2) and fieldMap(1,0) = Cross) then p1 <= '1';
								elsif(fieldMap(2,0) = fieldMap(2,1) and fieldMap(2, 1) = fieldMap(2, 2) and fieldMap(2,0) = Cross) then p1 <= '1';

								elsif(fieldMap(0,0) = fieldMap(1,1) and fieldMap(1, 1) = fieldMap(2, 2) and fieldMap(0,0) = Cross) then p1 <= '1';
								elsif(fieldMap(2,0) = fieldMap(1,1) and fieldMap(1, 1) = fieldMap(0, 2) and fieldMap(2,0) = Cross) then p1 <= '1';
								elsif(drawCounter = 9) then drawTrig <= '1';
								end if;
							elsif(player = '0') then	
								if   (fieldMap(0,0) = fieldMap(1,0) and fieldMap(1, 0) = fieldMap(2, 0) and fieldMap(0,0) = O) then p2 <= '1';
								elsif(fieldMap(0,1) = fieldMap(1,1) and fieldMap(1, 1) = fieldMap(2, 1) and fieldMap(0,1) = O) then p2 <= '1';
								elsif(fieldMap(0,2) = fieldMap(1,2) and fieldMap(1, 2) = fieldMap(2, 2) and fieldMap(0,2) = O) then p2 <= '1';
							
								elsif(fieldMap(0,0) = fieldMap(0,1) and fieldMap(0, 1) = fieldMap(0, 2) and fieldMap(0,0) = O) then p2 <= '1';
								elsif(fieldMap(1,0) = fieldMap(1,1) and fieldMap(1, 1) = fieldMap(1, 2) and fieldMap(1,0) = O) then p2 <= '1';
								elsif(fieldMap(2,0) = fieldMap(2,1) and fieldMap(2, 1) = fieldMap(2, 2) and fieldMap(2,0) = O) then p2 <= '1';

								elsif(fieldMap(0,0) = fieldMap(1,1) and fieldMap(1, 1) = fieldMap(2, 2) and fieldMap(0,0) = O) then p2 <= '1';
								elsif(fieldMap(2,0) = fieldMap(1,1) and fieldMap(1, 1) = fieldMap(0, 2) and fieldMap(2,0) = O) then p2 <= '1';
								elsif(drawCounter = 9) then drawTrig <= '1';
								end if;
						
							end if;
						elsif((prev_gameState = Menu0) or (prev_gameState = Menu1) or (prev_gameState = Menu2)) then
								if   (inReplay = '1' and inToMenu = '0') then replay <= '1';
								elsif(inReplay = '0' and inToMenu = '1') then toMenu <= '1';
								elsif(inReplay = '0' and inToMenu = '0') then replay <= '0'; toMenu <= '0';
								end if;
						end if;
	end if;
					
	end process;
		
end FSM;	