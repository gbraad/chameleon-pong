-- -----------------------------------------------------------------------
--
-- Turbo Chameleon Pong 0.0.4 for chameleon v2 hardware
--
-- -----------------------------------------------------------------------
--
-- left button:  reset game
-- right button: reload core slot 0
-- press mouse button on either ps/2 port to play
--
-- game is over when one player reaches a score of 05
--
-- TODO:
-- A sound effect for a point being scored.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- -----------------------------------------------------------------------

architecture rtl of chameleon2 is
   constant reset_cycles : integer := 131071;

	type gamestate_t is (GAME_SERVEP1, GAME_SERVEP2, GAME_ON, GAME_INIT, GAME_WON_P1, GAME_WON_P2, GAME_JOIN_P1, GAME_JOIN_P2);
	
-- System clocks
	signal sysclk : std_logic;
	signal clk_150 : std_logic;
	signal sd_clk_loc : std_logic;
	signal clk_locked : std_logic;
	signal ena_1mhz : std_logic;
	signal ena_1khz : std_logic;
	signal phi2 : std_logic;
--	signal no_clock : std_logic;

--	signal reset_button_n : std_logic;
--	signal menu_button_n : std_logic;
	
-- Global signals
	signal reset : std_logic;
	signal end_of_pixel : std_logic;

--	signal usart_rx : std_logic;

-- LEDs
	signal led_green : std_logic;
	signal led_red : std_logic;

-- Docking station
	signal no_clock : std_logic;
	signal docking_station : std_logic;
	signal phi_cnt : unsigned(7 downto 0);
	signal phi_end_1 : std_logic;
	
-- PS/2 Keyboard socket - used for second mouse
	signal ps2_keyboard_clk_in : std_logic;
	signal ps2_keyboard_dat_in : std_logic;
	signal ps2_keyboard_clk_out : std_logic;
	signal ps2_keyboard_dat_out : std_logic;

-- PS/2 Mouse
	signal ps2_mouse_clk_in: std_logic;
	signal ps2_mouse_dat_in: std_logic;
	signal ps2_mouse_clk_out: std_logic;
	signal ps2_mouse_dat_out: std_logic;

	signal mouse_present : std_logic;
	signal mouse_active : std_logic;
	signal mouse_trigger : std_logic;
	signal mouse_left_button : std_logic;
	signal mouse_middle_button : std_logic;
	signal mouse_right_button : std_logic;
	signal mouse_delta_x : signed(8 downto 0);
	signal mouse_delta_y : signed(8 downto 0);
	signal mouse_delta_z : signed(8 downto 0);

	signal mouse2_present : std_logic;
	signal mouse2_active : std_logic;
	signal mouse2_trigger : std_logic;
	signal mouse2_left_button : std_logic;
	signal mouse2_middle_button : std_logic;
	signal mouse2_right_button : std_logic;
	signal mouse2_delta_x : signed(8 downto 0);
	signal mouse2_delta_y : signed(8 downto 0);
	signal mouse2_delta_z : signed(8 downto 0);
	
	signal cursor_x : signed(11 downto 0) := to_signed(0, 12);
	signal cursor_y : signed(11 downto 0) := to_signed(0, 12);
	signal cursor_z : signed(11 downto 0) := to_signed(0, 12);
	signal cursor2_x : signed(11 downto 0) := to_signed(0, 12);
	signal cursor2_y : signed(11 downto 0) := to_signed(0, 12);
	signal cursor2_z : signed(11 downto 0) := to_signed(0, 12);
	
	signal sdram_req : std_logic := '0';
	signal sdram_ack : std_logic;
	signal sdram_we : std_logic := '0';
	signal sdram_a : unsigned(24 downto 0) := (others => '0');
	signal sdram_d : unsigned(7 downto 0);
	signal sdram_q : unsigned(7 downto 0);

