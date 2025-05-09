/*
 * Avalon memory-mapped peripheral that generates VGA
 *
 * Stephen A. Edwards
 * Columbia University
 *
 * Register map:
 * 
 * Byte Offset  7 ... 0   Meaning
 *        0    |  Red  |  Red component of background color (0-255)
 *        1    | Green |  Green component
 *        2    | Blue  |  Blue component
 *        3    |  ---  |  Unused
 *        4    | x LSB |  X coordinate of ball (least significant byte)
 *        5    | x MSB |  X coordinate of ball (most significant byte)
 *        6    | y LSB |  Y coordinate of ball (least significant byte)
 *        7    | y MSB |  Y coordinate of ball (most significant byte)
 */

module vga_ball (
    input logic       clk,
    input logic       reset,
    input logic [7:0] writedata,
    input logic       write,
    input             chipselect,
    input logic [2:0] address,

    output logic [7:0] VGA_R,
    VGA_G,
    VGA_B,
    output logic       VGA_CLK,
    VGA_HS,
    VGA_VS,
    VGA_BLANK_n,
    output logic       VGA_SYNC_n
);

	logic [10:0] hcount;
	logic [ 9:0] vcount;

	logic [7:0] background_r, background_g, background_b;
	logic [15:0] x, y;
	logic [9:0] r;

  logic [11:0] vga_x;
  logic [11:0] vga_y;
  logic [11:0] pos_x;
  logic [11:0] pos_y;
  logic [11:0] dx;
  logic [11:0] dy;
  logic [23:0] dist_sq;

	vga_counters counters (
		.clk50(clk),
		.*
	);

	always_ff @(posedge clk)
		if (reset) begin
		background_r <= 8'h0;
		background_g <= 8'h80;
		background_b <= 8'h80;
		x <= 16'h0;
		y <= 16'h0;
		end else if (chipselect && write)
		case (address)
			3'h0: background_r <= writedata;
			3'h1: background_g <= writedata;
			3'h2: background_b <= writedata;
			3'h4: x[7:0] <= writedata;
			3'h5: x[15:8] <= writedata;
			3'h6: y[7:0] <= writedata;
			3'h7: y[15:8] <= writedata;
		endcase

	always_comb begin
    r = 10'd256; // radius^2 = 16^2

    vga_x = hcount[10:1];
    vga_y = vcount[9:0];
    pos_x = x[15:6];
    pos_y = y[15:6];
		dx = (vga_x > pos_x) ? (vga_x - pos_x) : (pos_x - vga_x);
		dy = (vga_y > pos_y) ? (vga_y - pos_y) : (pos_y - vga_y);
		dist_sq = dx * dx + dy * dy;

		if (dist_sq < r)
			{VGA_R, VGA_G, VGA_B} = 24'hffffff;
		else
			{VGA_R, VGA_G, VGA_B} = {background_r, background_g, background_b};
	end

endmodule

module vga_counters (
    input  logic        clk50,
    reset,
    output logic [10:0] hcount,  // hcount[10:1] is pixel column
    output logic [ 9:0] vcount,  // vcount[9:0] is pixel row
    output logic        VGA_CLK,
    VGA_HS,
    VGA_VS,
    VGA_BLANK_n,
    VGA_SYNC_n
);

  /*
 * 640 X 480 VGA timing for a 50 MHz clock: one pixel every other cycle
 * 
 * HCOUNT 1599 0             1279       1599 0
 *             _______________              ________
 * ___________|    Video      |____________|  Video
 * 
 * 
 * |SYNC| BP |<-- HACTIVE -->|FP|SYNC| BP |<-- HACTIVE
 *       _______________________      _____________
 * |____|       VGA_HS          |____|
 */
  // Parameters for hcount
  parameter HACTIVE      = 11'd 1280,
             HFRONT_PORCH = 11'd 32,
             HSYNC        = 11'd 192,
             HBACK_PORCH  = 11'd 96,   
             HTOTAL       = HACTIVE + HFRONT_PORCH + HSYNC +
                            HBACK_PORCH; // 1600

  // Parameters for vcount
  parameter VACTIVE      = 10'd 480,
             VFRONT_PORCH = 10'd 10,
             VSYNC        = 10'd 2,
             VBACK_PORCH  = 10'd 33,
             VTOTAL       = VACTIVE + VFRONT_PORCH + VSYNC +
                            VBACK_PORCH; // 525

  logic endOfLine;

  always_ff @(posedge clk50 or posedge reset)
    if (reset) hcount <= 0;
    else if (endOfLine) hcount <= 0;
    else hcount <= hcount + 11'd1;

  assign endOfLine = hcount == HTOTAL - 1;

  logic endOfField;

  always_ff @(posedge clk50 or posedge reset)
    if (reset) vcount <= 0;
    else if (endOfLine)
      if (endOfField) vcount <= 0;
      else vcount <= vcount + 10'd1;

  assign endOfField = vcount == VTOTAL - 1;

  // Horizontal sync: from 0x520 to 0x5DF (0x57F)
  // 101 0010 0000 to 101 1101 1111
  assign VGA_HS = !((hcount[10:8] == 3'b101) & !(hcount[7:5] == 3'b111));
  assign VGA_VS = !(vcount[9:1] == (VACTIVE + VFRONT_PORCH) / 2);

  assign VGA_SYNC_n = 1'b0;  // For putting sync on the green signal; unused

  // Horizontal active: 0 to 1279     Vertical active: 0 to 479
  // 101 0000 0000  1280	       01 1110 0000  480
  // 110 0011 1111  1599	       10 0000 1100  524
  assign VGA_BLANK_n = !( hcount[10] & (hcount[9] | hcount[8]) ) &
			!( vcount[9] | (vcount[8:5] == 4'b1111) );

  /* VGA_CLK is 25 MHz
    *             __    __    __
    * clk50    __|  |__|  |__|
    *        
    *             _____       __
    * hcount[0]__|     |_____|
    */
  assign VGA_CLK = hcount[0];  // 25 MHz clock: rising edge sensitive

endmodule
