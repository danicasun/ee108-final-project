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

//TEMP TEMP -- TODO set this up 
localparam attack_step = 3'd0;
localparam decay_step = 3'd0;
localparam release_step = 3'd0;
localparam sustain_level = 3'd0;
localparam ENV_MAX = 3'd0;

always @(posedge clk) begin
    if (reset) begin
        state <= IDLE;
        env <= 0;
        env_done <= 0;
    end
    if (load) begin
        state <= ATTACK;
        env <= 12'd0;
    end else begin 
    
        case(state)
            IDLE: begin
                env <= 12'd0;  
                if (active) begin 
                    state <= ATTACK;
                end
            end
            
            ATTACK: begin
                if (env + attack_step >= ENV_MAX) begin
                    env <= ENV_MAX;
                    state <= DECAY;
                end else begin
                    env <= env + attack_step;
                end
            end
            
            DECAY: begin
                if (env <= sustain_level + decay_step) begin
                    env <= sustain_level;
                    state <= SUSTAIN;
                end else begin
                    env <= env - decay_step;
                end
            end 
            
            SUSTAIN: begin
                env <= sustain_level;
                if (note_done) begin
                    state <= RELEASE;
                end
            end
            
            RELEASE: begin
                if (env <= release_step) begin
                    env <= 12'd0;
                    state <= IDLE;
                    env_done = 1'd1;
                end else begin
                    env <= env - release_step;
                end
            end 
        endcase 
        
        if (!active && !load) begin
            state <= IDLE;
            env <= 12'd0;
        end 
    end
    
    sample_out <= (sample_in * {1'b0, env}) >> 12;
end

endmodule
