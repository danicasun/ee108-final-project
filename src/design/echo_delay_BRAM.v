module echo_delay_BRAM #(
    parameter integer SAMPLE_WIDTH = 16,
    parameter integer MAX_DELAY_SAMPLES = 24000,
    parameter integer ECHO_ADDR_WIDTH = 15
)(
    input clk,
    input reset,
    input enable,
    input sample_tick,
    input signed [SAMPLE_WIDTH-1:0] sample_in,
    input [ECHO_ADDR_WIDTH-1:0] delay_samples,
    output wire delayed_valid,
    output wire signed [SAMPLE_WIDTH-1:0] delayed_sample
);

    parameter [ECHO_ADDR_WIDTH-1:0] LAST_ECHO_ADDR = MAX_DELAY_SAMPLES - 1;
    parameter [ECHO_ADDR_WIDTH:0] MAX_DELAY_COUNT = MAX_DELAY_SAMPLES;

    reg [ECHO_ADDR_WIDTH-1:0] write_addr;
    reg [ECHO_ADDR_WIDTH-1:0] read_addr;
    reg [ECHO_ADDR_WIDTH:0] fill_count;
    reg [ECHO_ADDR_WIDTH:0] wrapped_read_addr;
    reg [ECHO_ADDR_WIDTH-1:0] previous_delay_samples;

    wire [ECHO_ADDR_WIDTH-1:0] bounded_delay_samples =
        (delay_samples > LAST_ECHO_ADDR) ? LAST_ECHO_ADDR : delay_samples;
    wire [ECHO_ADDR_WIDTH:0] bounded_delay_ext = {1'b0, bounded_delay_samples};
    wire [ECHO_ADDR_WIDTH:0] write_addr_ext = {1'b0, write_addr};
    wire delay_enabled = enable && (bounded_delay_samples != {ECHO_ADDR_WIDTH{1'b0}});
    wire delay_changed = (bounded_delay_samples != previous_delay_samples);

    always @(*) begin
        wrapped_read_addr = {ECHO_ADDR_WIDTH+1{1'b0}};

        if (!delay_enabled) begin
            read_addr = {ECHO_ADDR_WIDTH{1'b0}};
        end else if (write_addr_ext >= bounded_delay_ext) begin
            read_addr = write_addr - bounded_delay_samples;
        end else begin
            wrapped_read_addr = write_addr_ext + MAX_DELAY_COUNT - bounded_delay_ext;
            read_addr = wrapped_read_addr[ECHO_ADDR_WIDTH-1:0];
        end
    end

    wire [SAMPLE_WIDTH-1:0] delayed_sample_bits;

    ram_1w2r #(
        .WIDTH(SAMPLE_WIDTH),
        .DEPTH(ECHO_ADDR_WIDTH)
    ) echo_ram (
        .clka(clk),
        .wea(sample_tick && delay_enabled),
        .addra(write_addr),
        .dina(sample_in),
        .douta(),
        .clkb(clk),
        .addrb(read_addr),
        .doutb(delayed_sample_bits)
    );

    assign delayed_valid = delay_enabled && (fill_count >= bounded_delay_ext);
    assign delayed_sample = delayed_valid ? $signed(delayed_sample_bits) : {SAMPLE_WIDTH{1'b0}};

    always @(posedge clk) begin
        if (reset) begin
            write_addr <= {ECHO_ADDR_WIDTH{1'b0}};
            fill_count <= {ECHO_ADDR_WIDTH+1{1'b0}};
            previous_delay_samples <= {ECHO_ADDR_WIDTH{1'b0}};
        end else if (!delay_enabled || delay_changed) begin
            previous_delay_samples <= bounded_delay_samples;
            if (delay_enabled && sample_tick) begin
                if (LAST_ECHO_ADDR == {ECHO_ADDR_WIDTH{1'b0}}) begin
                    write_addr <= {ECHO_ADDR_WIDTH{1'b0}};
                end else begin
                    write_addr <= {{ECHO_ADDR_WIDTH-1{1'b0}}, 1'b1};
                end
                fill_count <= {{ECHO_ADDR_WIDTH{1'b0}}, 1'b1};
            end else begin
                write_addr <= {ECHO_ADDR_WIDTH{1'b0}};
                fill_count <= {ECHO_ADDR_WIDTH+1{1'b0}};
            end
        end else if (sample_tick) begin
            if (fill_count < MAX_DELAY_COUNT) begin
                fill_count <= fill_count + 1'b1;
            end

            if (write_addr == LAST_ECHO_ADDR) begin
                write_addr <= {ECHO_ADDR_WIDTH{1'b0}};
            end else begin
                write_addr <= write_addr + 1'b1;
            end

            previous_delay_samples <= bounded_delay_samples;
        end else begin
            previous_delay_samples <= bounded_delay_samples;
        end
    end

endmodule
