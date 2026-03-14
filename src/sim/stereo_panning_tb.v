`timescale 1ns/1ps

module stereo_panning_tb;
    parameter SAMPLE_W = 16;
    parameter PAN_W = 3;

    reg clk;
    reg reset;
    reg active;
    reg sample_tick;
    reg signed [SAMPLE_W-1:0] sample_in;
    reg [PAN_W-1:0] pan;

    wire signed [SAMPLE_W-1:0] left_sample;
    wire signed [SAMPLE_W-1:0] right_sample;

    stereo_panning #(
        .SAMPLE_W(SAMPLE_W),
        .PAN_W(PAN_W)
    ) dut (
        .clk(clk),
        .reset(reset),
        .active(active),
        .sample_tick(sample_tick),
        .sample_in(sample_in),
        .pan(pan),
        .left_sample(left_sample),
        .right_sample(right_sample)
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

    task pulse_sample_tick;
        begin
            @(negedge clk);
            sample_tick = 1'b1;
            @(negedge clk);
            sample_tick = 1'b0;
            repeat (2) @(posedge clk);
        end
    endtask

    initial begin
        reset = 1'b1;
        active = 1'b0;
        sample_tick = 1'b0;
        sample_in = 16'sd0;
        pan = {PAN_W{1'b0}};

        repeat (3) @(posedge clk);
        reset = 1'b0;
        @(posedge clk);

        if (left_sample !== 16'sd0 || right_sample !== 16'sd0) begin
            fail("reset did not clear outputs");
        end

        // No sample update should happen unless sample_tick is asserted.
        active = 1'b1;
        sample_in = 16'sd1024;
        pan = 3'd0;
        repeat (2) @(posedge clk);
        if (left_sample !== 16'sd0 || right_sample !== 16'sd0) begin
            fail("outputs changed without sample_tick");
        end

        // Hard-left pan sends the sample only to the left channel.
        pulse_sample_tick();
        if (left_sample !== 16'sd896 || right_sample !== 16'sd0) begin
            fail("hard-left pan produced the wrong stereo split");
        end

        // Hard-right pan sends the sample only to the right channel.
        sample_in = 16'sd1024;
        pan = 3'd7;
        pulse_sample_tick();
        if (left_sample !== 16'sd0 || right_sample !== 16'sd896) begin
            fail("hard-right pan produced the wrong stereo split");
        end

        // Mid pan should preserve sign on both channels.
        sample_in = -16'sd1600;
        pan = 3'd3;
        pulse_sample_tick();
        if (left_sample !== -16'sd800 || right_sample !== -16'sd600) begin
            fail("mid-pan negative sample scaling was incorrect");
        end

        // Inactive voices should mute both channels on the next sample tick.
        active = 1'b0;
        sample_in = 16'sd2048;
        pan = 3'd5;
        pulse_sample_tick();
        if (left_sample !== 16'sd0 || right_sample !== 16'sd0) begin
            fail("inactive panner did not mute both channels");
        end

        $display("PASS: stereo_panning hard pan, mid pan, tick gating, and mute behavior.");
        $finish;
    end

endmodule
