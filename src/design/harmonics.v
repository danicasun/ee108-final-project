module harmonics #(
    parameter PHASE_W = 24, 
    parameter SAMPLE_W = 16
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


endmodule;