`timescale 1ns/1ps

module wave_display (
    input clk,
    input reset,
    input [10:0] x,  // [0..1279]
    input [9:0]  y,  // [0..1023]
    input valid,
    input [7:0] read_value,
    input read_index,
    input [7:0] trace_r,
    input [7:0] trace_g,
    input [7:0] trace_b,
    output wire [8:0] read_address,
    output wire valid_pixel,
    output wire [7:0] r,
    output wire [7:0] g,
    output wire [7:0] b
);


    //address mapping (combinational)
    //display waveform only in middle quadrants (x[10:8] == 001 or 010)
    //and only in top half of screen (y[9] == 0).
    //
    //for those quadrants:
    //   x = 001xxxxxxxx -> addr = {read_index, 8'b0xxxxxxx} with x LSB dropped
    //   x = 010xxxxxxxx -> addr = {read_index, 8'b1xxxxxxx} with x LSB dropped
    // ----------------------------

    wire in_mid_quadrants = (x[10:8] == 3'b001) || (x[10:8] == 3'b010);
    wire in_top_half      = (y[9] == 1'b0);

    //drop x[0] so the waveform is 2 pixels wide.
    wire [6:0] x_thick = x[7:1]; //7 bits after dropping LSB

    wire [7:0] addr_low =
        (x[10:8] == 3'b001) ? {1'b0, x_thick} :
        (x[10:8] == 3'b010) ? {1'b1, x_thick} :
                              8'h00; //don't care outside draw region

    wire [8:0] addr_comb = {read_index, addr_low};

    assign read_address = addr_comb;

    //adjust read_value for 800x480 display:
    //read_value_adjusted = read_value/2 + 32
    wire [7:0] read_value_adjusted = (read_value >> 1) + 8'd32;

    reg [7:0] rv1, rv2;

    always @(posedge clk) begin
      if (reset) begin
        rv1 <= 8'd0;
        rv2 <= 8'd0;
      end else begin
        rv1 <= read_value_adjusted;
        rv2 <= rv1;
      end
    end

    reg [10:0] x1, x2;
    reg [9:0]  y1, y2;
    reg        v1, v2;
    reg        draw1, draw2;

    reg [8:0] addr1, addr2, addr3;

    always @(posedge clk) begin
        if (reset) begin
            x1 <= 11'd0; x2 <= 11'd0;
            y1 <= 10'd0; y2 <= 10'd0;
            v1 <= 1'b0;  v2 <= 1'b0;
            draw1 <= 1'b0; draw2 <= 1'b0;

            addr1 <= 9'd0; addr2 <= 9'd0; addr3 <= 9'd0;
        end else begin
            x1 <= x;  x2 <= x1;
            y1 <= y;  y2 <= y1;
            v1 <= valid; v2 <= v1;

            draw1 <= (in_mid_quadrants && in_top_half);
            draw2 <= draw1;

            addr1 <= addr_comb;
            addr2 <= addr1;
            addr3 <= addr2;
        end
    end

    //track last two accepted samples (8-bit Y-ish values)
    //update only when the pipelined address changes (every other pixel).
    wire in_draw_region = draw2 && v2;   // draw2 is aligned x in 001/010 && y top-half
    reg in_draw_region_d;
    
    reg [7:0] samp_prev, samp_curr;
    
    always @(posedge clk) begin
      if (reset) begin
        in_draw_region_d <= 1'b0;
      end else begin
        in_draw_region_d <= in_draw_region;
      end
    end
    
    wire enter_draw_region = in_draw_region && !in_draw_region_d;
    
    always @(posedge clk) begin
      if (reset) begin
        samp_prev <= 8'd0;
        samp_curr <= 8'd0;
      end else if (!in_draw_region) begin
        samp_prev <= 8'd0;
        samp_curr <= 8'd0;
      end else if (enter_draw_region) begin
        // first column: no vertical segment
        samp_prev <= rv2;
        samp_curr <= rv2;
      end else if (addr2 != addr3) begin
        samp_prev <= samp_curr;
        samp_curr <= rv2;
      end
    end

    //Y mapping: in top half, drop MSB y[9] (known 0) and drop LSB y[0]
    //so we compare 8-bit quantities and make the line 2 pixels tall.
    wire [7:0] y_disp = y2[8:1];

    wire [7:0] y_min = (samp_prev < samp_curr) ? samp_prev : samp_curr;
    wire [7:0] y_max = (samp_prev < samp_curr) ? samp_curr : samp_prev;

    wire pixel_on = draw2 && v2 && (y_disp >= y_min) && (y_disp <= y_max);

    assign valid_pixel = pixel_on;

    assign r = pixel_on ? trace_r : 8'h00;
    assign g = pixel_on ? trace_g : 8'h00;
    assign b = pixel_on ? trace_b : 8'h00;

endmodule
