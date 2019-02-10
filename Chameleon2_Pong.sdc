
#set_time_format -unit ns -decimal_places 3

#create_clock -name {clk8} -period 125.000 -waveform { 0.000 62.500 } [get_ports {clk8}]
#create_clock -name {video_vga_master:myVgaMaster|newPixel} -period 40.000 -waveform { 0.000 0.500 } [get_registers {video_vga_master:myVgaMaster|newPixel}]
#create_clock -name {video_vga_master:myVgaMaster|vSync} -period 16666.000 -waveform { 0.000 0.500 } [get_registers {video_vga_master:myVgaMaster|vSync}]
#create_clock -name {usart_clk} -period 125.000 -waveform { 0.000 0.500 } [get_ports {usart_clk}]

#create_generated_clock -name {pllInstance|altpll_component|auto_generated|pll1|clk[0]} -source [get_pins {pllInstance|altpll_component|auto_generated|pll1|inclk[0]}] -duty_cycle 50.000 -multiply_by 25 -divide_by 2 -master_clock {clk8} [get_pins {pllInstance|altpll_component|auto_generated|pll1|clk[0]}] 
#create_generated_clock -name {pllInstance|altpll_component|auto_generated|pll1|clk[3]} -source [get_pins {pllInstance|altpll_component|auto_generated|pll1|inclk[0]}] -duty_cycle 50.000 -multiply_by 75 -divide_by 4 -phase 180.000 -master_clock {clk8} [get_pins {pllInstance|altpll_component|auto_generated|pll1|clk[3]}] 



set_time_format -unit ns -decimal_places 3
create_clock -period 20.000 [get_ports {clk50m}]
derive_pll_clocks
derive_clock_uncertainty

create_generated_clock -name ram_clk_pin -source [get_pins {\pll_blk:pll_inst|altpll_component|auto_generated|pll1|clk[3]}] [get_ports {ram_clk}]

create_clock -name {video_vga_master:myVgaMaster|newPixel} -period 40.000 -waveform { 0.000 0.500 } [get_registers {video_vga_master:myVgaMaster|newPixel}]
create_clock -name {video_vga_master:myVgaMaster|vSync} -period 16666.000 -waveform { 0.000 0.500 } [get_registers {video_vga_master:myVgaMaster|vSync}]
create_clock -name {usart_clk} -period 125.000 -waveform { 0.000 0.500 } [get_ports {usart_clk}]
#create_generated_clock -name {pllInstance|altpll_component|auto_generated|pll1|clk[0]} -source [get_pins {pllInstance|altpll_component|auto_generated|pll1|inclk[0]}] -duty_cycle 50.000 -multiply_by 25 -divide_by 2 -master_clock {clk50m} [get_pins {pllInstance|altpll_component|auto_generated|pll1|clk[0]}] 
#create_generated_clock -name {pllInstance|altpll_component|auto_generated|pll1|clk[3]} -source [get_pins {pllInstance|altpll_component|auto_generated|pll1|inclk[0]}] -duty_cycle 50.000 -multiply_by 75 -divide_by 4 -phase 180.000 -master_clock {clk50m} [get_pins {pllInstance|altpll_component|auto_generated|pll1|clk[3]}] 

#set_output_delay -clock {\pll_blk:pll_inst|altpll_component|auto_generated|pll1|clk[3]} 0.000 ram_clk
set_output_delay -clock ram_clk_pin -max  1.000 ram_a[*]
set_output_delay -clock ram_clk_pin -min -1.000 ram_a[*]

set_output_delay -clock ram_clk_pin -max  1.000 ram_we
set_output_delay -clock ram_clk_pin -min -1.000 ram_we

set_output_delay -clock ram_clk_pin -max  1.000 ram_ras
set_output_delay -clock ram_clk_pin -min -1.000 ram_ras

set_output_delay -clock ram_clk_pin -max  1.000 ram_cas
set_output_delay -clock ram_clk_pin -min -1.000 ram_cas

set_output_delay -clock ram_clk_pin -max  1.000 ram_ba[*]
set_output_delay -clock ram_clk_pin -min -1.000 ram_ba[*]

set_output_delay -clock ram_clk_pin -max  1.000 ram_ldqm
set_output_delay -clock ram_clk_pin -min -1.000 ram_ldqm

set_output_delay -clock ram_clk_pin -max  1.000 ram_udqm
set_output_delay -clock ram_clk_pin -min -1.000 ram_udqm

set_output_delay -clock ram_clk_pin -max  1.000 ram_d[*]
set_output_delay -clock ram_clk_pin -min -1.000 ram_d[*]

set_input_delay -clock ram_clk_pin -min 1.500 ram_d[*]
set_input_delay -clock ram_clk_pin -max 3.000 ram_d[*]

set_multicycle_path -from [get_clocks {ram_clk_pin}] -to [get_clocks {\pll_blk:pll_inst|altpll_component|auto_generated|pll1|clk[2]}] -setup -end 2
