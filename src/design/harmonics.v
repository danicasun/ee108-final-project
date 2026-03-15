module harmonics #(
    parameter PHASE_W = 20, 
    parameter SAMPLE_W = 16,
    parameter W_SHIFT = 5
)(
    input clk, 
    input reset, 
    input restart_phase,
    input active,
    input gen_next, 
    input [PHASE_W-1:0] step_size, 
    input [2:0] meta, 
    output reg [SAMPLE_W-1:0] sample,
    output reg sample_ready 
);

// Widen the harmonic step path to the full phase-accumulator width so
// upper-octave harmonics do not wrap before they reach the sine reader.
localparam HARM_STEP_W = PHASE_W + 2;
wire [HARM_STEP_W-1:0] step1 = {{(HARM_STEP_W-PHASE_W){1'b0}}, step_size};
wire [HARM_STEP_W-1:0] step2 = step1 << 1;
wire [HARM_STEP_W-1:0] step3 = step1 + (step1 << 1);
wire [HARM_STEP_W-1:0] step4 = step1 << 2;

wire do_gen = gen_next && active; 

wire [SAMPLE_W-1:0] s1, s2, s3, s4;
wire r1, r2, r3, r4;

//instantiate sine readers for each harmonic
sine_reader h1(
    .clk(clk), 
    .reset(reset),
    .restart_phase(restart_phase),
    .step_size(step1), 
    .generate_next(do_gen), 
    .sample_ready(r1), 
    .sample(s1)
);

sine_reader h2(
    .clk(clk), 
    .reset(reset),
    .restart_phase(restart_phase),
    .step_size(step2), 
    .generate_next(do_gen), 
    .sample_ready(r2), 
    .sample(s2)
);

sine_reader h3(
    .clk(clk), 
    .reset(reset),
    .restart_phase(restart_phase),
    .step_size(step3), 
    .generate_next(do_gen), 
    .sample_ready(r3), 
    .sample(s3)
);

sine_reader h4(
    .clk(clk), 
    .reset(reset),
    .restart_phase(restart_phase),
    .step_size(step4), 
    .generate_next(do_gen), 
    .sample_ready(r4), 
    .sample(s4)
);

//weights based on meta
parameter WEIGHT_W = W_SHIFT + 1;
reg [WEIGHT_W-1:0] w1, w2, w3, w4;

always @(*) begin
    case (meta) 
        3'b000: begin
            w1 = 32;
            w2 = 0; 
            w3 = 0; 
            w4 = 0;
        end 
        3'b001: begin
            w1 = 24;
            w2 = 8; 
            w3 = 0; 
            w4 = 0;
        end  
        3'b010: begin
            w1 = 20;
            w2 = 8; 
            w3 = 4; 
            w4 = 0;
        end 
        3'b011: begin
            w1 = 24;
            w2 = 0; 
            w3 = 8; 
            w4 = 0;
        end  
        3'b100: begin
            w1 = 16;
            w2 = 8; 
            w3 = 4; 
            w4 = 4;
        end   
        3'b101: begin
            w1 = 20;
            w2 = 0; 
            w3 = 0; 
            w4 = 8;
        end 
        3'b110: begin
            w1 = 16;
            w2 = 8; 
            w3 = 6; 
            w4 = 2;
        end 
        3'b111: begin
            w1 = 28;
            w2 = 4; 
            w3 = 0; 
            w4 = 0;
        end 
        default: begin
            w1 = 32;
            w2 = 0;
            w3 = 0;
            w4 = 0;
        end
    endcase
end

//sum
parameter MIX_W = SAMPLE_W + 8;
wire signed [SAMPLE_W-1:0] s1_signed = s1;
wire signed [SAMPLE_W-1:0] s2_signed = s2;
wire signed [SAMPLE_W-1:0] s3_signed = s3;
wire signed [SAMPLE_W-1:0] s4_signed = s4;
wire signed [MIX_W-1:0] p1 = $signed(s1_signed) * $signed({1'b0, w1});
wire signed [MIX_W-1:0] p2 = $signed(s2_signed) * $signed({1'b0, w2});
wire signed [MIX_W-1:0] p3 = $signed(s3_signed) * $signed({1'b0, w3});
wire signed [MIX_W-1:0] p4 = $signed(s4_signed) * $signed({1'b0, w4});

reg signed [MIX_W-1:0] p1_q, p2_q, p3_q, p4_q;
wire signed [MIX_W-1:0] mixsum = p1_q + p2_q + p3_q + p4_q;
wire mix_valid = r1 & r2 & r3 & r4;
reg signed [MIX_W-1:0] mixsum_q;
reg product_valid_q;
reg mix_valid_q;
parameter signed [SAMPLE_W-1:0] SAMPLE_MAX = {1'b0, {(SAMPLE_W-1){1'b1}}};
parameter signed [SAMPLE_W-1:0] SAMPLE_MIN = {1'b1, {(SAMPLE_W-1){1'b0}}};
wire signed [MIX_W-1:0] mix_scale_q = mixsum_q >>> W_SHIFT;

always @(posedge clk) begin
    if (reset || !active || restart_phase) begin
        p1_q <= {MIX_W{1'b0}};
        p2_q <= {MIX_W{1'b0}};
        p3_q <= {MIX_W{1'b0}};
        p4_q <= {MIX_W{1'b0}};
        mixsum_q <= {MIX_W{1'b0}};
        product_valid_q <= 1'b0;
        mix_valid_q <= 1'b0;
    end else begin
        product_valid_q <= mix_valid;
        mix_valid_q <= product_valid_q;

        if (mix_valid) begin
            p1_q <= p1;
            p2_q <= p2;
            p3_q <= p3;
            p4_q <= p4;
        end

        if (product_valid_q) begin
            mixsum_q <= mixsum;
        end
    end
end

always @(*) begin
    sample_ready = 1'b0;
    sample = {SAMPLE_W{1'b0}};

    if (!reset && active) begin
        sample_ready = mix_valid_q;

        if (mix_scale_q > SAMPLE_MAX) begin
            sample = SAMPLE_MAX;
        end else if (mix_scale_q < SAMPLE_MIN) begin
            sample = SAMPLE_MIN;
        end else begin
            sample = mix_scale_q[SAMPLE_W-1:0];
        end
    end
end

endmodule
