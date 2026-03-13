`timescale 1ns/1ps

module multi_voice_player_tb;
    reg clk;
    reg reset;
    reg [5:0] note_in;
    reg [5:0] duration;
    reg [2:0] meta;
    reg gen_next;
    reg tick48th;
    reg schedule_note;

    wire [15:0] out;
    wire [3:0] voices_active;
    wire [3:0] load_voice;

    multi_voice_player dut (
        .clk(clk),
        .reset(reset),
        .note_in(note_in),
        .duration(duration),
        .meta(meta),
        .gen_next(gen_next),
        .tick48th(tick48th),
        .schedule_note(schedule_note),
        .out(out),
        .voices_active(voices_active),
        .load_voice(load_voice)
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

    task pulse_tick48th;
        begin
            @(negedge clk);
            tick48th = 1'b1;
            @(posedge clk);
            #1;
            @(negedge clk);
            tick48th = 1'b0;
        end
    endtask

    task pulse_gen_next;
        begin
            @(negedge clk);
            gen_next = 1'b1;
            @(posedge clk);
            #1;
            @(negedge clk);
            gen_next = 1'b0;
        end
    endtask

    task schedule_note_and_check;
        input [5:0] note_value;
        input [5:0] duration_value;
        input [2:0] meta_value;
        input [3:0] expected_active;
        input [3:0] expected_load;
        begin
            @(negedge clk);
            note_in = note_value;
            duration = duration_value;
            meta = meta_value;
            schedule_note = 1'b1;
            @(posedge clk);
            #1;
            if (voices_active !== expected_active || load_voice !== expected_load) begin
                fail("voice allocation or load pulse mismatch");
            end
            @(negedge clk);
            schedule_note = 1'b0;
            @(posedge clk);
            #1;
            if (load_voice !== 4'b0000) begin
                fail("load_voice should be a one-cycle pulse");
            end
        end
    endtask

    function integer sample_to_int;
        input [15:0] sample_bits;
        begin
            sample_to_int = $signed(sample_bits);
        end
    endfunction

    task check_mix_matches_internal;
        integer mix_sum;
        integer expected_out;
        begin
            mix_sum = 0;
            if (voices_active[0]) mix_sum = mix_sum + sample_to_int(dut.dyn0);
            if (voices_active[1]) mix_sum = mix_sum + sample_to_int(dut.dyn1);
            if (voices_active[2]) mix_sum = mix_sum + sample_to_int(dut.dyn2);
            if (voices_active[3]) mix_sum = mix_sum + sample_to_int(dut.dyn3);
            expected_out = mix_sum >>> 2;

            if ($signed(out) !== expected_out[15:0]) begin
                fail("output mix does not match the internal voice sum");
            end
        end
    endtask

    integer wait_cycles;
    reg saw_negative_dyn;

    initial begin
        reset = 1'b1;
        note_in = 6'd0;
        duration = 6'd0;
        meta = 3'd0;
        gen_next = 1'b0;
        tick48th = 1'b0;
        schedule_note = 1'b0;
        wait_cycles = 0;
        saw_negative_dyn = 1'b0;

        repeat (3) @(posedge clk);
        reset = 1'b0;
        @(posedge clk);
        #1;

        if (voices_active !== 4'b0000 || load_voice !== 4'b0000 || out !== 16'd0) begin
            fail("reset did not clear the multi_voice_player state");
        end

        schedule_note_and_check(6'd10, 6'd4, 3'd1, 4'b0001, 4'b0001);
        if (dut.note0 !== 6'd10 || dut.dur0 !== 6'd4 || dut.meta0 !== 3'd1) begin
            fail("voice 0 did not capture the first scheduled note");
        end

        schedule_note_and_check(6'd12, 6'd1, 3'd2, 4'b0011, 4'b0010);
        if (dut.note1 !== 6'd12 || dut.dur1 !== 6'd1 || dut.meta1 !== 3'd2) begin
            fail("voice 1 did not capture the second scheduled note");
        end

        schedule_note_and_check(6'd14, 6'd6, 3'd3, 4'b0111, 4'b0100);
        if (dut.note2 !== 6'd14 || dut.dur2 !== 6'd6 || dut.meta2 !== 3'd3) begin
            fail("voice 2 did not capture the third scheduled note");
        end

        schedule_note_and_check(6'd16, 6'd7, 3'd4, 4'b1111, 4'b1000);
        if (dut.note3 !== 6'd16 || dut.dur3 !== 6'd7 || dut.meta3 !== 3'd4) begin
            fail("voice 3 did not capture the fourth scheduled note");
        end

        @(negedge clk);
        note_in = 6'd18;
        duration = 6'd8;
        meta = 3'd5;
        schedule_note = 1'b1;
        @(posedge clk);
        #1;
        if (voices_active !== 4'b1111 || load_voice !== 4'b0000) begin
            fail("full voice set should not allocate an extra voice");
        end
        @(negedge clk);
        schedule_note = 1'b0;

        pulse_tick48th();
        if (dut.dur0 !== 6'd3 || dut.dur1 !== 6'd0 || dut.dur2 !== 6'd5 || dut.dur3 !== 6'd6) begin
            fail("tick48th did not decrement all active durations");
        end

        repeat (8) pulse_gen_next();
        repeat (4) begin
            @(posedge clk);
            #1;
            if (out !== 16'd0) begin
                check_mix_matches_internal();
            end
        end

        saw_negative_dyn = 1'b0;
        repeat (16) begin
            pulse_gen_next();
            @(posedge clk);
            #1;
            if ($signed(dut.dyn0) < 0 || $signed(dut.dyn1) < 0 ||
                $signed(dut.dyn2) < 0 || $signed(dut.dyn3) < 0) begin
                saw_negative_dyn = 1'b1;
                check_mix_matches_internal();
            end
        end

        if (!saw_negative_dyn) begin
            fail("did not observe a negative voice sample during mix testing");
        end

        wait_cycles = 0;
        while (voices_active[1] && wait_cycles < 16) begin
            @(posedge clk);
            #1;
            wait_cycles = wait_cycles + 1;
        end

        if (voices_active !== 4'b1101 || dut.dur1 !== 6'd0) begin
            fail("voice 1 did not release after note completion");
        end

        schedule_note_and_check(6'd20, 6'd9, 3'd6, 4'b1111, 4'b0010);
        if (dut.note1 !== 6'd20 || dut.dur1 !== 6'd9 || dut.meta1 !== 3'd6) begin
            fail("freed voice slot was not reused by the next note");
        end

        $display("PASS: multi_voice_player allocation, duration, reuse, and signed mix behavior.");
        $finish;
    end

endmodule
