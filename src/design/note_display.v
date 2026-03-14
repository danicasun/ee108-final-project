`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:
// Engineer:
//
// Create Date: 
// Design Name:
// Module Name: note_display
// Project Name:
// Target Devices:
// Tool Versions:
// Description:
//
// Dependencies:
//   note_to_ascii
//   ascii_to_pixel
//
//////////////////////////////////////////////////////////////////////////////////

module note_display(
    input clk,
    input reset,

    input [10:0] x,
    input [9:0]  y,
    input valid,

    input [3:0] voices_active, // bit i says whether voice i is active

    input [5:0] voice_note0,
    input [5:0] voice_note1,
    input [5:0] voice_note2,
    input [5:0] voice_note3,

    input       preview_valid,
    input [5:0] preview_note,
    input [5:0] preview_duration,
    input [2:0] preview_meta,

    output valid_pixel,
    output [7:0] r,
    output [7:0] g,
    output [7:0] b
);

    // Text placement constants
    localparam [10:0] TEXT_X0   = 11'd120;
    localparam [9:0]  TEXT_Y0   = 10'd60;

    localparam [10:0] CHAR_W    = 11'd8;
    localparam [9:0]  CHAR_H    = 10'd8;
    localparam [9:0]  LINE_SP   = 10'd12;   // 8 pixels glyph + 4 pixels gap

    localparam [1:0]  NUM_LINES = 2'd4;
    localparam [3:0]  LINE_LEN  = 4'd7;     // "V0: 5A " => 7 chars

    // silence unused-input warnings for checkpoint 1
    wire _unused_preview = preview_valid ^ preview_note[0] ^ preview_duration[0] ^ preview_meta[0] ^ clk ^ reset;

    // convert notes to ASCII strings
    wire [23:0] ascii0, ascii1, ascii2, ascii3;

    note_to_ascii n0(.note(voice_note0), .ascii(ascii0));
    note_to_ascii n1(.note(voice_note1), .ascii(ascii1));
    note_to_ascii n2(.note(voice_note2), .ascii(ascii2));
    note_to_ascii n3(.note(voice_note3), .ascii(ascii3));

    wire [23:0] blank_note = {"-","-"," "};

    wire [23:0] disp0 = voices_active[0] ? ascii0 : blank_note;
    wire [23:0] disp1 = voices_active[1] ? ascii1 : blank_note;
    wire [23:0] disp2 = voices_active[2] ? ascii2 : blank_note;
    wire [23:0] disp3 = voices_active[3] ? ascii3 : blank_note;

    // bounding box for the text
    wire in_text_box =
        valid &&
        (x >= TEXT_X0) &&
        (x <  (TEXT_X0 + LINE_LEN*CHAR_W)) &&
        (y >= TEXT_Y0) &&
        (y <  (TEXT_Y0 + NUM_LINES*LINE_SP));

    wire [10:0] rel_x = x - TEXT_X0;
    wire [9:0]  rel_y = y - TEXT_Y0;

    // figure out which line, which character, and where inside the 8x8
    wire [2:0] glyph_col = rel_x[2:0];   // rel_x % 8
    wire [2:0] char_idx  = rel_x[10:3];  // rel_x / 8

    wire [1:0] line_idx = rel_y / LINE_SP;
    wire [3:0] line_y_in_band = rel_y % LINE_SP;
    wire       in_glyph_band = (line_y_in_band < CHAR_H);
    wire [2:0] glyph_row = line_y_in_band[2:0];

    // choose the 3 char note string for the selected line
    reg [23:0] line_note_ascii;

    always @(*) begin
        case (line_idx)
            2'd0: line_note_ascii = disp0;
            2'd1: line_note_ascii = disp1;
            2'd2: line_note_ascii = disp2;
            2'd3: line_note_ascii = disp3;
            default: line_note_ascii = {" "," "," "};
        endcase
    end

    // build each displayed line as:
    //   char 0 = 'V'
    //   char 1 = line number
    //   char 2 = ':'
    //   char 3 = ' '
    //   char 4 = note char 1
    //   char 5 = note char 2
    //   char 6 = note char 3
    reg [7:0] ascii_char;

    always @(*) begin
        case (char_idx)
            3'd0: ascii_char = "V";
            3'd1: ascii_char = "0" + {6'd0, line_idx};
            3'd2: ascii_char = ":";
            3'd3: ascii_char = " ";
            3'd4: ascii_char = line_note_ascii[23:16];
            3'd5: ascii_char = line_note_ascii[15:8];
            3'd6: ascii_char = line_note_ascii[7:0];
            default: ascii_char = " ";
        endcase
    end

    // convert ASCII to a pixel
    wire char_pixel_on;

    ascii_to_pixel atp(
        .ascii_char(ascii_char),
        .glyph_row(glyph_row),
        .glyph_col(glyph_col),
        .pixel_on(char_pixel_on)
    );

    // final output pixels
    wire draw_text_pixel =
        in_text_box &&
        in_glyph_band &&
        (char_idx < LINE_LEN) &&
        char_pixel_on;

    assign valid_pixel = draw_text_pixel;

    assign r = draw_text_pixel ? 8'hFF : 8'h00;
    assign g = draw_text_pixel ? 8'hFF : 8'h00;
    assign b = draw_text_pixel ? 8'hFF : 8'h00;

endmodule