-- VGA
	signal currentX : unsigned(11 downto 0);
	signal currentY : unsigned(11 downto 0);

	type stage_t is record
			ena_pixel : std_logic;
			hsync : std_logic;
			vsync : std_logic;
			x : unsigned(11 downto 0);
			y : unsigned(11 downto 0);
			r : unsigned(4 downto 0);
			g : unsigned(4 downto 0);
			b : unsigned(4 downto 0);
		end record;
	signal vga_master : stage_t;
	
	signal wred : unsigned(7 downto 0);
	signal wgrn : unsigned(7 downto 0);
	signal wblu : unsigned(7 downto 0);


	signal drawdigit0 : boolean;
	signal drawdigit1 : boolean;
	signal drawdigit2 : boolean;
	signal drawdigit3 : boolean;

-- Sound
	signal beep_period_l : unsigned(15 downto 0);
	signal beep_amplitude_l : unsigned(7 downto 0);
	signal beep_period_r : unsigned(15 downto 0);
	signal beep_amplitude_r : unsigned(7 downto 0);

-- Game state
	signal ball_x : signed(13 downto 0) := "00101000000000";
	signal ball_y : signed(13 downto 0) := "00011110000000";
	signal ball_vel_x : signed(9 downto 0) := "0000001100";
	signal ball_vel_y : signed(9 downto 0) := "0000001100";
	signal ball_col_top : std_logic;
	signal ball_col_bottom : std_logic;
	signal ball_col_left : std_logic;
	signal ball_col_right : std_logic;
	signal ball_goal_p1 : std_logic;	-- High when player scores, used as a
	signal ball_goal_p2 : std_logic;	-- rising edge to clock the score counters.
	signal pause_ctr : unsigned(9 downto 0) := "0000000000";

	signal clear_scores : std_logic;
	
	signal player1_active : boolean := false;  -- When high, p1 is mouse controlled, else computer.
	signal player1_y : signed(13 downto 0) := TO_SIGNED(120*8,14);
	signal score_p1 : unsigned(7 downto 0) := "00000000";  -- Binary-coded decimal, to make 
	signal score_p1_shade : unsigned(7 downto 0);
 	signal player2_active : boolean := false;  -- When high, p2 is mouse controlled, else computer.
	signal player2_y : signed(13 downto 0) := TO_SIGNED(360*8,14);
	signal score_p2 : unsigned(7 downto 0) := "00000000";  -- life easy for the segment display!
	signal score_p2_shade : unsigned(7 downto 0);

	signal gamestate : gamestate_t := GAME_INIT;

begin
-- -----------------------------------------------------------------------
-- Unused pins
-- -----------------------------------------------------------------------
	iec_clk_out <= '0';
	iec_atn_out <= '0';
	iec_dat_out <= '0';
	iec_srq_out <= '0';
	irq_out <= '0';
	nmi_out <= '0';

	-- put these here?
	flash_cs <= '1';
	mmc_cs <= '1';
	rtc_cs <= '0';
	
-- -----------------------------------------------------------------------
-- VGA
-- -----------------------------------------------------------------------
	hsync_n <= not vga_master.hsync;
	vsync_n <= not vga_master.vsync;

-- -----------------------------------------------------------------------
-- Clocks and PLL
-- -----------------------------------------------------------------------
	pllInstance : entity work.pll50
		port map (
			inclk0 => clk50m,
			c0 => sysclk,
			c1 => open, 
			c2 => clk_150,
			c3 => sd_clk_loc,
			locked => clk_locked
		);
	ram_clk <= sd_clk_loc;

-- -----------------------------------------------------------------------
-- Reset
-- -----------------------------------------------------------------------
	myReset : entity work.gen_reset
		generic map (
			resetCycles => reset_cycles
		)
		port map (
			clk => sysclk,
			enable => '1',

			button => not reset_btn,
			reset => reset
		);

