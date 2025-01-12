library ieee;

use ieee.std_logic_1164.all;


entity RGBcontroller is
	port(
		red0, green0, blue0,    -- 0 = ttt
		red1, green1, blue1,    -- 1 = target 
		red2, green2, blue2,    -- 2 = Menu 
		                        -- 3 = connect4
		red3, green3, blue3     : in  std_logic_vector(9 downto 0) := (others => '0');
		tttPlay, targetPlay,
		menuPlay, connect4Play  : in  std_logic := '0';
		r, g, b                 : out std_logic_vector(9 downto 0) := (others => '0'));
end RGBcontroller;

architecture dataflow of RGBController is

signal sel : std_logic_vector(3 downto 0); -- 0111 = connect 4--1011 = ttt : 1101 = target : 1110 = menu
constant black : std_logic_vector(9 downto 0) := (others => '0');
begin

	  sel <= connect4Play & tttPlay & targetPlay & menuPlay;
	
	  with sel select r <=
				red3  when "0111",
				red2  when "1110",
				red1  when "1101",
				red0  when "1011",
				black when others;
				
	  with sel select g <=
				green3 when "0111",
				green2 when "1110",
				green1 when "1101",
				green0 when "1011",
				black  when others;
	  with sel select b <=
			    blue3 when "0111",
				blue2 when "1110",
				blue1 when "1101",
				blue0 when "1011",
				black when others;
	   
end dataflow;


