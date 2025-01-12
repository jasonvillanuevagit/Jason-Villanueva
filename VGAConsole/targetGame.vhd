library ieee;
use ieee.std_logic_1164.all;
use work.target_package.all;
use work.counter_package.all;
use work.properties_package.all;
use work.shape_package.all;
use work.sevenseg_package.all;

entity targetGame is
	generic(
	xMin      : integer := -100;
	xMax      : integer := 800;
	nTargets  : integer := 5);
	port(
	target_clock0,
	target_clock1,
	target_clock2,
	clk25,
	clk50,
	hsync, 
	hactive, vactive, 
	dena,
	reset,
	up, down, lt, rt, button,
	inReplay, inToMenu                        : in  std_logic := '0';
	replay, toMenu                            : out std_logic := '0';
	numberOne, numberTwo                      : out natural range 0 to 10;
	r, g, b								      : out std_logic_vector(9 downto 0) := (others => '0'));
end targetGame; 


	

architecture FSM of targetGame is
----------------------------------------------------------------------------------------------
--Color for targets---------------------------------------------------------------------------
----------------------------------------------------------------------------------------------	
	type colorIndex is array(0 to 4) of integer range 0 to 7;
	constant customColor1  : colorIndex := (4, 2, 1, 5, 3);
	constant customColor2  : colorIndex := (4, 7, 2, 3, 6);
	constant customColor3  : colorIndex := (4, 7, 0, 2, 1);

----------------------------------------------------------------------------------------------
--Game States---------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------		
	type gameState is(Start, Play, Menu);
	signal prev_gameState, next_gameState : gameState;
	
	type yState is(Bot, Mid, Top);
	signal prev_yState, next_yState : yState := Mid;
	
	 

	type detectorState is(Reload, Ready, Fire, yBot, yMid, yTop);
	signal prev_detState, next_detState : detectorState := Reload;
	
----------------------------------------------------------------------------------------------
--Data types for Game-------------------------------------------------------------------------
----------------------------------------------------------------------------------------------		
	
	--Total score-------------------------------------
	signal totalScore : natural range 0 to 999 := 0;
	signal BCDin1,
		   BCDin2,
		   BCDin3   : natural range 0 to 9;
	signal cntClk   : natural;
	--Game time--------------------------------------
	signal startGame : std_logic := '0';
	signal gameTime  : integer range 0 to 60 := 0;
    -------------------------------------------------
	
	--YController time------------------------------------
	signal yRefresh  : std_logic := '1';
	signal yTimer    : integer range 0 to 5 := 0;
	signal yTrigger  : std_logic        := '0';	   
	type   yPos is array(0 to 2) of integer range 0 to 500;
	signal yCoord      : yPos := (90, 200, 380);
    ------------------------------------------------------

	--DetController time------------------------------------
	signal detRefresh  : std_logic := '1';
	signal detTimer    : integer range 0 to 5 := 0;
	signal detTrigger  : std_logic        := '0';
	signal yLocation   : std_logic_vector(2 downto 0);	   
    ------------------------------------------------------

	--XController time------------------------------------
	signal xRefresh  : std_logic := '1';
	signal xTimer    : integer range 0 to 5 := 0;
	signal xTrigger  : std_logic        := '0';
	
	------------------------------------------------------

	--Reticule positions-----------------------------------
	signal xRange    : integer range 0 to 800 := 320;
	signal yCounter  : integer range 0 to 2 := 1;	    
	--------------------------------------------------------
	
	
	--Temp---
	signal target_counter0	: integer range -100 to 800 := 0;
	signal target_counter1	: integer range -100 to 800 := 0;
	signal target_counter2	: integer range -100 to 800 := 0;
	signal detector0            : natural range 0 to 200000;
	signal detector1            : natural range 0 to 200000;
	signal detector2            : natural range 0 to 200000;
	signal detFlag              : std_logic;
	signal xPix                 : natural range 0 to 800;
	signal yPix					: natural range 0 to 525;
	signal temp                 : natural := 320;
	signal allow                : std_logic := '0';