-- -----------------------------------------------------------------------
-- 1 Mhz and 1 Khz clocks
-- -----------------------------------------------------------------------
	my1Mhz : entity work.chameleon_1mhz
		generic map (
			clk_ticks_per_usec => 100
		)
		port map (
			clk => sysclk,
			ena_1mhz => ena_1mhz,
			ena_1mhz_2 => open
		);

	my1Khz : entity work.chameleon_1khz
		port map (
			clk => sysclk,
			ena_1mhz => ena_1mhz,
			ena_1khz => ena_1khz
		);
	
-- -----------------------------------------------------------------------
-- PS2IEC multiplexer
-- -----------------------------------------------------------------------
	io_ps2iec_inst : entity work.chameleon2_io_ps2iec
		port map (
			clk => sysclk,

			ps2iec_sel => ps2iec_sel,
			ps2iec => ps2iec,

			ps2_mouse_clk => ps2_mouse_clk_in,
			ps2_mouse_dat => ps2_mouse_dat_in,
			ps2_keyboard_clk => ps2_keyboard_clk_in,
			ps2_keyboard_dat => ps2_keyboard_dat_in,

			iec_clk => open, -- iec_clk_in,
			iec_srq => open, -- iec_srq_in,
			iec_atn => open, -- iec_atn_in,
			iec_dat => open  -- iec_dat_in
		);

-- -----------------------------------------------------------------------
-- LED, PS2 and reset shiftregister
-- -----------------------------------------------------------------------
	io_shiftreg_inst : entity work.chameleon2_io_shiftreg
		port map (
			clk => sysclk,

			ser_out_clk => ser_out_clk,
			ser_out_dat => ser_out_dat,
			ser_out_rclk => ser_out_rclk,

			reset_c64 => reset,
			reset_iec => reset,
			ps2_mouse_clk => ps2_mouse_clk_out,
			ps2_mouse_dat => ps2_mouse_dat_out,
			ps2_keyboard_clk => ps2_keyboard_clk_out,
			ps2_keyboard_dat => ps2_keyboard_dat_out,
			led_green => led_green,
			led_red => led_red
		);

-- -----------------------------------------------------------------------
-- Chameleon IO, docking station and cartridge port
-- -----------------------------------------------------------------------
	chameleon2_io_blk : block
	begin
		chameleon2_io_inst : entity work.chameleon2_io
			generic map (
				enable_docking_station => true,
				enable_cdtv_remote => true,
				enable_c64_joykeyb => true,
				enable_c64_4player => true
			)
			port map (
				clk => sysclk,
				ena_1mhz => ena_1mhz,
				phi2_n => phi2_n,
				dotclock_n => dotclk_n,

				reset => reset,

				ir_data => ir_data,
				ioef => ioef,
				romlh => romlh,

				dma_out => dma_out,
				game_out => game_out,
				exrom_out => exrom_out,

				ba_in => ba_in,
--				rw_in => rw_in,
				rw_out => rw_out,

				sa_dir => sa_dir,
				sa_oe => sa_oe,
				sa15_out => sa15_out,
				low_a => low_a,

				sd_dir => sd_dir,
				sd_oe => sd_oe,
				low_d => low_d,

				no_clock => no_clock,
				docking_station => docking_station,

				phi_cnt => phi_cnt,
				phi_end_1 => phi_end_1,

--				joystick1 => joystick1,
--				joystick2 => joystick2,
--				joystick3 => joystick3,
--				joystick4 => joystick4,
				joystick1 => open,
				joystick2 => open,
				joystick3 => open,
				joystick4 => open,
--				keys => keys,
--				restore_key_n => restore_n
				keys => open,
				restore_key_n => open
			);
	end block;
		
