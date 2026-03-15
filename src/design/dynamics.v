module dynamics(
    input clk,
    input reset,
    input trigger,
    input gate,
    input [15:0] sample_in,
    input sample_valid_in,
    output [15:0] sample_out,
    output sample_valid_out
);

    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] ATTACK = 3'd1;
    localparam [2:0] DECAY = 3'd2;
    localparam [2:0] SUSTAIN = 3'd3;
    localparam [2:0] RELEASE = 3'd4;

    localparam [15:0] MAX_LEVEL = 16'hffff;
    localparam [15:0] SUSTAIN_LEVEL = 16'h5000;
    localparam [15:0] ATTACK_STEP = 16'd256;
    localparam integer DECAY_SHIFT = 8;
    localparam integer RELEASE_SHIFT = 9;

    reg [2:0] state;
    reg [15:0] envelope_level;

    wire [15:0] decay_delta = envelope_level - SUSTAIN_LEVEL;
    wire [15:0] decay_step = (decay_delta >> DECAY_SHIFT) == 16'd0 ? 16'd1 : (decay_delta >> DECAY_SHIFT);
    wire [15:0] release_step = (envelope_level >> RELEASE_SHIFT) == 16'd0 ? 16'd1 : (envelope_level >> RELEASE_SHIFT);

    always @(posedge clk) begin
        if (reset) begin
            state <= IDLE;
            envelope_level <= 16'd0;
        end else if (trigger) begin
            state <= ATTACK;
            envelope_level <= 16'd0;
        end else if (sample_valid_in) begin
            case (state)
                IDLE: begin
                    envelope_level <= 16'd0;
                    if (gate) begin
                        state <= ATTACK;
                    end
                end

                ATTACK: begin
                    if (!gate) begin
                        state <= RELEASE;
                    end else if (envelope_level >= (MAX_LEVEL - ATTACK_STEP)) begin
                        envelope_level <= MAX_LEVEL;
                        state <= DECAY;
                    end else begin
                        envelope_level <= envelope_level + ATTACK_STEP;
                    end
                end

                DECAY: begin
                    if (!gate) begin
                        state <= RELEASE;
                    end else if (envelope_level <= SUSTAIN_LEVEL) begin
                        envelope_level <= SUSTAIN_LEVEL;
                        state <= SUSTAIN;
                    end else begin
                        envelope_level <= envelope_level - decay_step;
                    end
                end

                SUSTAIN: begin
                    envelope_level <= SUSTAIN_LEVEL;
                    if (!gate) begin
                        state <= RELEASE;
                    end
                end

                RELEASE: begin
                    if (envelope_level <= release_step) begin
                        envelope_level <= 16'd0;
                        state <= gate ? ATTACK : IDLE;
                    end else begin
                        envelope_level <= envelope_level - release_step;
                    end
                end

                default: begin
                    state <= IDLE;
                    envelope_level <= 16'd0;
                end
            endcase
        end
    end

    wire signed [15:0] signed_sample_in = $signed(sample_in);
    wire signed [32:0] scaled_sample = signed_sample_in * $signed({1'b0, envelope_level});
    wire signed [15:0] scaled_sample_out = scaled_sample >>> 16;

    assign sample_out = scaled_sample_out;
    assign sample_valid_out = sample_valid_in;

endmodule