begin


--------------------------------------------------------------------------------------------
--Timer for Target Detector-----------------------------------------------------------------
--------------------------------------------------------------------------------------------	
	process(clk50, detTimer, detRefresh)	
	variable detRefreshTime   : integer range 0 to 50_000_000 := 0;
	begin
	if(detTrigger = '1') then 
									detTimer        <= 0;
									detRefreshTime  := 0;
	elsif(rising_edge(clk50)) then 
			if(detRefreshTime = 50_000_000) then detRefreshTime := detRefreshTime;							   
											      detTimer <= 1;
			else                                  detRefreshTime := detRefreshTime + 1;
			end if;
	end if;
	end process;
--------------------------------------------------------------------------------------------
--Target Detector---------------------------------------------------------------------------
--------------------------------------------------------------------------------------------
	 
	process(clk50)
	begin
	if(rising_edge(clk50)) then 
		if(reset = '1') then prev_detState <= Reload;
		else                 prev_detState <= next_detState;
		end if;
	end if;
	end process;
	
	process(prev_detState)
	
	
	begin
	
		detRefresh <= '0';
		
		case (prev_detState) is 
			when Reload => 
					if(detTimer = 1) then next_detState <= Ready;
					else                   next_detState <= Reload;
					end if;
						 
			when Ready =>  
				if(button = '1' and allow = '1') then next_detState <= Fire; detRefresh <= '1';
				else                  next_detState <= Ready;
				end if;
				
								                
			when Fire => 
			
				if   (yCounter = 0) then next_detState <= yBot;
				elsif(yCounter = 1) then next_detState <= yMid;
				elsif(yCounter = 2) then next_detState <= yTop;
				else                     next_detState <= Fire;
				end if;
			
			when yBot => 
				
				next_detState <= Reload;
			
			when yMid =>
				
				next_detState <= Reload;
			
			when yTop => 
				
				next_detState <= Reload;
				
		end case;
	end process;
	--Logic for detection-----------------------------------------------------------------------
	process(clk50)
	begin	
	
	--Glitch prevention for state tranfer--	
	if(rising_edge(clk50)) then 
			detTrigger <= detRefresh;
	end if;	
	end process;
	---------------------------------------
	

	process(clk50)
	begin
	if(rising_edge(clk50)) then
		if(prev_detState = Ready) then
			detector2 <= (xRange - target_counter2)**2;
			detector1 <= (xRange - target_counter1)**2;
			detector0 <= (xRange - target_counter0)**2;
		end if;
	end if;
	end process;
	
	process(clk50)
	variable detFlag : std_logic := '0';
	begin
	
		
		if   (reset = '1') then totalScore <= 0; numberOne <= 0; numberTwo <= 0;
		elsif(rising_edge(clk50)) then
			
			case (prev_detState) is
				
			
					when yTop =>
							
							if(detFlag = '0') then 
							detFlag := '1';
								if(detector2 <  radii3(0) or detector2 = 0)    then numberOne <= 2; numberTwo <= 0; totalScore <= totalScore + 20; 
								elsif(detector2 <  radii3(1))                  then numberOne <= 1; numberTwo <= 5; totalScore <= totalScore + 15; 
								elsif(detector2 <  radii3(2)) 				   then numberOne <= 0; numberTwo <= 8; totalScore <= totalScore +  8; 
								elsif(detector2 <  radii3(3))				   then numberOne <= 0; numberTwo <= 2; totalScore <= totalScore +  2; 
								elsif(detector2 <  radii3(4))				   then numberOne <= 0; numberTwo <= 1; totalScore <= totalScore +  1; 
								else                                                numberOne <= 0; numberTwo <= 0; totalScore <= totalScore;	
								end if;
							end if;  
						
							
					when yMid => 
							if(detFlag = '0') then 
							detFlag := '1';
								if   (detector1 <  radii2(0) or detector1 = 0) then numberOne <= 3; numberTwo <= 0; totalScore <= totalScore + 30;
								elsif(detector1 <  radii2(1))                  then numberOne <= 2; numberTwo <= 0; totalScore <= totalScore + 20; 
								elsif(detector1 <  radii2(2)) 				   then numberOne <= 1; numberTwo <= 0; totalScore <= totalScore + 10; 
								elsif(detector1 <  radii2(3))				   then numberOne <= 0; numberTwo <= 5; totalScore <= totalScore +  5; 
								elsif(detector1 <  radii2(4))				   then numberOne <= 0; numberTwo <= 3; totalScore <= totalScore +  3; 
								else                                                numberOne <= 0; numberTwo <= 0; totalScore <= totalScore;	   
								end if;
							end if;
					when yBot =>
						
							if(detFlag = '0') then 
							detFlag := '1';   
								if   (detector0 <  radii1(0) or detector0 = 0) then numberOne <= 5; numberTwo <= 0; totalScore <= totalScore + 50; 
								elsif(detector0 <  radii1(1))                  then numberOne <= 3; numberTwo <= 0; totalScore <= totalScore + 30; 
								elsif(detector0 <  radii1(2)) 				   then numberOne <= 2; numberTwo <= 0; totalScore <= totalScore + 20; 
								elsif(detector0 <  radii1(3))				   then numberOne <= 1; numberTwo <= 0; totalScore <= totalScore + 10; 
								elsif(detector0 <  radii1(4))				   then numberOne <= 0; numberTwo <= 5; totalScore <= totalScore +  5; 
								else                                                numberOne <= 0; numberTwo <= 0; totalScore <= totalScore;	   
								end if;
							end if;
							
					when others => 
							detFlag := '0';
							

			end case;
		end if;
		
	end process;