-- -----------------------------------------------------------------------
-- Sound test
-- -----------------------------------------------------------------------
	leftbeeper: entity work.squarewave
		port map (sysclk,beep_period_l,beep_amplitude_l,sigma_l);

	process(sysclk)
	begin
		if rising_edge(sysclk) then
			if(gamestate = GAME_ON) then
				if (ball_col_left = '1') then
					beep_period_l <= TO_UNSIGNED(2500,16);	-- High beep for ball hitting paddle
					beep_amplitude_l <= TO_UNSIGNED(80,8);	-- loud and on left channel only
				elsif (ball_col_top = '1') then
					beep_period_l <= TO_UNSIGNED(5000,16);  -- Low beep for top and bottom edge
					beep_amplitude_l <= TO_UNSIGNED(48,8);  -- quieter because it sounds on
				elsif (ball_col_bottom = '1') then			-- both channels
					beep_period_l <= TO_UNSIGNED(5000,16);
					beep_amplitude_l <= TO_UNSIGNED(48,8);
				else
					beep_period_l <= TO_UNSIGNED(40000,16);	-- in-game phase drone - quiet
					beep_amplitude_l <= TO_UNSIGNED(4,8);
				end if;
			else
				beep_period_l <= TO_UNSIGNED(40000,16);		-- serve mode phase drone - loud
				beep_amplitude_l <= TO_UNSIGNED(16,8);
			end if;
		end if;
	end process;


	rightbeeper: entity work.squarewave
		port map (sysclk,beep_period_r,beep_amplitude_r,sigma_r);

	process(sysclk)
	begin
		if rising_edge(sysclk) then
			if(gamestate=GAME_ON) then
				if (ball_col_right = '1') then
					beep_period_r <= TO_UNSIGNED(2500,16);	-- High beep for ball hitting paddle
					beep_amplitude_r <= TO_UNSIGNED(80,8);  -- loud and on right channel only
				elsif (ball_col_top = '1') or (ball_col_bottom = '1') then
					beep_period_r <= TO_UNSIGNED(5000,16);  -- Low beep for top and bottom edge
					beep_amplitude_r <= TO_UNSIGNED(48,8);  -- quieter because it sounds on
				elsif (ball_col_bottom = '1') then			-- both channels
					beep_period_r <= TO_UNSIGNED(5000,16);
					beep_amplitude_r <= TO_UNSIGNED(48,8);
				else
					beep_period_r <= TO_UNSIGNED(40100,16);	-- in-game phase drone - quiet
					beep_amplitude_r <= TO_UNSIGNED(4,8);
				end if;
			else
				beep_period_r <= TO_UNSIGNED(40100,16);		-- serve-mode phase drone - loud
				beep_amplitude_r <= TO_UNSIGNED(16,8);
			end if;
		end if;
	end process;

-- -----------------------------------------------------------------------
----					irq_n <= mux_q(2);
----					ir <= mux_q(3);
----					vga_id <= mux_q;
--					ps2_keyboard_dat_in <= mux_q(0);
--					ps2_keyboard_clk_in <= mux_q(1);
--					ps2_mouse_dat_in <= mux_q(2);
--					ps2_mouse_clk_in <= mux_q(3);
--					mux_d_reg <= "10" & led_green & led_red;
--					mux_reg <= X"B";
--					mux_d_reg <= usart_rx & "111";
--					mux_d_reg(0) <= ps2_keyboard_dat_out;
--					mux_d_reg(1) <= ps2_keyboard_clk_out;
--					mux_d_reg(2) <= ps2_mouse_dat_out;
--					mux_d_reg(3) <= ps2_mouse_clk_out;

reconfigurer : entity work.chameleon_reconfigure
port map (
	clk => sysclk,
	reconfigure => not usart_cts, -- Shared with button!
--	reconfigure => not freeze_btn, --???
	serial_clk => usart_clk,
	serial_txd => usart_rx,
	serial_cts_n => usart_rts
	);
	
