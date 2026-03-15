module echo #(
    parameter integer DELAY_SAMPLES = 12000,
    parameter integer ATTENUATION_SHIFT = 2
) (
    input clk,
    input reset,
    input [15:0] sample_in,
    input sample_valid_in,
    output [15:0] sample_out,
    output sample_valid_out
);

    localparam integer PTR_WIDTH = $clog2(DELAY_SAMPLES);

    function signed [15:0] clip_sample;
        input signed [17:0] value;
        begin
            //if val to positive to fit in 16 bits, saturate
            if (value > 18'sd32767) begin
                clip_sample = 16'sh7fff;
            //too neg, saturate to most neg 16b val
            end else if (value < -18'sd32768) begin
                clip_sample = 16'sh8000;
            end else begin
                //keep low 16
                clip_sample = value[15:0];
            end
        end
    endfunction

    (* ram_style = "block" *) reg signed [15:0] delay_line [0:DELAY_SAMPLES-1];
    reg [PTR_WIDTH-1:0] write_ptr;
    reg [PTR_WIDTH:0] fill_count;
    reg signed [15:0] dry_sample_reg;
    reg signed [15:0] delayed_sample_reg;
    reg sample_valid_reg;

    always @(posedge clk) begin
        if (reset) begin
            write_ptr <= {PTR_WIDTH{1'b0}};
            fill_count <= {(PTR_WIDTH + 1){1'b0}};
            dry_sample_reg <= 16'sd0;
            delayed_sample_reg <= 16'sd0;
            sample_valid_reg <= 1'b0;
        end else begin
            sample_valid_reg <= sample_valid_in;

            if (sample_valid_in) begin
                dry_sample_reg <= $signed(sample_in);

                if (fill_count < DELAY_SAMPLES) begin
                    delayed_sample_reg <= 16'sd0;
                    fill_count <= fill_count + 1'b1;
                end else begin
                    delayed_sample_reg <= delay_line[write_ptr];
                end

                delay_line[write_ptr] <= $signed(sample_in);

                if (write_ptr == (DELAY_SAMPLES - 1)) begin
                    write_ptr <= {PTR_WIDTH{1'b0}};
                end else begin
                    write_ptr <= write_ptr + 1'b1;
                end
            end
        end
    end

    wire signed [17:0] mixed_sample = dry_sample_reg + (delayed_sample_reg >>> ATTENUATION_SHIFT);

    assign sample_out = clip_sample(mixed_sample);
    assign sample_valid_out = sample_valid_reg;

endmodule
