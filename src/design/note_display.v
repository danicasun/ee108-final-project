`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 13.03.2026 20:42:41
// Design Name: 
// Module Name: note_display
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

module note_display(
    input clk,
    input reset,

    input [10:0] x,
    input [9:0]  y,
    input valid,

    input [3:0] voices_active, // index matches to voice index

    input [5:0] voice_note0,
    input [5:0] voice_note1,
    input [5:0] voice_note2,
    input [5:0] voice_note3,

    output valid_pixel,
    output [7:0] r,
    output [7:0] g,
    output [7:0] b
);

// if voices_active[X] is active, convert voice_noteX to ASCII and display it 
// use the spreadhseet as refernece, case statement mapping each note value to the ASCII representation 

// convert the ASCII to pixels to display on the screen, is there a libaryr I can use for this?
// understand deeply how wave display works


endmodule
