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
reg [15:0] stage_count;
reg [11:0] release_start_env;

parameter IDLE = 3'd0;
parameter ATTACK = 3'd1;
parameter DECAY = 3'd2;
parameter SUSTAIN = 3'd3;
parameter RELEASE = 3'd4;

parameter [11:0] ENV_MAX = 12'd4095;

reg [15:0] attack_len_sel;
reg [15:0] decay_len_sel;
reg [15:0] release_len_sel;
reg [11:0] sustain_level_sel;
reg [27:0] env_interp;
wire bypass_env = (meta == 3'b000);

wire signed [15:0] sample_in_signed = sample_in;
wire signed [27:0] scaled_sample =
    ($signed(sample_in_signed) * $signed({1'b0, env})) >>> 12;

always @(*) begin
    case (meta)
        3'b000: begin
            attack_len_sel = 16'd64;
            decay_len_sel = 16'd960;
            release_len_sel = 16'd1440;
            sustain_level_sel = 12'd2304;
        end
        3'b001: begin
            attack_len_sel = 16'd24;
            decay_len_sel = 16'd600;
            release_len_sel = 16'd720;
            sustain_level_sel = 12'd1792;
        end
        3'b010: begin
            attack_len_sel = 16'd320;
            decay_len_sel = 16'd1800;
            release_len_sel = 16'd3200;
            sustain_level_sel = 12'd3200;
        end
        3'b011: begin
            attack_len_sel = 16'd96;
            decay_len_sel = 16'd900;
            release_len_sel = 16'd1200;
            sustain_level_sel = 12'd2816;
        end
        3'b100: begin
            attack_len_sel = 16'd16;
            decay_len_sel = 16'd120;
            release_len_sel = 16'd360;
            sustain_level_sel = 12'd3584;
        end
        3'b101: begin
            attack_len_sel = 16'd8;
            decay_len_sel = 16'd1500;
            release_len_sel = 16'd2600;
            sustain_level_sel = 12'd1024;
        end
        3'b110: begin
            attack_len_sel = 16'd180;
            decay_len_sel = 16'd1500;
            release_len_sel = 16'd2400;
            sustain_level_sel = 12'd2560;
        end
        3'b111: begin
            attack_len_sel = 16'd48;
            decay_len_sel = 16'd720;
            release_len_sel = 16'd960;
            sustain_level_sel = 12'd2944;
        end
        default: begin
            attack_len_sel = 16'd64;
            decay_len_sel = 16'd960;
            release_len_sel = 16'd1440;
            sustain_level_sel = 12'd2304;
        end
    endcase
end

always @(*) begin
    env_interp = 28'd0;

    case (state)
        ATTACK: begin
            if (attack_len_sel <= 16'd1) begin
                env_interp = {16'd0, ENV_MAX};
            end else begin
                env_interp = ((stage_count + 16'd1) * ENV_MAX) / attack_len_sel;
            end
        end

        DECAY: begin
            if (decay_len_sel <= 16'd1) begin
                env_interp = {16'd0, sustain_level_sel};
            end else begin
                env_interp =
                    {16'd0, ENV_MAX} -
                    (((stage_count + 16'd1) * (ENV_MAX - sustain_level_sel)) / decay_len_sel);
            end
        end

        RELEASE: begin
            if (release_len_sel <= 16'd1 || release_start_env == 12'd0) begin
                env_interp = 28'd0;
            end else begin
                env_interp =
                    {16'd0, release_start_env} -
                    (((stage_count + 16'd1) * release_start_env) / release_len_sel);
            end
        end

        default: begin
            env_interp = {16'd0, env};
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
        stage_count <= 16'd0;
        release_start_env <= 12'd0;
    end else begin
        env_done <= 1'b0;

        if (load) begin
            state <= bypass_env ? SUSTAIN : ATTACK;
            env <= bypass_env ? ENV_MAX : 12'd0;
            sample_out <= 16'd0;
            release_pending <= 1'b0;
            stage_count <= 16'd0;
            release_start_env <= 12'd0;
        end else if (!active) begin
            state <= IDLE;
            env <= 12'd0;
            sample_out <= 16'd0;
            release_pending <= 1'b0;
            stage_count <= 16'd0;
            release_start_env <= 12'd0;
        end else if (bypass_env) begin
            state <= SUSTAIN;
            env <= ENV_MAX;
            release_pending <= 1'b0;
            stage_count <= 16'd0;
            release_start_env <= 12'd0;

            if (note_done) begin
                state <= IDLE;
                env <= 12'd0;
                sample_out <= 16'd0;
                env_done <= 1'b1;
            end else if (sample_tick) begin
                sample_out <= sample_in;
            end
        end else begin
            if (note_done) begin
                release_pending <= 1'b1;
            end

            if (sample_tick) begin
                case (state)
                    IDLE: begin
                        env <= 12'd0;
                        state <= IDLE;
                        stage_count <= 16'd0;
                    end

                    ATTACK: begin
                        if (release_pending || note_done) begin
                            state <= RELEASE;
                            stage_count <= 16'd0;
                            release_start_env <= env;
                            release_pending <= 1'b0;
                        end else if (attack_len_sel <= 16'd1 || (stage_count + 16'd1) >= attack_len_sel) begin
                            env <= ENV_MAX;
                            state <= DECAY;
                            stage_count <= 16'd0;
                        end else begin
                            env <= env_interp[11:0];
                            stage_count <= stage_count + 16'd1;
                        end
                    end

                    DECAY: begin
                        if (release_pending || note_done) begin
                            state <= RELEASE;
                            stage_count <= 16'd0;
                            release_start_env <= env;
                            release_pending <= 1'b0;
                        end else if (decay_len_sel <= 16'd1 || (stage_count + 16'd1) >= decay_len_sel) begin
                            env <= sustain_level_sel;
                            state <= SUSTAIN;
                            stage_count <= 16'd0;
                        end else begin
                            env <= env_interp[11:0];
                            stage_count <= stage_count + 16'd1;
                        end
                    end 

                    SUSTAIN: begin
                        env <= sustain_level_sel;
                        stage_count <= 16'd0;
                        if (release_pending || note_done) begin
                            state <= RELEASE;
                            release_start_env <= sustain_level_sel;
                            stage_count <= 16'd0;
                            release_pending <= 1'b0;
                        end
                    end

                    RELEASE: begin
                        release_pending <= 1'b0;
                        if (release_len_sel <= 16'd1 || release_start_env == 12'd0 ||
                            (stage_count + 16'd1) >= release_len_sel) begin
                            env <= 12'd0;
                            state <= IDLE;
                            stage_count <= 16'd0;
                            release_start_env <= 12'd0;
                            env_done <= 1'b1;
                        end else begin
                            env <= env_interp[11:0];
                            stage_count <= stage_count + 16'd1;
                        end
                    end

                    default: begin
                        state <= IDLE;
                        env <= 12'd0;
                        release_pending <= 1'b0;
                        stage_count <= 16'd0;
                        release_start_env <= 12'd0;
                    end
                endcase

                sample_out <= scaled_sample[15:0];
            end
        end
    end
end

endmodule
