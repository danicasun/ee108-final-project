`timescale 1ns/1ps

module echo_delay_bram_tb;
    parameter SAMPLE_WIDTH = 16;
    parameter MAX_DELAY_SAMPLES = 4;
    parameter ECHO_ADDR_WIDTH = 2;

    reg clk;
    reg reset;
    reg sample_tick;
    reg signed [SAMPLE_WIDTH-1:0] sample_in;
    reg [ECHO_ADDR_WIDTH-1:0] delay_samples;

    wire delayed_valid;
    wire signed [SAMPLE_WIDTH-1:0] delayed_sample;

    echo_delay_BRAM #(
        .SAMPLE_WIDTH(SAMPLE_WIDTH),
        .MAX_DELAY_SAMPLES(MAX_DELAY_SAMPLES),
        .ECHO_ADDR_WIDTH(ECHO_ADDR_WIDTH)
    ) dut (
        .clk(clk),
        .reset(reset),
        .sample_tick(sample_tick),
        .sample_in(sample_in),
        .delay_samples(delay_samples),
        .delayed_valid(delayed_valid),
        .delayed_sample(delayed_sample)
    );

    initial clk = 1'b0;
    always #5 clk = ~clk;

    task fail;
        input [255:0] message;
        begin
            $display("FAIL: %0s", message);
            $finish;
        end
    endtask

    task write_sample;
        input signed [SAMPLE_WIDTH-1:0] sample_value;
        input [ECHO_ADDR_WIDTH-1:0] delay_value;
        begin
            @(negedge clk);
            sample_in = sample_value;
            delay_samples = delay_value;
            sample_tick = 1'b1;
            @(negedge clk);
            sample_tick = 1'b0;
            repeat (3) @(posedge clk);
        end
    endtask

    initial begin
        reset = 1'b1;
        sample_tick = 1'b0;
        sample_in = 16'sd0;
        delay_samples = {ECHO_ADDR_WIDTH{1'b0}};

        repeat (3) @(posedge clk);
        reset = 1'b0;
        @(posedge clk);

        if (delayed_valid !== 1'b0 || delayed_sample !== 16'sd0) begin
            fail("reset did not clear the delayed output");
        end
        if (dut.write_addr !== 2'd0 || dut.fill_count !== 3'd0) begin
            fail("reset did not clear the circular buffer state");
        end

        // Delay 0 disables the echo output.
        write_sample(16'sd1234, 2'd0);
        if (delayed_valid !== 1'b0 || delayed_sample !== 16'sd0) begin
            fail("delay 0 should suppress delayed output");
        end

        // A two-sample delay should become valid after enough writes.
        write_sample(16'sd100, 2'd2);
        if (delayed_valid !== 1'b0 || delayed_sample !== 16'sd0) begin
            fail("echo became valid too early after the first write");
        end

        write_sample(16'sd200, 2'd2);
        if (delayed_valid !== 1'b1 || delayed_sample !== 16'sd100) begin
            fail("two-sample delay did not return the oldest delayed sample");
        end

        write_sample(16'sd300, 2'd2);
        if (delayed_valid !== 1'b1 || delayed_sample !== 16'sd200) begin
            fail("delayed output did not advance to the next stored sample");
        end

        write_sample(16'sd400, 2'd2);
        if (delayed_valid !== 1'b1 || delayed_sample !== 16'sd300) begin
            fail("delayed output was incorrect before pointer wrap");
        end

        // The circular buffer should wrap and continue returning delayed data.
        write_sample(16'sd500, 2'd2);
        if (delayed_valid !== 1'b1 || delayed_sample !== 16'sd400) begin
            fail("delayed output was incorrect after pointer wrap");
        end
        if (dut.write_addr !== 2'd1) begin
            fail("write pointer did not wrap back to the start of the buffer");
        end
        if (dut.fill_count !== 3'd4) begin
            fail("fill_count should saturate at MAX_DELAY_SAMPLES");
        end

        // Reset should clear validity even after the buffer has filled.
        @(negedge clk);
        reset = 1'b1;
        @(posedge clk);
        #1;
        @(negedge clk);
        reset = 1'b0;
        @(posedge clk);

        if (delayed_valid !== 1'b0 || delayed_sample !== 16'sd0) begin
            fail("reset did not clear delayed output after wraparound activity");
        end
        if (dut.write_addr !== 2'd0 || dut.fill_count !== 3'd0) begin
            fail("reset did not clear pointer state after wraparound activity");
        end

        $display("PASS: echo_delay_BRAM delay gating, delayed reads, wraparound, and reset behavior.");
        $finish;
    end

endmodule