----------------------------------------------------------------------------------------------
--XController--------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------	
	process(clk50)
	begin
	
	if(rising_edge(clk50)) then
		if(reset = '1') then xRange <= 320;
		elsif(Lt = '1' and Rt = '0')  then 
			if(xRange > 0) then xRange <= xRange - 10;
			end if;
		elsif(Lt = '0' and Rt = '1') then
			if(xRange < 640) then xRange <= xRange + 10;	
		 	end if;
		end if;
	end if;
	end process;
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
			if(yRefreshTime = 20_000_000) then yRefreshTime := yRefreshTime;							   
											   yTimer <= 1;
			else 							   yRefreshTime := yRefreshTime + 1;
			end if;
	end if;
	end process;

----------------------------------------------------------------------------------------------
--FSM for YController-------------------------------------------------------------------------
----------------------------------------------------------------------------------------------	
	process(clk50)
	begin
	if(rising_edge(clk50)) then 
		if(reset = '1') then prev_yState <= Mid;
		else                 prev_yState <= next_yState;
		end if;
	end if;
	end process;
	
	process(prev_yState, yRefresh, yCounter, Up, Down, yTimer, yTrigger)
	begin
		
		case (prev_yState) is 
			when Bot => 
						yCounter <= 2;
						yRefresh <= '0';
						if(yTimer = 1) then
							if(Up = '1' and Down = '0') then next_yState <= Mid;
															 yRefresh <= '1';
							else                             next_yState <= Bot;
							end if;
						else                                 next_yState <= Bot;
						end if;

					
			when Mid => 
						yCounter <= 1;
						yRefresh <= '0';
						if(yTimer = 1) then
							if   (Up = '1' and Down = '0') then next_yState <= Top;
											      			    yRefresh <= '1';
							elsif(Up = '0' and Down = '1') then next_yState <= Bot;
												   			    yRefresh <= '1';
							else                                next_yState <= Mid;
							end if;
						else next_yState <= Mid;
						end if;
					 
								                
			when Top => 
						yCounter <= 0;
						yRefresh <= '0';
						if(yTimer = 1) then
							if(Up = '0' and Down = '1') then next_yState <= Mid;
															 yRefresh <= '1';
							else                             next_yState <= Top;
							end if;
						else next_yState <= Top;
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
----------------------------------------------------------------------------------------------
--Timer for game------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------	
	
	process(clk50)	
	variable gameCounter	 : integer range 0 to 50_000_000 := 0;
	begin
 
	if(startGame = '1') then 
		if(rising_edge(clk50)) then 
			gameCounter := gameCounter + 1;
				if(gameCounter = 50_000_000) then gameCounter   := 0;
												  gameTime <= gameTime + 1;
				end if;
		end if;
	else
		gameTime      <=0;
		gameCounter  := 0;
	end if;
	end process;