-- -----------------------------------------------------------------------
-- Mouse controller
-- -----------------------------------------------------------------------
	myMouse : entity work.io_ps2_mouse
		generic map (
			ticksPerUsec => 100
		)
		port map (
			clk => sysclk,
			reset => reset,

			ps2_clk_in => ps2_mouse_clk_in,
			ps2_dat_in => ps2_mouse_dat_in,
			ps2_clk_out => ps2_mouse_clk_out,
			ps2_dat_out => ps2_mouse_dat_out,

			mousePresent => mouse_present,

			trigger => mouse_trigger,
			leftButton => mouse_left_button,
			middleButton => mouse_middle_button,
			rightButton => mouse_right_button,
			deltaX => mouse_delta_x,
			deltaY => mouse_delta_y
		);


-- -----------------------------------------------------------------------
-- Second mouse controller
-- -----------------------------------------------------------------------
	myMouse2 : entity work.io_ps2_mouse
		generic map (
			ticksPerUsec => 100
		)
		port map (
			clk => sysclk,
			reset => reset,

			ps2_clk_in => ps2_keyboard_clk_in,
			ps2_dat_in => ps2_keyboard_dat_in,
			ps2_clk_out => ps2_keyboard_clk_out,
			ps2_dat_out => ps2_keyboard_dat_out,

			mousePresent => mouse2_present,

			trigger => mouse2_trigger,
			leftButton => mouse2_left_button,
			middleButton => mouse2_middle_button,
			rightButton => mouse2_right_button,
			deltaX => mouse2_delta_x,
			deltaY => mouse2_delta_y
		);

-- -----------------------------------------------------------------------
-- Score counters
-- -----------------------------------------------------------------------

	scorecounter1 : entity work.scorecounter
	port map (
		clk => ball_goal_p1,
		counter => score_p1,
		clear => clear_scores
	);
	scorecounter2 : entity work.scorecounter
	port map (
		clk => ball_goal_p2,
		counter => score_p2,
		clear => clear_scores
	);

-- -----------------------------------------------------------------------
-- VGA timing configured for 640x480
-- -----------------------------------------------------------------------
	myVgaMaster : entity work.video_vga_master
		generic map (
			clkDivBits => 4
		)
		port map (
			clk => sysclk,
			-- 100 Mhz / (3+1) = 25 Mhz
			clkDiv => X"3",

			hSync => vga_master.hSync,
			vSync => vga_master.vSync,

			endOfPixel => end_of_pixel,
			endOfLine => open,
			endOfFrame => open,
			currentX => currentX,
			currentY => currentY,

			-- Setup 640x480@60hz needs ~25 Mhz
			hSyncPol => '0',
			vSyncPol => '0',
			xSize => to_unsigned(800, 12),
			ySize => to_unsigned(525, 12),
			xSyncFr => to_unsigned(656, 12), -- Sync pulse 96
			xSyncTo => to_unsigned(752, 12),
			ySyncFr => to_unsigned(500, 12), -- Sync pulse 2
			ySyncTo => to_unsigned(502, 12)
		);

-- -----------------------------------------------------------------------
--
-- Reposition mouse cursor.
-- I like to move it, move it. You like to move it, move it.
-- We like to move it, move it. So just move it!
-- -----------------------------------------------------------------------
	process(sysclk)
		variable newX : signed(11 downto 0);
		variable newY : signed(11 downto 0);
		variable newX2 : signed(11 downto 0);
		variable newY2 : signed(11 downto 0);
		variable newZ : signed(11 downto 0);
		variable newZ2 : signed(11 downto 0);
	begin
		if rising_edge(sysclk) then
		--
		-- Calculate new cursor coordinates
		-- deltaY is subtracted as line count runs top to bottom on the screen.
			newX := cursor_x + mouse_delta_x;
			newY := cursor_y - mouse_delta_y;
			newZ := cursor_z - mouse_delta_z;	-- Mouse wheel
			newX2 := cursor2_x - mouse2_delta_x;
			newY2 := cursor2_y - mouse2_delta_y;
			newZ2 := cursor2_z - mouse2_delta_z;	-- Mouse wheel
		--
		-- Limit mouse cursor to screen
			if newX > 640 then
				newX := to_signed(640, 12);
			end if;
			if newX < 0 then
				newX := to_signed(0, 12);
			end if;
			if newY > 480 then
				newY := to_signed(480, 12);
			end if;
			if newY < 0 then
				newY := to_signed(0, 12);
			end if;

			if newX2 > 640 then
				newX2 := to_signed(640, 12);
			end if;
			if newX2 < 0 then
				newX2 := to_signed(0, 12);
			end if;
			if newY2 > 480 then
				newY2 := to_signed(480, 12);
			end if;
			if newY2 < 0 then
				newY2 := to_signed(0, 12);
			end if;
		--
		-- Update cursor location
			if mouse_trigger = '1' then
				cursor_x <= newX;
				cursor_y <= newY;
				cursor_z <= newZ;	-- Mouse wheel
			end if;
			if mouse2_trigger = '1' then
				cursor2_x <= newX2;
				cursor2_y <= newY2;
				cursor2_z <= newZ2;	-- Mouse wheel
			end if;
		end if;
	end process;

