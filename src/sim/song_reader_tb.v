`timescale 1ns/1ps

module song_reader_tb;

    reg clk;
    reg reset;
    reg play;
    reg [1:0] song;
    reg tick_48th;

    wire valid;
    wire [5:0] note;
    wire [5:0] duration;
    wire [2:0] meta;
    wire song_done;

    localparam FETCH   = 3'd1;
    localparam DECODE  = 3'd2;
    localparam WAITING = 3'd4;
    localparam DONE    = 3'd5;

    song_reader dut (
        .clk(clk),
        .reset(reset),
        .play(play),
        .song(song),
        .tick_48th(tick_48th),
        .valid(valid),
        .note(note),
        .duration(duration),
        .meta(meta),
        .song_done(song_done)
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

    task step_cycle;
        begin
            @(posedge clk);
            #1;
        end
    endtask

    task pulse_tick48th;
        begin
            @(negedge clk);
            tick_48th = 1'b1;
            @(posedge clk);
            #1;
            @(negedge clk);
            tick_48th = 1'b0;
        end
    endtask

    task expect_addr;
        input [8:0] expected_addr;
        input [255:0] message;
        begin
            if (dut.song_addr !== expected_addr) begin
                fail(message);
            end
        end
    endtask

    task wait_for_valid_and_check;
        input [5:0] expected_note;
        input [5:0] expected_duration;
        input [2:0] expected_meta;
        input [8:0] expected_addr_after;
        input [255:0] context;
        integer cycles;
        begin
            cycles = 0;
            while (valid !== 1'b1 && cycles < 12) begin
                step_cycle();
                cycles = cycles + 1;
            end

            if (valid !== 1'b1) begin
                fail({"timed out waiting for valid pulse: ", context});
            end

            if (note !== expected_note ||
                duration !== expected_duration ||
                meta !== expected_meta) begin
                fail({"NOTE fields incorrect: ", context});
            end

            if (dut.song_addr !== expected_addr_after) begin
                fail({"song_addr incorrect after NOTE: ", context});
            end

            step_cycle();
            if (valid !== 1'b0) begin
                fail({"valid should only pulse for one cycle: ", context});
            end
        end
    endtask

    task wait_for_waiting_and_check;
        input [5:0] expected_wait;
        input [8:0] expected_addr_after;
        input [255:0] context;
        integer cycles;
        begin
            cycles = 0;
            while (dut.state !== WAITING && cycles < 12) begin
                step_cycle();
                cycles = cycles + 1;
            end

            if (dut.state !== WAITING) begin
                fail({"timed out waiting to enter WAITING: ", context});
            end

            if (dut.wait_counter !== expected_wait) begin
                fail({"wait_counter incorrect: ", context});
            end

            if (dut.song_addr !== expected_addr_after) begin
                fail({"song_addr incorrect after WAIT: ", context});
            end

            if (valid !== 1'b0) begin
                fail({"WAIT event should not assert valid: ", context});
            end
        end
    endtask

    task consume_wait;
        input integer ticks;
        input [255:0] context;
        integer i;
        begin
            for (i = 0; i < ticks-1; i = i + 1) begin
                pulse_tick48th();
                if (dut.state !== WAITING) begin
                    fail({"state left WAITING too early: ", context});
                end
            end

            pulse_tick48th();
            if (dut.state !== FETCH) begin
                fail({"WAITING did not return to FETCH: ", context});
            end
            if (dut.wait_counter !== 6'd0) begin
                fail({"wait_counter did not clear: ", context});
            end
        end
    endtask

    task jump_to_song_end_and_check;
        input [1:0] song_sel;
        input [8:0] end_addr;
        input [255:0] context;
        begin
            song = song_sel;
            step_cycle();

            @(negedge clk);
            dut.song_q    = song_sel;
            dut.song_addr = end_addr;
            dut.state     = FETCH;

            // song_rom is synchronous, so the END word appears a cycle later.
            step_cycle();
            step_cycle();
            step_cycle();

            if (dut.state !== DONE) begin
                fail({"END word did not transition to DONE: ", context});
            end

            step_cycle();
            if (song_done !== 1'b1) begin
                fail({"song_done did not assert in DONE state: ", context});
            end
        end
    endtask

    initial begin
        reset = 1'b1;
        play = 1'b0;
        song = 2'd0;
        tick_48th = 1'b0;

        repeat (3) @(posedge clk);
        reset = 1'b0;
        @(posedge clk);
        #1;

        // Reset should point to the start of song 0 and clear visible outputs.
        if (dut.state !== FETCH) begin
            fail("reset should place state in FETCH");
        end
        expect_addr(9'd0, "song 0 base address should be 0 after reset");

        if (valid !== 1'b0 || song_done !== 1'b0 ||
            note !== 6'd0 || duration !== 6'd0 || meta !== 3'd0) begin
            fail("reset did not clear outputs");
        end

        // With play low, FETCH should stall and the ROM address should not move.
        step_cycle();
        if (dut.state !== FETCH) begin
            fail("FETCH should hold when play=0");
        end
        expect_addr(9'd0, "address should not move when play=0");

        play = 1'b1;

        // Song 0 starts NOTE 49,12,0 then WAIT 12.
        wait_for_valid_and_check(6'd49, 6'd12, 3'd0, 9'd1, "song 0 first note");
        wait_for_waiting_and_check(6'd12, 9'd2, "song 0 first wait");

        // WAITING should hold without a beat tick.
        step_cycle();
        if (dut.state !== WAITING || dut.wait_counter !== 6'd12) begin
            fail("WAITING should hold without tick_48th");
        end

        // WAITING should also freeze while paused.
        play = 1'b0;
        pulse_tick48th();
        if (dut.state !== WAITING || dut.wait_counter !== 6'd12) begin
            fail("WAITING should freeze when play=0");
        end

        play = 1'b1;
        consume_wait(12, "song 0 first wait countdown");
        wait_for_valid_and_check(6'd51, 6'd12, 3'd0, 9'd3, "song 0 second note");

        // Switching songs should jump to that song's base address.
        song = 2'd1;
        step_cycle();
        if (dut.state !== FETCH) begin
            fail("song change to 1 should force FETCH");
        end
        expect_addr(9'd128, "song 1 base address should be 128");

        // Song 1 begins with three consecutive NOTE events, which is how chords
        // are encoded in the ROM before the following WAIT.
        wait_for_valid_and_check(6'd40, 6'd12, 3'd0, 9'd129, "song 1 note 0");
        wait_for_valid_and_check(6'd44, 6'd12, 3'd0, 9'd130, "song 1 note 1");
        wait_for_valid_and_check(6'd47, 6'd12, 3'd0, 9'd131, "song 1 note 2");
        wait_for_waiting_and_check(6'd12, 9'd132, "song 1 wait after chord");

        song = 2'd2;
        step_cycle();
        if (dut.state !== FETCH) begin
            fail("song change to 2 should force FETCH");
        end
        expect_addr(9'd256, "song 2 base address should be 256");
        wait_for_valid_and_check(6'd28, 6'd48, 3'd0, 9'd257, "song 2 first note");
        wait_for_waiting_and_check(6'd12, 9'd258, "song 2 first wait");

        song = 2'd3;
        step_cycle();
        if (dut.state !== FETCH) begin
            fail("song change to 3 should force FETCH");
        end
        expect_addr(9'd384, "song 3 base address should be 384");
        wait_for_valid_and_check(6'd42, 6'd12, 3'd0, 9'd385, "song 3 first note");
        wait_for_waiting_and_check(6'd12, 9'd386, "song 3 first wait");

        // Jump near each END word to check termination without simulating the
        // entire song body.
        jump_to_song_end_and_check(2'd0, 9'd127, "song 0 end");
        jump_to_song_end_and_check(2'd1, 9'd255, "song 1 end");
        jump_to_song_end_and_check(2'd2, 9'd383, "song 2 end");
        jump_to_song_end_and_check(2'd3, 9'd511, "song 3 end");

        $display("PASS: song_reader reset, stall, note decode, wait timing, song switch, chord-adjacent notes, and end-of-song behavior.");
        $finish;
    end

endmodule
