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

//instantiate sine readers for each harmonic


//weights based on meta

//sum


endmodule