-- -----------------------------------------------------------------------
-- Score rendering
-- -----------------------------------------------------------------------

	-- P1's score
	
	segdisplay0 : entity work.segmentdisplay
		generic map (
			lft => TO_UNSIGNED(200,12),
			top => TO_UNSIGNED(10,12)
		)
		port map (
			xpos => CurrentX,
			ypos => CurrentY,
			digit => score_p1(7 downto 4),
			draw => drawdigit0
		);

	segdisplay1 : entity work.segmentdisplay
		generic map (
			lft => TO_UNSIGNED(226,12),
			top => TO_UNSIGNED(10,12)
		)
		port map (
			xpos => CurrentX,
			ypos => CurrentY,
			digit => score_p1(3 downto 0),
			draw => drawdigit1
		);

	-- P2's score
	
	segdisplay2 : entity work.segmentdisplay
		generic map (
			lft => TO_UNSIGNED(394,12),
			top => TO_UNSIGNED(10,12)
		)
		port map (
			xpos => CurrentX,
			ypos => CurrentY,
			digit => score_p2(7 downto 4),
			draw => drawdigit2
		);

	segdisplay3 : entity work.segmentdisplay
		generic map (
			lft => TO_UNSIGNED(420,12),
			top => TO_UNSIGNED(10,12)
		)
		port map (
			xpos => CurrentX,
			ypos => CurrentY,
			digit => score_p2(3 downto 0),
			draw => drawdigit3
		);
		
-- VGADither
	vgadithering : entity work.vgadither
		port map (
			pixelclock => end_of_pixel,
			X => currentX(9 downto 0),
			Y => currentY(9 downto 0),
			VSync => vga_master.vsync,
			enable => '1',
			iRed => wred,
			iGreen => wgrn,
			iBlue => wblu,
			oRed => red,
			oGreen => grn,
			oBlue => blu
		);


