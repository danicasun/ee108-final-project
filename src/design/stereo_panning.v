`timescale 1ns / 1ps 

module stereo_panning #(
    parameter SAMPLE_W = 16, 
    parameter PAN_W = 3
)(
    input clk, 
    input reset, 
    input active, 
    input sample_tick, 
    input signed [SAMPLE_W-1:0] sample_in, 
    input [PAN_W-1:0] pan,
    output reg signed [SAMPLE_W-1:0] left_sample, 
    output reg signed [SAMPLE_W-1:0] right_sample
);

    localparam [PAN_W-1:0] PAN_MAX = {PAN_W{1'b1}};
    localparam ACC_W = SAMPLE_W + PAN_W + 2;
    
    reg [PAN_W-1:0] left_gain;
    reg [PAN_W-1:0] right_gain;
    reg signed [ACC_W-1:0] right_scaled;
    reg signed [ACC_W-1:0] left_scaled;
    
    always @(*) begin
        left_gain = PAN_MAX - pan;
        right_gain = pan;
        
        left_scaled = ($signed(sample_in)) * ($signed({1'b0, left_gain})) >>> PAN_W;
        right_scaled = ($signed(sample_in)) * ($signed({1'b0, right_gain})) >>> PAN_W;
    end
    
    always @(posedge clk) begin
        if (reset) begin
            left_sample <= 0;
            right_sample <= 0;
        end else if (sample_tick) begin
            if(!active) begin
                left_sample <= 0;
                right_sample <= 0;
            end else begin
                left_sample <= left_scaled[SAMPLE_W-1:0];
                right_sample <= right_scaled[SAMPLE_W-1:0];
            end
        end
    end

endmodule;