----------------------------------------------------------------------------------------------
--Total Score---------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------

	process(clk50)
	begin
		
		
		if(rising_edge(clk50)) then
			if(reset = '1') then BCDin1 <= 0;
								 BCDin2 <= 0;
								 BCDin3 <= 0;
								 cntClk <= 0;
			elsif (cntClk < totalScore) then 
					if(BCDin2 = 9) and (BCDin1 = 9) then
						BCDin1 <= 0;
						BCDin2 <= 0;
						BCDin3 <= BCDin3 + 1;
					cntClk <= cntClk + 1;
					elsif(BCDin1 = 9) then 
						BCDin1 <= 0;
						BCDin2 <= BCDin2 + 1;
					cntClk <= cntClk + 1;
					else           
						BCDin1 <= BCDin1 + 1;
					cntClk <= cntClk + 1;
					end if;
			end if;
		end if;
	end process;

----------------------------------------------------------------------------------------------
--FSM for Game--------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------
	--Keeping track the targets on the screen---------------
	process(target_clock0, reset)
	begin
	if(allow = '1') then
	sigCounter(target_clock0, reset, 800, -100, target_counter0);
	end if;
	end process;
	
	process(target_clock1, reset)
	begin
	if(allow = '1') then
	sigCounter(target_clock1, reset, 800, -100, target_counter1);
	end if;
	end process;
	
	process(target_clock2, reset)
	begin
	if(allow = '1') then
    sigCounter(target_clock2, reset, 800, -100, target_counter2);
	end if;
	end process;
	-----------------------------------------------------------
	
	--Count columns:------------------------
	process(clk25)
	begin
	pos_edgeCounter(clk25, Hactive, xPix);
	end process;
	----------------------------------------

    --Count lines:--------------------------
	process(hsync)
	begin
	pos_edgeCounter(hsync, Vactive, yPix);
	end process;
	---------------------------------------
	
	--gameStates---------------------------
	process(clk50)
	begin
	if(rising_edge(clk50)) then
		if(reset = '1') then prev_gameState <= Start;
		else                 prev_gameState <= next_gameState;
		end if;
	end if;
	end process;
	----------------------------------------
	
	
	--Next State Logic-------------------
	process (prev_gameState)
	variable yOne            : integer := yCoord(0);
	variable yTwo            : integer := yCoord(1);
	variable yThree          : integer := yCoord(2); 
	variable     x      	 : integer range 0    to xMax;
	variable     y       	 : integer range 0    to 525;
	begin

