module sine_reader(
    input clk,
    input reset,
    input restart_phase,
    input [21:0] step_size,
    input generate_next,

    output sample_ready,
    output wire [15:0] sample
);


    // [21:20] = quadrant
    // [19:10] = raw address (10 integer bits)
    // [9:0]   = Precision (10 fractional bits)
    reg [21:0] phase;
    wire [1:0] quadrant = phase[21:20];
    wire [9:0] raw_addr = phase[19:10];


    reg [9:0] rom_addr;
    always @(*) begin
        case (quadrant)
            2'b00: rom_addr = raw_addr;          //1st quadrant
            2'b01: rom_addr = ~raw_addr;         //2nd quadrant (flip horizontal)
            2'b10: rom_addr = raw_addr;          //3rd quadrant
            2'b11: rom_addr = ~raw_addr;         //4th quadrant (flip horizontal)
        endcase
    end

    wire [15:0] sine_out;
    sine_rom sine_rom_inst (
        .clk(clk),
        .addr(rom_addr),
        .dout(sine_out)
    );

    always @(posedge clk) begin
        if (reset || restart_phase) begin
            phase <= 22'b0;
        end else if (generate_next) begin

            phase <= phase + step_size;
        end
    end


    
    reg [1:0] quadrant_dly; 
    reg sample_ready_dly;   
    reg valid_1;            

    always @(posedge clk) begin
        if (reset || restart_phase) begin
            quadrant_dly <= 2'b0;
            valid_1 <= 1'b0;
            sample_ready_dly <= 1'b0;
        end else begin
            
            quadrant_dly <= quadrant;
            
            valid_1 <= generate_next;
            sample_ready_dly <= valid_1; 
        end
    end


    //negate the output if we are in Quadrant 3 (10) or 4 (11) to check the Top bit (bit 1) of the delayed quadrant
    assign sample = (quadrant_dly[1]) ? -sine_out : sine_out;
    
    assign sample_ready = sample_ready_dly;

endmodule
