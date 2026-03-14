`timescale 1ns/1ps

module harmonics_tb;
    localparam PHASE_W = 20;
    localparam SAMPLE_W = 16;
    localparam W_SHIFT = 5;

    reg clk;
    reg reset;
    reg active;
    reg gen_next;
    reg [PHASE_W-1:0] step_size;
    reg [2:0] meta;

    wire [SAMPLE_W-1:0] sample;
    wire sample_ready;

    wire do_gen = gen_next && active;
    wire [PHASE_W-1:0] step1 = step_size;
    wire [PHASE_W-1:0] step2 = step_size << 1;
    wire [PHASE_W-1:0] step3 = step_size + (step_size << 1);
    wire [PHASE_W-1:0] step4 = step_size << 2;

    wire [SAMPLE_W-1:0] ref_s1, ref_s2, ref_s3, ref_s4;
    wire ref_r1, ref_r2, ref_r3, ref_r4;
    wire ref_valid = ref_r1 & ref_r2 & ref_r3 & ref_r4;

    harmonics #(
        .PHASE_W(PHASE_W),
        .SAMPLE_W(SAMPLE_W),
        .W_SHIFT(W_SHIFT)
    ) dut (
        .clk(clk),
        .reset(reset),
        .active(active),
        .gen_next(gen_next),
        .step_size(step_size),
        .meta(meta),
        .sample(sample),
        .sample_ready(sample_ready)
    );

    sine_reader ref1 (
        .clk(clk),
        .reset(reset),
        .step_size(step1),
        .generate_next(do_gen),
        .sample_ready(ref_r1),
        .sample(ref_s1)
    );

    sine_reader ref2 (
        .clk(clk),
        .reset(reset),
        .step_size(step2),
        .generate_next(do_gen),
        .sample_ready(ref_r2),
        .sample(ref_s2)
    );

    sine_reader ref3 (
        .clk(clk),
        .reset(reset),
        .step_size(step3),
        .generate_next(do_gen),
        .sample_ready(ref_r3),
        .sample(ref_s3)
    );

    sine_reader ref4 (
        .clk(clk),
        .reset(reset),
        .step_size(step4),
        .generate_next(do_gen),
        .sample_ready(ref_r4),
        .sample(ref_s4)
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

    task pulse_gen_next;
        begin
            @(negedge clk);
            gen_next = 1'b1;
            @(negedge clk);
            gen_next = 1'b0;
        end
    endtask

    function integer weight1;
        input [2:0] meta_in;
        begin
            case (meta_in)
                3'b000: weight1 = 32;
                3'b001: weight1 = 24;
                3'b010: weight1 = 20;
                3'b011: weight1 = 24;
                3'b100: weight1 = 16;
                3'b101: weight1 = 20;
                3'b110: weight1 = 16;
                3'b111: weight1 = 28;
                default: weight1 = 32;
            endcase
        end
    endfunction

    function integer weight2;
        input [2:0] meta_in;
        begin
            case (meta_in)
                3'b001: weight2 = 8;
                3'b010: weight2 = 8;
                3'b100: weight2 = 8;
                3'b110: weight2 = 8;
                3'b111: weight2 = 4;
                default: weight2 = 0;
            endcase
        end
    endfunction

    function integer weight3;
        input [2:0] meta_in;
        begin
            case (meta_in)
                3'b010: weight3 = 4;
                3'b011: weight3 = 8;
                3'b100: weight3 = 4;
                3'b110: weight3 = 6;
                default: weight3 = 0;
            endcase
        end
    endfunction

    function integer weight4;
        input [2:0] meta_in;
        begin
            case (meta_in)
                3'b100: weight4 = 4;
                3'b101: weight4 = 8;
                3'b110: weight4 = 2;
                default: weight4 = 0;
            endcase
        end
    endfunction

    function integer sample_to_int;
        input [15:0] sample_bits;
        begin
            sample_to_int = $signed(sample_bits);
        end
    endfunction

    function [15:0] clip16_bits;
        input integer mixed_sample;
        begin
            if (mixed_sample > 32767) begin
                clip16_bits = 16'sh7fff;
            end else if (mixed_sample < -32768) begin
                clip16_bits = 16'sh8000;
            end else begin
                clip16_bits = mixed_sample[15:0];
            end
        end
    endfunction

    integer expected_mix;
    reg [15:0] expected_sample;
    integer checked_samples;
    reg saw_harmonic_difference;
    reg expected_valid_d0;
    reg expected_valid_d1;
    reg [15:0] expected_sample_d0;
    reg [15:0] expected_sample_d1;

    always @(posedge clk) begin
        #1;
        if (!reset && sample_ready && !expected_valid_d1) begin
            fail("sample_ready asserted without aligned reference samples");
        end

        if (!reset && expected_valid_d1) begin
            if (sample_ready !== 1'b1) begin
                fail("harmonics missed a valid mixed sample");
            end

            if ($signed(sample) !== $signed(expected_sample_d1)) begin
                fail("harmonics sample does not match the weighted reference mix");
            end

            checked_samples = checked_samples + 1;
        end

        expected_valid_d1 = expected_valid_d0;
        expected_sample_d1 = expected_sample_d0;
        expected_valid_d0 = 1'b0;
        expected_sample_d0 = 16'd0;

        if (!reset && active && ref_valid) begin
            expected_mix =
                (sample_to_int(ref_s1) * weight1(meta)) +
                (sample_to_int(ref_s2) * weight2(meta)) +
                (sample_to_int(ref_s3) * weight3(meta)) +
                (sample_to_int(ref_s4) * weight4(meta));
            expected_mix = expected_mix >>> W_SHIFT;
            expected_sample = clip16_bits(expected_mix);
            expected_valid_d0 = 1'b1;
            expected_sample_d0 = expected_sample;

            if (meta != 3'b000 && $signed(expected_sample) !== $signed(ref_s1)) begin
                saw_harmonic_difference = 1'b1;
            end
        end
    end

    initial begin
        reset = 1'b1;
        active = 1'b0;
        gen_next = 1'b0;
        step_size = 20'd4096;
        meta = 3'b000;
        checked_samples = 0;
        saw_harmonic_difference = 1'b0;
        expected_valid_d0 = 1'b0;
        expected_valid_d1 = 1'b0;
        expected_sample_d0 = 16'd0;
        expected_sample_d1 = 16'd0;
        expected_mix = 0;
        expected_sample = 16'd0;

        repeat (3) @(posedge clk);
        reset = 1'b0;
        repeat (2) @(posedge clk);

        repeat (3) pulse_gen_next();
        repeat (3) @(posedge clk);
        if (sample_ready !== 1'b0 || sample !== 16'd0) begin
            fail("inactive harmonics should stay quiet");
        end

        active = 1'b1;
        meta = 3'b000;
        checked_samples = 0;

        repeat (8) pulse_gen_next();
        repeat (4) @(posedge clk);
        if (checked_samples < 4) begin
            fail("pure-fundamental case did not produce enough checked samples");
        end

        reset = 1'b1;
        active = 1'b0;
        gen_next = 1'b0;
        repeat (2) @(posedge clk);
        reset = 1'b0;
        repeat (2) @(posedge clk);

        active = 1'b1;
        meta = 3'b100;
        checked_samples = 0;
        saw_harmonic_difference = 1'b0;

        repeat (8) pulse_gen_next();
        repeat (4) @(posedge clk);
        if (checked_samples < 4) begin
            fail("multi-harmonic case did not produce enough checked samples");
        end

        if (!saw_harmonic_difference) begin
            fail("multi-harmonic meta setting never differed from the fundamental-only output");
        end

        active = 1'b0;
        repeat (2) @(posedge clk);
        if (sample_ready !== 1'b0 || sample !== 16'd0) begin
            fail("harmonics should return to zero when inactive");
        end

        $display("PASS: harmonics gating, ready timing, and weighted mixing behavior.");
        $finish;
    end

endmodule
