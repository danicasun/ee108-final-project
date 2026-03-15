`timescale 1ns/1ps

module wave_display (
    input clk,
    input reset,
    input [10:0] x,  // [0..1279]
    input [9:0]  y,  // [0..1023]
    input valid,
    input [7:0] read_value,
    input read_index,
    output wire [8:0] read_address,
    input [7:0] read_value_voice0,
    input read_index_voice0,
    output wire [8:0] read_address_voice0,
    input [7:0] read_value_voice1,
    input read_index_voice1,
    output wire [8:0] read_address_voice1,
    input [7:0] read_value_voice2,
    input read_index_voice2,
    output wire [8:0] read_address_voice2,
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
    wire [8:0] addr_voice0 = {read_index_voice0, addr_low};
    wire [8:0] addr_voice1 = {read_index_voice1, addr_low};
    wire [8:0] addr_voice2 = {read_index_voice2, addr_low};

    assign read_address = addr_comb;
    assign read_address_voice0 = addr_voice0;
    assign read_address_voice1 = addr_voice1;
    assign read_address_voice2 = addr_voice2;

    //adjust read_value for 800x480 display:
    //read_value_adjusted = read_value/2 + 32
    wire [7:0] read_value_adjusted = (read_value >> 1) + 8'd32;
    wire [7:0] read_value_adjusted_voice0 = (read_value_voice0 >> 1) + 8'd32;
    wire [7:0] read_value_adjusted_voice1 = (read_value_voice1 >> 1) + 8'd32;
    wire [7:0] read_value_adjusted_voice2 = (read_value_voice2 >> 1) + 8'd32;

    reg [7:0] rv1, rv2;
    reg [7:0] rv1_voice0, rv2_voice0;
    reg [7:0] rv1_voice1, rv2_voice1;
    reg [7:0] rv1_voice2, rv2_voice2;

    always @(posedge clk) begin
      if (reset) begin
        rv1 <= 8'd0;
        rv2 <= 8'd0;
        rv1_voice0 <= 8'd0;
        rv2_voice0 <= 8'd0;
        rv1_voice1 <= 8'd0;
        rv2_voice1 <= 8'd0;
        rv1_voice2 <= 8'd0;
        rv2_voice2 <= 8'd0;
      end else begin
        rv1 <= read_value_adjusted;
        rv2 <= rv1;
        rv1_voice0 <= read_value_adjusted_voice0;
        rv2_voice0 <= rv1_voice0;
        rv1_voice1 <= read_value_adjusted_voice1;
        rv2_voice1 <= rv1_voice1;
        rv1_voice2 <= read_value_adjusted_voice2;
        rv2_voice2 <= rv1_voice2;
      end
    end

    reg [10:0] x1, x2;
    reg [9:0]  y1, y2;
    reg        v1, v2;
    reg        draw1, draw2;

    reg [8:0] addr1, addr2, addr3;
    reg [8:0] addr1_voice0, addr2_voice0, addr3_voice0;
    reg [8:0] addr1_voice1, addr2_voice1, addr3_voice1;
    reg [8:0] addr1_voice2, addr2_voice2, addr3_voice2;

    always @(posedge clk) begin
        if (reset) begin
            x1 <= 11'd0; x2 <= 11'd0;
            y1 <= 10'd0; y2 <= 10'd0;
            v1 <= 1'b0;  v2 <= 1'b0;
            draw1 <= 1'b0; draw2 <= 1'b0;

            addr1 <= 9'd0; addr2 <= 9'd0; addr3 <= 9'd0;
            addr1_voice0 <= 9'd0; addr2_voice0 <= 9'd0; addr3_voice0 <= 9'd0;
            addr1_voice1 <= 9'd0; addr2_voice1 <= 9'd0; addr3_voice1 <= 9'd0;
            addr1_voice2 <= 9'd0; addr2_voice2 <= 9'd0; addr3_voice2 <= 9'd0;
        end else begin
            x1 <= x;  x2 <= x1;
            y1 <= y;  y2 <= y1;
            v1 <= valid; v2 <= v1;

            draw1 <= (in_mid_quadrants && in_top_half);
            draw2 <= draw1;

            addr1 <= addr_comb;
            addr2 <= addr1;
            addr3 <= addr2;
            addr1_voice0 <= addr_voice0;
            addr2_voice0 <= addr1_voice0;
            addr3_voice0 <= addr2_voice0;
            addr1_voice1 <= addr_voice1;
            addr2_voice1 <= addr1_voice1;
            addr3_voice1 <= addr2_voice1;
            addr1_voice2 <= addr_voice2;
            addr2_voice2 <= addr1_voice2;
            addr3_voice2 <= addr2_voice2;
        end
    end

    //track last two accepted samples (8-bit Y-ish values)
    //update only when the pipelined address changes (every other pixel).
    wire in_draw_region = draw2 && v2;   // draw2 is aligned x in 001/010 && y top-half
    reg in_draw_region_d;
    
    reg [7:0] samp_prev, samp_curr;
    reg [7:0] samp_prev_voice0, samp_curr_voice0;
    reg [7:0] samp_prev_voice1, samp_curr_voice1;
    reg [7:0] samp_prev_voice2, samp_curr_voice2;
    
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
        samp_prev_voice0 <= 8'd0;
        samp_curr_voice0 <= 8'd0;
        samp_prev_voice1 <= 8'd0;
        samp_curr_voice1 <= 8'd0;
        samp_prev_voice2 <= 8'd0;
        samp_curr_voice2 <= 8'd0;
      end else if (!in_draw_region) begin
        samp_prev <= 8'd0;
        samp_curr <= 8'd0;
        samp_prev_voice0 <= 8'd0;
        samp_curr_voice0 <= 8'd0;
        samp_prev_voice1 <= 8'd0;
        samp_curr_voice1 <= 8'd0;
        samp_prev_voice2 <= 8'd0;
        samp_curr_voice2 <= 8'd0;
      end else if (enter_draw_region) begin
        // first column: no vertical segment
        samp_prev <= rv2;
        samp_curr <= rv2;
        samp_prev_voice0 <= rv2_voice0;
        samp_curr_voice0 <= rv2_voice0;
        samp_prev_voice1 <= rv2_voice1;
        samp_curr_voice1 <= rv2_voice1;
        samp_prev_voice2 <= rv2_voice2;
        samp_curr_voice2 <= rv2_voice2;
      end else begin
        if (addr2 != addr3) begin
          samp_prev <= samp_curr;
          samp_curr <= rv2;
        end
        if (addr2_voice0 != addr3_voice0) begin
          samp_prev_voice0 <= samp_curr_voice0;
          samp_curr_voice0 <= rv2_voice0;
        end
        if (addr2_voice1 != addr3_voice1) begin
          samp_prev_voice1 <= samp_curr_voice1;
          samp_curr_voice1 <= rv2_voice1;
        end
        if (addr2_voice2 != addr3_voice2) begin
          samp_prev_voice2 <= samp_curr_voice2;
          samp_curr_voice2 <= rv2_voice2;
        end
      end
    end

    //Y mapping: in top half, drop MSB y[9] (known 0) and drop LSB y[0]
    //so we compare 8-bit quantities and make the line 2 pixels tall.
    wire [7:0] y_disp = y2[8:1];

    wire [7:0] y_min = (samp_prev < samp_curr) ? samp_prev : samp_curr;
    wire [7:0] y_max = (samp_prev < samp_curr) ? samp_curr : samp_prev;
    wire [7:0] y_min_voice0 = (samp_prev_voice0 < samp_curr_voice0) ? samp_prev_voice0 : samp_curr_voice0;
    wire [7:0] y_max_voice0 = (samp_prev_voice0 < samp_curr_voice0) ? samp_curr_voice0 : samp_prev_voice0;
    wire [7:0] y_min_voice1 = (samp_prev_voice1 < samp_curr_voice1) ? samp_prev_voice1 : samp_curr_voice1;
    wire [7:0] y_max_voice1 = (samp_prev_voice1 < samp_curr_voice1) ? samp_curr_voice1 : samp_prev_voice1;
    wire [7:0] y_min_voice2 = (samp_prev_voice2 < samp_curr_voice2) ? samp_prev_voice2 : samp_curr_voice2;
    wire [7:0] y_max_voice2 = (samp_prev_voice2 < samp_curr_voice2) ? samp_curr_voice2 : samp_prev_voice2;

    wire pixel_on_combined = draw2 && v2 && (y_disp >= y_min) && (y_disp <= y_max);
    wire pixel_on_voice0 = draw2 && v2 && (y_disp >= y_min_voice0) && (y_disp <= y_max_voice0);
    wire pixel_on_voice1 = draw2 && v2 && (y_disp >= y_min_voice1) && (y_disp <= y_max_voice1);
    wire pixel_on_voice2 = draw2 && v2 && (y_disp >= y_min_voice2) && (y_disp <= y_max_voice2);

    assign valid_pixel = pixel_on_combined || pixel_on_voice0 || pixel_on_voice1 || pixel_on_voice2;

    assign r = pixel_on_combined ? 8'hFF :
               pixel_on_voice0 ? 8'hFF :
               pixel_on_voice1 ? 8'h00 :
               pixel_on_voice2 ? 8'h00 :
               8'h00;
    assign g = pixel_on_combined ? 8'hFF :
               pixel_on_voice0 ? 8'h00 :
               pixel_on_voice1 ? 8'hFF :
               pixel_on_voice2 ? 8'h00 :
               8'h00;
    assign b = pixel_on_combined ? 8'hFF :
               pixel_on_voice0 ? 8'h00 :
               pixel_on_voice1 ? 8'h00 :
               pixel_on_voice2 ? 8'hFF :
               8'h00;

endmodule

