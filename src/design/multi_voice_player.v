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
    parameter NUM_VOICES = 4, 
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
    output reg [5:0] note3,
    output reg [NUM_VOICES-1:0] load_voice,
    output [NUM_VOICES*SAMPLE_W-1:0] voice_samples_packed
);
    reg [5:0] dur0, dur1, dur2, dur3;
    reg [2:0] meta0, meta1, meta2, meta3;
    
    //steps
    wire [19:0] step0;
    wire [19:0] step1;
    wire [19:0] step2;
    wire [19:0] step3;

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

    frequency_rom freq3 (
        .clk(clk),
        .addr(note3),
        .dout(step3)
    );
    
    wire [SAMPLE_W-1:0] harm0, harm1, harm2, harm3;
    wire hr0, hr1, hr2, hr3;

    //instantiate the harmonics
    harmonics #(.PHASE_W(20), .SAMPLE_W(16), .W_SHIFT(5)) h0 (
        .clk(clk), 
        .reset(reset), 
        .restart_phase(load_voice[0]),
        .active(voices_active[0]),
        .gen_next(gen_next), 
        .step_size(step0), 
        .meta(meta0),
        .sample(harm0), 
        .sample_ready(hr0)
    );
    
     harmonics #(.PHASE_W(20), .SAMPLE_W(16), .W_SHIFT(5)) h1 (
        .clk(clk), 
        .reset(reset), 
        .restart_phase(load_voice[1]),
        .active(voices_active[1]),
        .gen_next(gen_next), 
        .step_size(step1), 
        .meta(meta1),
        .sample(harm1), 
        .sample_ready(hr1)
    );
    
     harmonics #(.PHASE_W(20), .SAMPLE_W(16), .W_SHIFT(5)) h2 (
        .clk(clk), 
        .reset(reset), 
        .restart_phase(load_voice[2]),
        .active(voices_active[2]),
        .gen_next(gen_next), 
        .step_size(step2), 
        .meta(meta2),
        .sample(harm2), 
        .sample_ready(hr2)
    );
    
     harmonics #(.PHASE_W(20), .SAMPLE_W(16), .W_SHIFT(5)) h3 (
        .clk(clk), 
        .reset(reset), 
        .restart_phase(load_voice[3]),
        .active(voices_active[3]),
        .gen_next(gen_next), 
        .step_size(step3), 
        .meta(meta3),
        .sample(harm3), 
        .sample_ready(hr3)
    );
    
    wire note_done0 = tick48th && voices_active[0] && (dur0 == 6'd1);
    wire note_done1 = tick48th && voices_active[1] && (dur1 == 6'd1);
    wire note_done2 = tick48th && voices_active[2] && (dur2 == 6'd1);
    wire note_done3 = tick48th && voices_active[3] && (dur3 == 6'd1);
    
    wire [15:0] dyn0, dyn1, dyn2, dyn3;
    wire envdone0, envdone1, envdone2, envdone3;

    //scale w/ dynamic module
    dynamics d0 (
        .clk(clk), 
        .reset(reset), 
        .load(load_voice[0]), 
        .sample_tick(hr0),
        .active(voices_active[0]), 
        .note_done(note_done0), 
        .meta(meta0), 
        .sample_in(harm0), 
        .sample_out(dyn0), 
        .env_done(envdone0)
    );
    
    dynamics d1 (
        .clk(clk), 
        .reset(reset), 
        .load(load_voice[1]), 
        .sample_tick(hr1),
        .active(voices_active[1]), 
        .note_done(note_done1), 
        .meta(meta1), 
        .sample_in(harm1), 
        .sample_out(dyn1), 
        .env_done(envdone1)
    );
    
    dynamics d2 (
        .clk(clk), 
        .reset(reset), 
        .load(load_voice[2]), 
        .sample_tick(hr2),
        .active(voices_active[2]), 
        .note_done(note_done2), 
        .meta(meta2), 
        .sample_in(harm2), 
        .sample_out(dyn2), 
        .env_done(envdone2)
    );
    
    dynamics d3 (
        .clk(clk), 
        .reset(reset), 
        .load(load_voice[3]), 
        .sample_tick(hr3),
        .active(voices_active[3]), 
        .note_done(note_done3), 
        .meta(meta3), 
        .sample_in(harm3), 
        .sample_out(dyn3), 
        .env_done(envdone3)
    );
    
    //sum together samples && out
    wire free0 = !voices_active[0] || envdone0;
    wire free1 = !voices_active[1] || envdone1;
    wire free2 = !voices_active[2] || envdone2;
    wire free3 = !voices_active[3] || envdone3;
    
    //voice allocation
    always @(posedge clk) begin
        if (reset) begin
            voices_active <= 4'b0000;
            load_voice <= 4'b0000;
            
            note0 <= 0; note1 <= 0; note2 <= 0; note3 <= 0;
            dur0 <= 0; dur1 <= 0; dur2 <= 0; dur3 <= 0;
            meta0 <= 0; meta1 <= 0; meta2 <= 0; meta3 <= 0;
        end else begin
            load_voice <= 4'b0000;
            
            if (tick48th) begin
                if (voices_active[0] && dur0 != 0) dur0 <= dur0 - 1'b1;
                if (voices_active[1] && dur1 != 0) dur1 <= dur1 - 1'b1;
                if (voices_active[2] && dur2 != 0) dur2 <= dur2 - 1'b1;
                if (voices_active[3] && dur3 != 0) dur3 <= dur3 - 1'b1;
            end
            
            if (envdone0) begin
                voices_active[0] <= 1'b0;
                dur0 <= 6'd0;
            end
            
            if (envdone1) begin
                voices_active[1] <= 1'b0;
                dur1 <= 6'd0;
            end
            
            if (envdone2) begin
                voices_active[2] <= 1'b0;
                dur2 <= 6'd0;
            end
            
            if (envdone3) begin
                voices_active[3] <= 1'b0;
                dur3 <= 6'd0;
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
                end else if (free3) begin
                    note3 <= note_in;
                    dur3 <= duration;
                    meta3 <= meta;
                    voices_active[3] <= 1'b1;
                    load_voice[3] <= 1'b1;
                end
            end
        end
    end
    
    //mix the sum
    wire signed [15:0] dyn0_signed = dyn0;
    wire signed [15:0] dyn1_signed = dyn1;
    wire signed [15:0] dyn2_signed = dyn2;
    wire signed [15:0] dyn3_signed = dyn3;
    wire signed [17:0] mix_sum = 
     (voices_active[0] ? {{2{dyn0_signed[15]}}, dyn0_signed} : 18'sd0) + 
     (voices_active[1] ? {{2{dyn1_signed[15]}}, dyn1_signed} : 18'sd0) + 
     (voices_active[2] ? {{2{dyn2_signed[15]}}, dyn2_signed} : 18'sd0) + 
     (voices_active[3] ? {{2{dyn3_signed[15]}}, dyn3_signed} : 18'sd0);
    wire signed [17:0] mix_avg = mix_sum >>> 2;
    wire any_voice_active = |voices_active;
    wire active_voice_ready =
        (voices_active[0] ? hr0 : 1'b1) &
        (voices_active[1] ? hr1 : 1'b1) &
        (voices_active[2] ? hr2 : 1'b1) &
        (voices_active[3] ? hr3 : 1'b1);
    
    assign out = reset ? 16'd0 : mix_avg[15:0];
    assign sample_ready = any_voice_active ? active_voice_ready : gen_next;
    assign voice_samples_packed = {dyn3, dyn2, dyn1, dyn0};

endmodule
