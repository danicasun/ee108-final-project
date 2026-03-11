`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10.03.2026 21:16:36
// Design Name: 
// Module Name: multi_voice_player
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


module multi_voice_player#(
    parameter NUM_VOICES = 4
)(
    input clk, 
    input reset,
    input [5:0] note_in,
    input [5:0] duration, 
    input [2:0] meta,
    output reg [15:0] out, 
    output reg [NUM_VOICES-1:0] voice_active,
    output reg [NUM_VOICES-1:0] load_voice
);

    //call sine 
    
    //scale each sine w/ dynamic module
    //sum together samples && out

endmodule