-- -----------------------------------------------------------------------
-- VGA colors
-- -----------------------------------------------------------------------
	process(sysclk, currentX, currentY)
		variable x : signed(11 downto 0);
		variable y : signed(11 downto 0);
		variable bg : unsigned(4 downto 0);
		variable dy : signed(13 downto 0);
		variable dy2 : signed(13 downto 0);
	begin
		x := signed(currentX);
		y := signed(currentY);
		if reset='1' then
			gamestate <= GAME_INIT;
		elsif rising_edge(sysclk) then
			if end_of_pixel = '1' then

				-- Avoid concurrency problems by detecting collisions at a different time
				-- from updating ball position.
				-- We essentially use a simple sequential state machine with the state
				-- determined by the horizonal pixel position on the top row.

				if (currentX=0) and (currentY=0) then
					-- React to collisions by inverting either the horizontal or vertical
					-- component of the ball's velocity.
					-- When the ball hits a paddle we make the Y component dependent upon
					-- where on the paddle the ball strikes, and also speed up the ball.
					if ball_col_left = '1' then
						ball_vel_x <= abs(ball_vel_x)+2;
						dy := (ball_y - player1_y);
						ball_vel_y <= ball_vel_y(9) & ball_vel_y(9 downto 1) + signed(dy(8 downto 3));
						ball_col_left <= '0';
						ball_col_right <= '0';
					end if;
					if ball_col_right = '1' then
						ball_vel_x <= (-abs(ball_vel_x))-2;
						dy := (ball_y - player2_y);
						ball_vel_y <= ball_vel_y(9) & ball_vel_y(9 downto 1) + signed(dy(8 downto 3));
						ball_col_left <= '0';
						ball_col_right <= '0';
					end if;
					if ball_col_top = '1' then
						ball_vel_y <= -ball_vel_y;	
						ball_col_top <= '0';
					end if;
					if ball_col_bottom = '1' then
						ball_vel_y <= -ball_vel_y;	
						ball_col_bottom <= '0';
					end if;
					
					pause_ctr <= pause_ctr-1;		
				end if;
				
				if(currentX=1) and (currentY=0) then
					-- Update paddle position
					-- If a player clicks the left mouse button they can join the game...
					if player1_active = false and mouse_left_button = '1' then
						player1_active <= true;
						clear_scores <= '1';
						gamestate <= GAME_JOIN_P1;
					elsif player2_active = false and mouse2_left_button = '1' then
						player2_active <= true;
						clear_scores <= '1';
						gamestate <= GAME_JOIN_P2;
					else
						clear_scores <= '0';
					end if;

					if(player1_active) then
						player1_y <= cursor_y(10 downto 0) & "000";
					elsif ball_vel_x < 0 then
						dy := ball_y-player1_y;
						if dy<-128 then
							player1_y <= player1_y - 32;
						elsif dy>128 then
							player1_y <= player1_y + 32;
						end if;
					end if;
					if(player2_active) then
						player2_y <= cursor2_y(10 downto 0) & "000";
					elsif ball_vel_x > 0 then
						dy2 := ball_y-player2_y;
						if dy2 < -128 then
							player2_y <= player2_y - 32;
						elsif dy2 > 128 then
							player2_y <= player2_y + 32;
						end if;
					end if;
				end if;
				
				-- Update ball position
				if(currentX=2) and (currentY=0) then

					case gamestate is
						when GAME_JOIN_P1 =>
							if(mouse_left_button='0') then
								gamestate<=GAME_SERVEP1;
							end if;
						when GAME_JOIN_P2 =>
							if(mouse2_left_button='0') then
								gamestate<=GAME_SERVEP2;
							end if;
						when GAME_ON =>
							ball_x <= (ball_x + ball_vel_x);
							ball_y <= (ball_y + ball_vel_y);
						when GAME_SERVEP1 =>
							-- FIXME - wait until mouse button is released
							if(score_p1 = 5) then
								pause_ctr <= TO_UNSIGNED(512,10);
								gamestate <= GAME_WON_P1;
							end if;
							ball_x <= TO_SIGNED(11*8,14);
							ball_y <= player1_y;
							ball_vel_y <= player1_y(12 downto 6) - TO_SIGNED(30,10);
							ball_goal_p1<= '0';
							if(mouse_left_button = '1' or ((player1_active = false) and (pause_ctr = 0))) then
								ball_vel_x <= TO_SIGNED(-20,10);
								gamestate <= GAME_ON;
							end if;
						when GAME_SERVEP2 =>
							if(score_p2 = 5) then
								pause_ctr <= TO_UNSIGNED(512,10);
								gamestate <= GAME_WON_P2;
							end if;
							ball_x <= TO_SIGNED(626*8,14);
							ball_y <= player2_y;
							ball_vel_y <= player2_y(12 downto 6) - TO_SIGNED(30,10);
							ball_goal_p2<= '0';
							if(mouse2_left_button = '1' or ((player2_active = false) and (pause_ctr = 0))) then
								ball_vel_x <= TO_SIGNED(20,10);
								gamestate <= GAME_ON;
							end if;
						when GAME_WON_P1 =>
							score_p1_shade <= "1" & pause_ctr(5 downto 0) & "0";
							if pause_ctr = 0 then
								gamestate <= GAME_INIT;
							end if;
						when GAME_WON_P2 =>
							score_p2_shade <= "1" & pause_ctr(5 downto 0) & "0";
							if pause_ctr = 0 then
								gamestate <= GAME_INIT;
							end if;
						when GAME_INIT =>
							pause_ctr <= TO_UNSIGNED(120,10);
							if score_p2>score_p1 then
								gamestate <= GAME_SERVEP2;
							else
								gamestate <= GAME_SERVEP1;
							end if;
							clear_scores <= '1';
							score_p1_shade <= "11000000";
							score_p2_shade <= "11000000";
							player1_active <= false;
							player2_active <= false;
					end case;
				end if;
				
				if (currentX=3) and (currentY=0) then
					-- Detect collisions
					-- Left paddle:
					if(ball_x(13 downto 3)<11) and (abs(ball_y(13 downto 3)-player1_y(13 downto 3))<23) then
						ball_col_left <= '1';
					elsif (ball_x(13 downto 3)<2) then
						ball_goal_p2 <= '1';
						gamestate <= GAME_SERVEP2;
						pause_ctr <= TO_UNSIGNED(90,10);
					end if;

					-- Right paddle:
					if(ball_x(13 downto 3)>626) and (abs(ball_y(13 downto 3)-player2_y(13 downto 3))<23) then
						ball_col_right <= '1';
					elsif (ball_x(13 downto 3)>637) then 
						ball_goal_p1 <= '1';
						gamestate <= GAME_SERVEP1;
						pause_ctr <= TO_UNSIGNED(90,10);
					end if;
					
					-- Top and bottom edge...
					if(ball_y(13 downto 3)<2) then
						ball_col_top <= '1';
					end if;

					if (ball_y(13 downto 3)>477) then
						ball_col_bottom <= '1';
					end if;

				end if;
			

				bg := unsigned((currentX(5 downto 1) xor currentY(5 downto 1)) and "01000");
				wred <= bg & "000";
				wgrn <= currentY(10 downto 3);
				wblu <= currentY(10 downto 3) xor "00111111";

			-- Draw ball
				if (abs(x - ball_x(13 downto 3)) < 5) and (abs(y - ball_y(13 downto 3)) < 5) then
					wred <= (others => '1');
					wgrn <= (others => '1');
					wblu <= (others => '0');
				end if;

			-- Draw paddle 1
				if (currentX<10) and (abs(y - player1_y(13 downto 3)) < 25) then
					wred <= (others => '1');
					wgrn <= (others => '1');
					wblu <= (others => '1');
				end if;

			-- Draw paddle 2
				if (currentX>629) and (abs(y - player2_y(13 downto 3)) < 25) then
					wred <= (others => '1');
					wgrn <= (others => '1');
					wblu <= (others => '1');
				end if;
				
			-- Draw scores
				if drawdigit0 or drawdigit1 then
					wred <= score_p1_shade;
					wgrn <= score_p1_shade;
					wblu <= score_p1_shade;
				end if;
				if drawdigit2 or drawdigit3 then
					wred <= score_p2_shade;
					wgrn <= score_p2_shade;
					wblu <= score_p2_shade;
				end if;

			--
			-- Two pixel border at top and bottom of screen, and down the middle.
				if (currenty < 2) or (currenty>477) or ((currentX > 318) and (currentX<322)) then
					wred <= (others => '1');
					wgrn <= (others => '1');
					wblu <= (others => '1');
				end if;
			--
			-- Never draw pixels outside the visual area
				if (currentX >= 640) or (currentY >= 480) then
					wred <= (others => '0');
					wgrn <= (others => '0');
					wblu <= (others => '0');
				end if;
			end if;
		end if;
	end process;

end architecture;
