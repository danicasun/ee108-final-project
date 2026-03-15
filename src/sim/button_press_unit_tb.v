`timescale 1ns/1ps

module button_press_unit_tb;
    reg clk;
    reg reset;
    reg in;
    wire out;

    integer pulse_count;

    button_press_unit #(.WIDTH(2)) dut (
        .clk(clk),
        .reset(reset),
        .in(in),
        .out(out)
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

    task hold_cycles;
        input integer cycles;
        integer i;
        begin
            for (i = 0; i < cycles; i = i + 1) begin
                @(posedge clk);
                #1;
            end
        end
    endtask

    task press_button;
        begin
            in = 1'b1;
            hold_cycles(6);
            in = 1'b0;
            hold_cycles(6);
        end
    endtask

    always @(posedge clk) begin
        if (out) begin
            pulse_count <= pulse_count + 1;
        end
    end

    initial begin
        reset = 1'b1;
        in = 1'b0;
        pulse_count = 0;

        hold_cycles(3);
        reset = 1'b0;
        hold_cycles(2);

        press_button();
        if (pulse_count !== 1) begin
            fail("first button press should create exactly one pulse");
        end

        press_button();
        if (pulse_count !== 2) begin
            fail("second button press should create exactly one additional pulse");
        end

        hold_cycles(4);
        if (out !== 1'b0) begin
            fail("out should return low after the pulse");
        end

        $display("PASS: button_press_unit emits one pulse per debounced press.");
        $finish;
    end
endmodule
