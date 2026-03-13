`timescale 1ns/1ps

module dynamics_tb;
    localparam IDLE = 3'd0;
    localparam ATTACK = 3'd1;
    localparam DECAY = 3'd2;
    localparam SUSTAIN = 3'd3;
    localparam RELEASE = 3'd4;

    reg clk;
    reg reset;
    reg load;
    reg active;
    reg note_done;
    reg [2:0] meta;
    reg signed [15:0] sample_in;

    wire signed [15:0] sample_out;
    wire env_done;

    dynamics dut (
        .clk(clk),
        .reset(reset),
        .load(load),
        .active(active),
        .note_done(note_done),
        .meta(meta),
        .sample_in(sample_in),
        .sample_out(sample_out),
        .env_done(env_done)
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

    task tick;
        begin
            @(posedge clk);
            #1;
        end
    endtask

    integer release_cycles;

    initial begin
        reset = 1'b1;
        load = 1'b0;
        active = 1'b0;
        note_done = 1'b0;
        meta = 3'd0;
        sample_in = 16'sd4096;

        repeat (3) tick();
        reset = 1'b0;
        tick();

        if (dut.state !== IDLE || dut.env !== 12'd0 || env_done !== 1'b0 || sample_out !== 16'sd0) begin
            fail("reset did not return dynamics to idle");
        end

        active = 1'b1;
        load = 1'b1;
        tick();
        if (dut.state !== ATTACK || dut.env !== 12'd0) begin
            fail("load did not start the attack phase");
        end

        load = 1'b0;

        tick();
        if (dut.state !== ATTACK || dut.env !== 12'd1024) begin
            fail("first attack step is incorrect");
        end

        tick();
        if (dut.state !== ATTACK || dut.env !== 12'd2048) begin
            fail("second attack step is incorrect");
        end

        tick();
        if (dut.state !== ATTACK || dut.env !== 12'd3072) begin
            fail("third attack step is incorrect");
        end

        tick();
        if (dut.state !== DECAY || dut.env !== 12'd4095) begin
            fail("attack did not clamp at full scale and move to decay");
        end

        repeat (4) tick();
        if (dut.state !== SUSTAIN || dut.env !== 12'd3072) begin
            fail("decay did not settle at the sustain level");
        end

        tick();
        if (sample_out !== 16'sd3072) begin
            fail("sample_out did not track the sustain envelope");
        end

        note_done = 1'b1;
        tick();
        note_done = 1'b0;
        if (dut.state !== RELEASE) begin
            fail("note_done did not start the release phase");
        end

        release_cycles = 0;
        while (!env_done && release_cycles < 10) begin
            tick();
            release_cycles = release_cycles + 1;
        end

        if (!env_done) begin
            fail("release never asserted env_done");
        end

        if (dut.state !== IDLE || dut.env !== 12'd0) begin
            fail("release did not return the envelope to idle");
        end

        @(negedge clk);
        active = 1'b0;
        tick();
        if (sample_out !== 16'sd0) begin
            fail("inactive dynamics should drive sample_out to zero");
        end

        $display("PASS: dynamics ADSR load, sustain, release, and mute behavior.");
        $finish;
    end

endmodule
