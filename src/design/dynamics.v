`timescale 1ns / 1ps

module dynamics(
    input clk, 
    input reset, 
    input load,
    input active, 
    input note_done, 
    input [2:0] meta, 
    input [15:0] sample_in, 
    output reg [15:0] sample_out, 
    output reg env_done
);

reg [2:0] state;
reg [11:0] env;

localparam IDLE = 3'd0;
localparam ATTACK = 3'd1;
localparam DECAY = 3'd2;
localparam SUSTAIN = 3'd3;
localparam RELEASE = 3'd4;

localparam [11:0] ATTACK_STEP = 12'd1024;
localparam [11:0] DECAY_STEP = 12'd256;
localparam [11:0] RELEASE_STEP = 12'd512;
localparam [11:0] SUSTAIN_LEVEL = 12'd3072;
localparam [11:0] ENV_MAX = 12'd4095;

wire signed [15:0] sample_in_signed = sample_in;
wire signed [27:0] scaled_sample =
    ($signed(sample_in_signed) * $signed({1'b0, env})) >>> 12;

always @(posedge clk) begin
    if (reset) begin
        state <= IDLE;
        env <= 12'd0;
        env_done <= 1'b0;
        sample_out <= 16'd0;
    end else begin
        env_done <= 1'b0;

        if (load) begin
            state <= ATTACK;
            env <= 12'd0;
        end else if (!active) begin
            state <= IDLE;
            env <= 12'd0;
        end else begin
            case (state)
                IDLE: begin
                    env <= 12'd0;
                    state <= ATTACK;
                end
                
                ATTACK: begin
                    if (note_done) begin
                        state <= RELEASE;
                    end else if (env + ATTACK_STEP >= ENV_MAX) begin
                        env <= ENV_MAX;
                        state <= DECAY;
                    end else begin
                        env <= env + ATTACK_STEP;
                    end
                end
                
                DECAY: begin
                    if (note_done) begin
                        state <= RELEASE;
                    end else if (env <= SUSTAIN_LEVEL + DECAY_STEP) begin
                        env <= SUSTAIN_LEVEL;
                        state <= SUSTAIN;
                    end else begin
                        env <= env - DECAY_STEP;
                    end
                end 
                
                SUSTAIN: begin
                    env <= SUSTAIN_LEVEL;
                    if (note_done) begin
                        state <= RELEASE;
                    end
                end
                
                RELEASE: begin
                    if (env <= RELEASE_STEP) begin
                        env <= 12'd0;
                        state <= IDLE;
                        env_done <= 1'b1;
                    end else begin
                        env <= env - RELEASE_STEP;
                    end
                end

                default: begin
                    state <= IDLE;
                    env <= 12'd0;
                end
            endcase
        end

        if (!active && !load) begin
            sample_out <= 16'd0;
        end else begin
            sample_out <= scaled_sample[15:0];
        end
    end
end

endmodule