-------------------------------------------------------
	x := xPix;
	y := yPix;
	
	case (prev_gameState) is
		
		when Start =>  
		allow <= '0';
						if (dena = '1') then
							r <= (others => '1');
							g <= (others => '0');
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
						--Counter:------------------------------
						if (dena = '1') then
						
						r <= (others => '1');
						g <= (others => '1');
						b <= (others => '1');
	
						for i in 0 to nTargets-1 loop  --Loop to create circles	
							drawDisc(x, y, target_counter0, yOne, radii1((nTargets-1)-i), color(customColor1((nTargets-1)-i)), r, g, b);
						end loop;
						
						for i in 0 to nTargets-1 loop  --Loop to create circles	
							drawDisc(x, y, target_counter1, yTwo, radii2((nTargets-1)-i), color(customColor2((nTargets-1)-i)), r, g, b);
						end loop;
						
						for i in 0 to nTargets-1 loop  --Loop to create circles	
							drawDisc(x, y, target_counter2, yThree, radii3((nTargets-1)-i), color(customColor3((nTargets-1)-i)), r, g, b);
						end loop;
						
    					drawReticule(x, y, xRange, yCoord(yCounter), 1, 6, color(0), r, g, b);
						
						SevenSeg_shapes(x, y, color(0), r, g, b);
						decode7seg(x, y, BCDin1, BCDin2, BCDin3, color(7), r, g, b);
						
						else
						r <= (others => '0');
						g <= (others => '0');
						b <= (others => '0');
						end if;
						
						if(gameTime = 33) then next_gameState <= Menu; 
						else                   next_gameState <= Play;
						end if;
						startGame <= '1';
						
		when Menu => 
		allow <= '0';
					startGame <= '0';
					if (dena = '1') then
						if(totalScore >= 250) then
						r <= (others => '0');
						g <= (others => '0');
						b <= (others => '1');
							for i in 0 to nTargets-1 loop  --Loop to create circles	
							drawDisc(x, y, target_counter0, yOne, radii1((nTargets-1)-i), color(customColor1((nTargets-1)-i)), r, g, b);
							end loop;
						
							for i in 0 to nTargets-1 loop  --Loop to create circles	
							drawDisc(x, y, target_counter1, yTwo, radii2((nTargets-1)-i), color(customColor2((nTargets-1)-i)), r, g, b);
							end loop;
						
							for i in 0 to nTargets-1 loop  --Loop to create circles	
								drawDisc(x, y, target_counter2, yThree, radii3((nTargets-1)-i), color(customColor3((nTargets-1)-i)), r, g, b);
							end loop;
							SevenSeg_shapes(x, y, color(0), r, g, b);
							decode7seg(x, y, BCDin1, BCDin2, BCDin3, color(7), r, g, b);
						else
						r <= (others => '1');
						g <= (others => '0');
						b <= (others => '0');
							
							for i in 0 to nTargets-1 loop  --Loop to create circles	
								drawDisc(x, y, target_counter0, yOne, radii1((nTargets-1)-i), color(customColor1((nTargets-1)-i)), r, g, b);
							end loop;
							
							for i in 0 to nTargets-1 loop  --Loop to create circles	
								drawDisc(x, y, target_counter1, yTwo, radii2((nTargets-1)-i), color(customColor2((nTargets-1)-i)), r, g, b);
							end loop;
							
							for i in 0 to nTargets-1 loop  --Loop to create circles	
								drawDisc(x, y, target_counter2, yThree, radii3((nTargets-1)-i), color(customColor3((nTargets-1)-i)), r, g, b);
							end loop;
							SevenSeg_shapes(x, y, color(0), r, g, b);
							decode7seg(x, y, BCDin1, BCDin2, BCDin3, color(7), r, g, b);
						end if;
						
					else
						r <= (others => '0');
						g <= (others => '0');
						b <= (others => '0');
					end if;
					
					next_gameState <= Menu;
						
		end case;
	end process;	
	
	process(clk50)
	begin
	if(rising_edge(clk50)) then
		if(reset = '1') then replay <= '0'; toMenu <= '0';
		else
					if(prev_GameState = Menu) then
							if   (inReplay = '1' and inToMenu = '0') then replay <= '1';
							elsif(inReplay = '0' and inToMenu = '1') then toMenu <= '1';
							elsif(inReplay = '0' and inToMenu = '0') then replay <= '0'; toMenu <= '0';
							end if;
					end if;
		end if;
	end if;
	end process;
end FSM;
 

