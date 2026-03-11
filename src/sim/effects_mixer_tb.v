`timescale 1ns/1ps

module effects_mixer_tb;
    parameter NUM_VOICES = 2;
    parameter SAMPLE_WIDTH = 16;
    parameter PAN_WIDTH = 3;
    parameter MAX_DELAY_SAMPLES = 8;
    parameter ECHO_ADDR_WIDTH = 3;

    reg clk;
    reg reset;
    reg sample_tick;
    reg [NUM_VOICES-1:0] voice_active;
    reg [NUM_VOICES*SAMPLE_WIDTH-1:0] voice_samples;
    reg [NUM_VOICES*PAN_WIDTH-1:0] voice_pan;
    reg echo_enable;
    reg [ECHO_ADDR_WIDTH-1:0] echo_delay_samples;
    reg [3:0] echo_atten_shift;

    wire signed [SAMPLE_WIDTH-1:0] mono_sample;
    wire signed [SAMPLE_WIDTH-1:0] left_sample;
    wire signed [SAMPLE_WIDTH-1:0] right_sample;

    effects_mixer #(
        .NUM_VOICES(NUM_VOICES),
        .SAMPLE_WIDTH(SAMPLE_WIDTH),
        .PAN_WIDTH(PAN_WIDTH),
        .MAX_DELAY_SAMPLES(MAX_DELAY_SAMPLES),
        .ECHO_ADDR_WIDTH(ECHO_ADDR_WIDTH)
    ) dut (
        .clk(clk),
        .reset(reset),
        .sample_tick(sample_tick),
        .voice_active(voice_active),
        .voice_samples(voice_samples),
        .voice_pan(voice_pan),
        .echo_enable(echo_enable),
        .echo_delay_samples(echo_delay_samples),
        .echo_atten_shift(echo_atten_shift),
        .mono_sample(mono_sample),
        .left_sample(left_sample),
        .right_sample(right_sample)
    );

    initial clk = 1'b0;
    always #5 clk = ~clk;

    task pulse_sample_tick;
        begin
            @(negedge clk);
            sample_tick = 1'b1;
            @(negedge clk);
            sample_tick = 1'b0;
            repeat (3) @(posedge clk);
        end
    endtask

    task load_voice_frame;
        input [1:0] active_in;
        input signed [15:0] sample0_in;
        input [2:0] pan0_in;
        input signed [15:0] sample1_in;
        input [2:0] pan1_in;
        begin
            voice_active = active_in;
            voice_samples = {sample1_in, sample0_in};
            voice_pan = {pan1_in, pan0_in};
        end
    endtask

    initial begin
        reset = 1'b1;
        sample_tick = 1'b0;
        voice_active = 2'b00;
        voice_samples = {NUM_VOICES*SAMPLE_WIDTH{1'b0}};
        voice_pan = {NUM_VOICES*PAN_WIDTH{1'b0}};
        echo_enable = 1'b0;
        echo_delay_samples = 3'd0;
        echo_atten_shift = 4'd1;

        repeat (4) @(posedge clk);
        reset = 1'b0;
        repeat (2) @(posedge clk);

        // Hard-left panning should only drive the left channel.
        load_voice_frame(2'b01, 16'sd1024, 3'd0, 16'sd0, 3'd0);
        pulse_sample_tick();
        if (mono_sample !== 16'sd1024 || left_sample !== 16'sd896 || right_sample !== 16'sd0) begin
            $display("FAIL: hard-left pan mismatch mono=%0d left=%0d right=%0d",
                     mono_sample, left_sample, right_sample);
            $finish;
        end

        // Hard-right panning should only drive the right channel.
        load_voice_frame(2'b01, 16'sd1024, 3'd7, 16'sd0, 3'd0);
        pulse_sample_tick();
        if (mono_sample !== 16'sd1024 || left_sample !== 16'sd0 || right_sample !== 16'sd896) begin
            $display("FAIL: hard-right pan mismatch mono=%0d left=%0d right=%0d",
                     mono_sample, left_sample, right_sample);
            $finish;
        end

        // Clipping should saturate instead of wrapping.
        load_voice_frame(2'b11, 16'sd30000, 3'd0, 16'sd30000, 3'd0);
        pulse_sample_tick();
        if (mono_sample !== 16'sd32767 || left_sample !== 16'sd32767 || right_sample !== 16'sd0) begin
            $display("FAIL: clipping mismatch mono=%0d left=%0d right=%0d",
                     mono_sample, left_sample, right_sample);
            $finish;
        end

        // Echo should replay the delayed mono sample into both channels.
        echo_enable = 1'b1;
        echo_delay_samples = 3'd2;
        echo_atten_shift = 4'd1;

        load_voice_frame(2'b01, 16'sd800, 3'd0, 16'sd0, 3'd0);
        pulse_sample_tick();
        if (left_sample !== 16'sd700 || right_sample !== 16'sd0) begin
            $display("FAIL: dry echo frame mismatch left=%0d right=%0d", left_sample, right_sample);
            $finish;
        end

        load_voice_frame(2'b00, 16'sd0, 3'd0, 16'sd0, 3'd0);
        pulse_sample_tick();
        if (left_sample !== 16'sd0 || right_sample !== 16'sd0) begin
            $display("FAIL: echo arrived too early left=%0d right=%0d", left_sample, right_sample);
            $finish;
        end

        load_voice_frame(2'b00, 16'sd0, 3'd0, 16'sd0, 3'd0);
        pulse_sample_tick();
        if (left_sample !== 16'sd400 || right_sample !== 16'sd400) begin
            $display("FAIL: delayed echo mismatch left=%0d right=%0d", left_sample, right_sample);
            $finish;
        end

        $display("PASS: effects_mixer basic mix, pan, clip, and echo behavior.");
        $finish;
    end

endmodule
