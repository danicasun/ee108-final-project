`timescale 1ns / 1ps

module voice_allocator #(
    parameter NUM_VOICES = 4 // how many does our FPGA limit us to??
)(
    input clk,
    input reset,

    // note from song_reader
    input valid,
    input [5:0] note,
    input [5:0] duration,
    input [2:0] meta,

    // voice status from & outputs to multi_voice_player
    input [NUM_VOICES-1:0] voice_active,

    output reg [NUM_VOICES-1:0] load_voice,
    output reg [5:0] note_out,
    output reg [5:0] duration_out,
    output reg [2:0] meta_out
);


endmodule
