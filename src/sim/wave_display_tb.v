`timescale 1ns/1ps

module wave_display_tb;
  reg clk=0, reset=1;
  reg [10:0] x;
  reg [9:0]  y;
  reg valid;
  reg read_index;
  reg saw_any;

  wire [8:0] read_address;
  wire [8:0] read_address_voice0;
  wire [8:0] read_address_voice1;
  wire [8:0] read_address_voice2;
  wire valid_pixel;
  wire [7:0] r,g,b;

  wire [7:0] ram_dout;

  wave_display dut(
    .clk(clk), .reset(reset),
    .x(x), .y(y), .valid(valid),
    .read_value(ram_dout),
    .read_index(read_index),
    .read_address(read_address),
    .read_value_voice0(ram_dout),
    .read_index_voice0(read_index),
    .read_address_voice0(read_address_voice0),
    .read_value_voice1(ram_dout),
    .read_index_voice1(read_index),
    .read_address_voice1(read_address_voice1),
    .read_value_voice2(ram_dout),
    .read_index_voice2(read_index),
    .read_address_voice2(read_address_voice2),
    .valid_pixel(valid_pixel),
    .r(r), .g(g), .b(b)
  );

  // fake RAM
  fake_sample_ram ram(
    .clk(clk),
    .addr(read_address[7:0]), // ignore MSB 
    .dout(ram_dout)
  );

  always #5 clk = ~clk;

  // helper
  task tick;
    @(posedge clk);
  endtask

  // expected address mapping helper
  function [7:0] expected_addr_low(input [10:0] xx);
    begin
      if (xx[10:8] == 3'b001)
        expected_addr_low = {1'b0, xx[7:1]};   // 001 -> 0 + x thick
      else if (xx[10:8] == 3'b010)
        expected_addr_low = {1'b1, xx[7:1]};   // 010 -> 1 + x thick
      else
        expected_addr_low = 8'h00;             // outside region
    end
  endfunction
  
  integer i;
  reg test1_fail, test2_fail, test3_fail, test4_fail, test5_fail, test6_fail;
  
  // flush pipeline after changing inputs (x/y/valid)
  task flush_pipe;
    begin
      repeat(3) tick(); // matches x1/x2 and draw1/draw2 
    end
  endtask

  initial begin
    // defaults
    x=0; y=0; valid=0; read_index=0;
    test1_fail = 0;
    test2_fail = 0;
    test3_fail = 0;
    test4_fail = 0;
    test5_fail = 0;
    test6_fail = 0;

    // reset
    repeat(5) tick();
    reset = 0;


    // test 1: Sweep in draw region, quadrant 001
    valid = 1;
    y = 10'd120;       // top half
    read_index = 0;

    repeat(3) tick(); // pipeline fill

    for (i=0; i<256; i=i+1) begin
      x = 11'b001_000000000 + i;
      tick();

      if (valid_pixel) begin
        if (r !== 8'hFF || g !== 8'hFF || b !== 8'hFF)
          test1_fail = 1;
      end
    end

    if (test1_fail)
      $display("TEST 1 FAIL: incorrect RGB when drawing");
    else
      $display("TEST 1 PASS: sweep in draw region");

    // test 2: valid = 0 must suppress drawing
    valid = 0;
    y = 10'd120;
    x = 11'b001_000001000;

    repeat(10) begin
      tick();
      if (valid_pixel !== 1'b0)
        test2_fail = 1;
    end

    if (test2_fail)
      $display("TEST 2 FAIL: drew when valid=0");
    else
      $display("TEST 2 PASS: valid gating");

    // test 3: bottom half must suppress drawing
    valid = 1;
    y = 10'b1_000000000;   // bottom half
    x = 11'b001_000001000;

    repeat(10) begin
      tick();
      if (valid_pixel !== 1'b0)
        test3_fail = 1;
    end

    if (test3_fail)
      $display("TEST 3 FAIL: drew in bottom half");
    else
      $display("TEST 3 PASS: top-half gating");
      
    // test 4: address mapping correctness, 001 vs 010 vs outside
    // checks read_address[7:0] matches the mapping for a few known
    valid = 1;
    y = 10'd120;
    read_index = 0;

    x = 11'b001_010101010; #1;
    if (read_address[7:0] !== expected_addr_low(x)) test4_fail = 1;

    x = 11'b010_010101010; #1;
    if (read_address[7:0] !== expected_addr_low(x)) test4_fail = 1;

    x = 11'b000_111100000; #1;
    if (read_address[7:0] !== expected_addr_low(x)) test4_fail = 1;

    tick();

    if (test4_fail)
      $display("TEST 4 FAIL: read_address mapping wrong");
    else
      $display("TEST 4 PASS: read_address mapping (001/010/outside)");

    // test 5: read_index affects MSB of read_address 
    x = 11'b001_000101010;

    read_index = 0; #1;
    if (read_address[8] !== 1'b0) test5_fail = 1;

    read_index = 1; #1;
    if (read_address[8] !== 1'b1) test5_fail = 1;

    tick();

    if (test5_fail)
      $display("TEST 5 FAIL: read_address[8] not following read_index");
    else
      $display("TEST 5 PASS: buffer select bit (read_index)");


    // test 6: no drawing outside middle quadrants
    valid = 1;
    y = 10'd120;
    read_index = 0;
    x = 11'b000_000001000; // not 001/010
    flush_pipe();

    repeat(10) begin
      tick();
      if (valid_pixel !== 1'b0)
        test6_fail = 1;
    end

    if (test6_fail)
      $display("TEST 6 FAIL: drew outside middle quadrants");
    else
      $display("TEST 6 PASS: no drawing outside middle quadrants");

    // summary
    if (!test1_fail && !test2_fail && !test3_fail &&
        !test4_fail && !test5_fail && !test6_fail)
      $display("ALL TESTS PASSED.");
    else
      $display("ONE OR MORE TESTS FAILED.");

    $finish;
  end

endmodule

