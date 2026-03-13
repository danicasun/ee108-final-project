module harmonics #(
    parameter PHASE_W = 20, 
    parameter SAMPLE_W = 16,
    parameter W_SHIFT = 5
)(
    input clk, 
    input reset, 
    input active,
    input gen_next, 
    input [PHASE_W-1:0] step_size, 
    input [2:0] meta, 
    output reg [SAMPLE_W-1:0] sample,
    output reg sample_ready 
);

//harmonic step sizes
wire [PHASE_W-1:0] step1 = step_size;
wire [PHASE_W-1:0] step2 = step_size << 1;
wire [PHASE_W-1:0] step3 = step_size + (step_size << 1);
wire [PHASE_W-1:0] step4 = step_size << 2;

wire do_gen = gen_next && active; 

wire [SAMPLE_W-1:0] s1, s2, s3, s4;
wire r1, r2, r3, r4;

//instantiate sine readers for each harmonic
sine_reader h1(
    .clk(clk), 
    .reset(reset),
    .step_size(step1), 
    .generate_next(do_gen), 
    .sample_ready(r1), 
    .sample(s1)
);

sine_reader h2(
    .clk(clk), 
    .reset(reset),
    .step_size(step2), 
    .generate_next(do_gen), 
    .sample_ready(r2), 
    .sample(s2)
);

sine_reader h3(
    .clk(clk), 
    .reset(reset),
    .step_size(step3), 
    .generate_next(do_gen), 
    .sample_ready(r3), 
    .sample(s3)
);

sine_reader h4(
    .clk(clk), 
    .reset(reset),
    .step_size(step4), 
    .generate_next(do_gen), 
    .sample_ready(r4), 
    .sample(s4)
);

//weights based on meta
localparam WEIGHT_W = W_SHIFT + 1;
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
localparam MIX_W = SAMPLE_W + 8;
wire signed [SAMPLE_W-1:0] s1_signed = s1;
wire signed [SAMPLE_W-1:0] s2_signed = s2;
wire signed [SAMPLE_W-1:0] s3_signed = s3;
wire signed [SAMPLE_W-1:0] s4_signed = s4;
wire signed [MIX_W-1:0] p1 = $signed(s1_signed) * $signed({1'b0, w1});
wire signed [MIX_W-1:0] p2 = $signed(s2_signed) * $signed({1'b0, w2});
wire signed [MIX_W-1:0] p3 = $signed(s3_signed) * $signed({1'b0, w3});
wire signed [MIX_W-1:0] p4 = $signed(s4_signed) * $signed({1'b0, w4});

wire signed [MIX_W-1:0] mixsum = p1 + p2 + p3 + p4;
wire signed [MIX_W-1:0] mix_scale = mixsum >>> W_SHIFT;
wire mix_valid = r1 & r2 & r3 & r4;
localparam signed [SAMPLE_W-1:0] SAMPLE_MAX = {1'b0, {(SAMPLE_W-1){1'b1}}};
localparam signed [SAMPLE_W-1:0] SAMPLE_MIN = {1'b1, {(SAMPLE_W-1){1'b0}}};

//output reg
always @(posedge clk) begin
    if (reset) begin
        sample <= 0;
        sample_ready <= 0;
    end else begin
        sample_ready <= 1'b0;
        
        if (!active) begin
            sample <= 0;
        end else if (mix_valid) begin
            if (mix_scale > SAMPLE_MAX) begin
                sample <= SAMPLE_MAX;
            end else if (mix_scale < SAMPLE_MIN) begin
                sample <= SAMPLE_MIN;
            end else begin
                sample <= mix_scale[SAMPLE_W-1:0];
            end
            sample_ready <= 1'b1;
        end  
    end
end


endmodule
