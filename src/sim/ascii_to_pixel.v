`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 14.03.2026 05:26:58
// Design Name: 
// Module Name: ascii_to_pixel
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module ascii_to_pixel(
    input  [7:0] ascii_char,
    input  [2:0] glyph_row,
    input  [2:0] glyph_col,
    output       pixel_on
);

    reg  [5:0] font_char_idx;
    wire [7:0] row_bits;
    wire [8:0] rom_addr;

    // map asciii to tcgrom character index
    always @(*) begin
        case (ascii_char)
            " ": font_char_idx = 6'd32; // space
            "!": font_char_idx = 6'd33;
            "#": font_char_idx = 6'd35;
            "-": font_char_idx = 6'd45;
            ":": font_char_idx = 6'd58;

            "0": font_char_idx = 6'd48;
            "1": font_char_idx = 6'd49;
            "2": font_char_idx = 6'd50;
            "3": font_char_idx = 6'd51;
            "4": font_char_idx = 6'd52;
            "5": font_char_idx = 6'd53;
            "6": font_char_idx = 6'd54;
            "7": font_char_idx = 6'd55;
            "8": font_char_idx = 6'd56;
            "9": font_char_idx = 6'd57;

            "A": font_char_idx = 6'd65;
            "B": font_char_idx = 6'd66;
            "C": font_char_idx = 6'd67;
            "D": font_char_idx = 6'd68;
            "E": font_char_idx = 6'd69;
            "F": font_char_idx = 6'd70;
            "G": font_char_idx = 6'd71;
            "V": font_char_idx = 6'd86;

            default: font_char_idx = 6'd32; // if unknown, use space
        endcase
    end

    assign rom_addr = {font_char_idx, glyph_row};

    tcgrom font_rom (
        .addr(rom_addr),
        .data(row_bits)
    );

    assign pixel_on = row_bits[7 - glyph_col];

endmodule
