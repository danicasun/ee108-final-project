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
    parameter NUM_VOICES = 3,
    parameter SAMPLE_W = 16,
    parameter PHASE_W = 20
)(
    input clk,
    input reset,
    input [5:0] note_in,
    input [5:0] duration,
    input [2:0] meta,
    input gen_next,
    input tick48th,
    input schedule_note,
    output [15:0] out,
    output sample_ready,
    output reg [NUM_VOICES-1:0] voices_active,
    output reg [5:0] note0,
    output reg [5:0] note1,
    output reg [5:0] note2,
    output reg [NUM_VOICES-1:0] load_voice,
    output [NUM_VOICES*SAMPLE_W-1:0] voice_samples_packed
);
    reg [5:0] dur0, dur1, dur2;
    reg [2:0] meta0, meta1, meta2;

    wire [19:0] step0;
    wire [19:0] step1;
    wire [19:0] step2;

    frequency_rom freq0 (
        .clk(clk),
        .addr(note0),
        .dout(step0)
    );

    frequency_rom freq1 (
        .clk(clk),
        .addr(note1),
        .dout(step1)
    );

    frequency_rom freq2 (
        .clk(clk),
        .addr(note2),
        .dout(step2)
    );

    wire [SAMPLE_W-1:0] voice0, voice1, voice2;
    wire hr0, hr1, hr2;

    sine_reader s0 (
        .clk(clk),
        .reset(reset),
        .restart_phase(load_voice[0]),
        .step_size(step0),
        .generate_next(gen_next && voices_active[0]),
        .sample_ready(hr0),
        .sample(voice0)
    );

    sine_reader s1 (
        .clk(clk),
        .reset(reset),
        .restart_phase(load_voice[1]),
        .step_size(step1),
        .generate_next(gen_next && voices_active[1]),
        .sample_ready(hr1),
        .sample(voice1)
    );

    sine_reader s2 (
        .clk(clk),
        .reset(reset),
        .restart_phase(load_voice[2]),
        .step_size(step2),
        .generate_next(gen_next && voices_active[2]),
        .sample_ready(hr2),
        .sample(voice2)
    );

    wire note_done0 = tick48th && voices_active[0] && (dur0 == 6'd1);
    wire note_done1 = tick48th && voices_active[1] && (dur1 == 6'd1);
    wire note_done2 = tick48th && voices_active[2] && (dur2 == 6'd1);

    wire free0 = !voices_active[0] || note_done0;
    wire free1 = !voices_active[1] || note_done1;
    wire free2 = !voices_active[2] || note_done2;

    always @(posedge clk) begin
        if (reset) begin
            voices_active <= 3'b000;
            load_voice <= 3'b000;

            note0 <= 0;
            note1 <= 0;
            note2 <= 0;
            dur0 <= 0;
            dur1 <= 0;
            dur2 <= 0;
            meta0 <= 0;
            meta1 <= 0;
            meta2 <= 0;
        end else begin
            load_voice <= 3'b000;

            if (tick48th) begin
                if (voices_active[0] && dur0 != 0) dur0 <= dur0 - 1'b1;
                if (voices_active[1] && dur1 != 0) dur1 <= dur1 - 1'b1;
                if (voices_active[2] && dur2 != 0) dur2 <= dur2 - 1'b1;
            end

            if (note_done0) begin
                voices_active[0] <= 1'b0;
                dur0 <= 6'd0;
            end

            if (note_done1) begin
                voices_active[1] <= 1'b0;
                dur1 <= 6'd0;
            end

            if (note_done2) begin
                voices_active[2] <= 1'b0;
                dur2 <= 6'd0;
            end

            if (schedule_note) begin
                if (free0) begin
                    note0 <= note_in;
                    dur0 <= duration;
                    meta0 <= meta;
                    voices_active[0] <= 1'b1;
                    load_voice[0] <= 1'b1;
                end else if (free1) begin
                    note1 <= note_in;
                    dur1 <= duration;
                    meta1 <= meta;
                    voices_active[1] <= 1'b1;
                    load_voice[1] <= 1'b1;
                end else if (free2) begin
                    note2 <= note_in;
                    dur2 <= duration;
                    meta2 <= meta;
                    voices_active[2] <= 1'b1;
                    load_voice[2] <= 1'b1;
                end
            end
        end
    end

    wire signed [15:0] voice0_signed = voice0;
    wire signed [15:0] voice1_signed = voice1;
    wire signed [15:0] voice2_signed = voice2;
    wire signed [17:0] mix_sum =
        (voices_active[0] ? {{2{voice0_signed[15]}}, voice0_signed} : 18'sd0) +
        (voices_active[1] ? {{2{voice1_signed[15]}}, voice1_signed} : 18'sd0) +
        (voices_active[2] ? {{2{voice2_signed[15]}}, voice2_signed} : 18'sd0);
    wire [2:0] active_voice_count =
        voices_active[0] + voices_active[1] + voices_active[2];
    reg signed [17:0] mix_avg;
    wire any_voice_active = |voices_active;
    wire active_voice_ready =
        (voices_active[0] ? hr0 : 1'b1) &
        (voices_active[1] ? hr1 : 1'b1) &
        (voices_active[2] ? hr2 : 1'b1);

    always @(*) begin
        case (active_voice_count)
            3'd0: mix_avg = 18'sd0;
            3'd1: mix_avg = mix_sum;
            3'd2: mix_avg = mix_sum >>> 1;
            default: mix_avg = mix_sum / 18'sd3;
        endcase
    end

    assign out = reset ? 16'd0 : mix_avg[15:0];
    assign sample_ready = any_voice_active ? active_voice_ready : gen_next;
    assign voice_samples_packed = {voice2, voice1, voice0};

endmodule
