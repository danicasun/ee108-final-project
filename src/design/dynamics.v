`timescale 1ns / 1ps

module dynamics(
    input clk, 
    input reset, 
    input load,
    input sample_tick,
    input active, 
    input note_done, 
    input [2:0] meta, 
    input [15:0] sample_in, 
    output reg [15:0] sample_out, 
    output reg env_done
);

reg [2:0] state;
reg [11:0] env;
reg release_pending;

parameter IDLE = 3'd0;
parameter ATTACK = 3'd1;
parameter DECAY = 3'd2;
parameter SUSTAIN = 3'd3;
parameter RELEASE = 3'd4;

parameter [11:0] ATTACK_STEP = 12'd1024;
parameter [11:0] DECAY_STEP = 12'd256;
parameter [11:0] RELEASE_STEP = 12'd512;
parameter [11:0] SUSTAIN_LEVEL = 12'd3072;
parameter [11:0] ENV_MAX = 12'd4095;

reg [11:0] attack_step_sel;
reg [11:0] decay_step_sel;
reg [11:0] release_step_sel;
reg [11:0] sustain_level_sel;

wire signed [15:0] sample_in_signed = sample_in;
wire signed [27:0] scaled_sample =
    ($signed(sample_in_signed) * $signed({1'b0, env})) >>> 12;

always @(*) begin
    case (meta)
        3'b000: begin
            attack_step_sel = ATTACK_STEP;
            decay_step_sel = DECAY_STEP;
            release_step_sel = RELEASE_STEP;
            sustain_level_sel = SUSTAIN_LEVEL;
        end
        3'b001: begin
            attack_step_sel = 12'd512;
            decay_step_sel = 12'd128;
            release_step_sel = 12'd256;
            sustain_level_sel = 12'd3328;
        end
        3'b010: begin
            attack_step_sel = 12'd256;
            decay_step_sel = 12'd128;
            release_step_sel = 12'd192;
            sustain_level_sel = 12'd2816;
        end
        3'b011: begin
            attack_step_sel = 12'd2048;
            decay_step_sel = 12'd384;
            release_step_sel = 12'd768;
            sustain_level_sel = 12'd2304;
        end
        3'b100: begin
            attack_step_sel = 12'd128;
            decay_step_sel = 12'd64;
            release_step_sel = 12'd96;
            sustain_level_sel = 12'd3584;
        end
        3'b101: begin
            attack_step_sel = 12'd64;
            decay_step_sel = 12'd32;
            release_step_sel = 12'd64;
            sustain_level_sel = 12'd2048;
        end
        3'b110: begin
            attack_step_sel = 12'd1536;
            decay_step_sel = 12'd192;
            release_step_sel = 12'd384;
            sustain_level_sel = 12'd2560;
        end
        3'b111: begin
            attack_step_sel = 12'd768;
            decay_step_sel = 12'd96;
            release_step_sel = 12'd128;
            sustain_level_sel = 12'd3200;
        end
        default: begin
            attack_step_sel = ATTACK_STEP;
            decay_step_sel = DECAY_STEP;
            release_step_sel = RELEASE_STEP;
            sustain_level_sel = SUSTAIN_LEVEL;
        end
    endcase
end

always @(posedge clk) begin
    if (reset) begin
        state <= IDLE;
        env <= 12'd0;
        env_done <= 1'b0;
        sample_out <= 16'd0;
        release_pending <= 1'b0;
    end else begin
        env_done <= 1'b0;

        if (load) begin
            state <= ATTACK;
            env <= 12'd0;
            sample_out <= 16'd0;
            release_pending <= 1'b0;
        end else if (!active) begin
            state <= IDLE;
            env <= 12'd0;
            sample_out <= 16'd0;
            release_pending <= 1'b0;
        end else begin
            if (note_done) begin
                release_pending <= 1'b1;
            end

            if (sample_tick) begin
                case (state)
                    IDLE: begin
                        env <= 12'd0;
                        state <= IDLE;
                    end

                    ATTACK: begin
                        if (release_pending || note_done) begin
                            state <= RELEASE;
                            release_pending <= 1'b0;
                        end else if (env >= (ENV_MAX - attack_step_sel)) begin
                            env <= ENV_MAX;
                            state <= DECAY;
                        end else begin
                            env <= env + attack_step_sel;
                        end
                    end

                    DECAY: begin
                        if (release_pending || note_done) begin
                            state <= RELEASE;
                            release_pending <= 1'b0;
                        end else if (env <= sustain_level_sel + decay_step_sel) begin
                            env <= sustain_level_sel;
                            state <= SUSTAIN;
                        end else begin
                            env <= env - decay_step_sel;
                        end
                    end 

                    SUSTAIN: begin
                        env <= sustain_level_sel;
                        if (release_pending || note_done) begin
                            state <= RELEASE;
                            release_pending <= 1'b0;
                        end
                    end

                    RELEASE: begin
                        release_pending <= 1'b0;
                        if (env <= release_step_sel) begin
                            env <= 12'd0;
                            state <= IDLE;
                            env_done <= 1'b1;
                        end else begin
                            env <= env - release_step_sel;
                        end
                    end

                    default: begin
                        state <= IDLE;
                        env <= 12'd0;
                        release_pending <= 1'b0;
                    end
                endcase

                sample_out <= scaled_sample[15:0];
            end
        end
    end
end

endmodule
