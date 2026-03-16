module wave_display_top(
    input clk,
    input reset,
    input new_sample,
    input [15:0] sample,
    input [1:0] current_song,
    input [5:0] current_note,
    input display_new_note,
    input [6:0] next_note_addr,
    input [10:0] x,  // [0..1279]
    input [9:0]  y,  // [0..1023]     
    input valid,
    input vsync,
    output [7:0] r,
    output [7:0] g,
    output [7:0] b
);

    function [5:0] chord_tone;
        input [5:0] root_note;
        input [5:0] interval;
        reg [6:0] shifted_note;
        begin
            if (root_note == 6'd0) begin
                chord_tone = 6'd0;
            end else begin
                shifted_note = root_note + interval;
                if (shifted_note <= 7'd63) begin
                    chord_tone = shifted_note[5:0];
                end else begin
                    chord_tone = 6'd0;
                end
            end
        end
    endfunction

    function [7:0] captured_sample;
        input [15:0] sample_in;
        begin
            captured_sample = sample_in[15:8] + 8'd128;
        end
    endfunction

    localparam [7:0] ROOT_R  = 8'hFF;
    localparam [7:0] ROOT_G  = 8'h50;
    localparam [7:0] ROOT_B  = 8'h40;
    localparam [7:0] THIRD_R = 8'h40;
    localparam [7:0] THIRD_G = 8'hFF;
    localparam [7:0] THIRD_B = 8'h70;
    localparam [7:0] FIFTH_R = 8'h50;
    localparam [7:0] FIFTH_G = 8'h90;
    localparam [7:0] FIFTH_B = 8'hFF;

    wire [7:0] mix_read_sample;
    wire [7:0] root_read_sample;
    wire [7:0] third_read_sample;
    wire [7:0] fifth_read_sample;
    wire [8:0] mix_read_address;
    wire [8:0] root_read_address;
    wire [8:0] third_read_address;
    wire [8:0] fifth_read_address;
    wire [8:0] write_address;
    wire read_index;
    wire write_en;
    reg [1:0] song_q;
    reg [5:0] active_root_note;
    reg [8:0] preview_write_address_d1;
    reg [8:0] preview_write_address_d2;
    reg preview_write_en_d1;
    reg preview_write_en_d2;
    // wrong because vsync is a synchronnization pulse at the start/end of frames
    //wire wave_display_idle = ~vsync;
    
    // use valid instead as those are the moments when we are in the active visible region, where it is not safe to swap buffer
    // so this will only allow buffer swap when we're not outputting visible pixels
    wire wave_display_idle = ~valid; 
    wire song_change = (current_song != song_q);

    // Track the currently displayed root note and delay the write address so the
    // display-only preview waveforms line up with the existing sample capture.
    always @(posedge clk) begin
        if (reset) begin
            song_q <= 2'd0;
            active_root_note <= 6'd0;
            preview_write_address_d1 <= 9'd0;
            preview_write_address_d2 <= 9'd0;
            preview_write_en_d1 <= 1'b0;
            preview_write_en_d2 <= 1'b0;
        end else begin
            song_q <= current_song;
            if (song_change) begin
                active_root_note <= 6'd0;
            end else if (display_new_note) begin
                active_root_note <= current_note;
            end

            preview_write_address_d1 <= write_address;
            preview_write_address_d2 <= preview_write_address_d1;
            preview_write_en_d1 <= write_en;
            preview_write_en_d2 <= preview_write_en_d1;
        end
    end

    wire low_register_note = (active_root_note != 6'd0) && (active_root_note < 6'd28);
    wire very_low_register_note = (active_root_note != 6'd0) && (active_root_note < 6'd20);
    wire [5:0] third_interval = low_register_note ? 6'd16 : 6'd4;
    wire [5:0] fifth_interval = low_register_note ? 6'd19 : 6'd7;
    wire [5:0] active_third_note = very_low_register_note ? 6'd0 : chord_tone(active_root_note, third_interval);
    wire [5:0] active_fifth_note = chord_tone(active_root_note, fifth_interval);

    wire [19:0] root_step_size;
    wire [19:0] third_step_size;
    wire [19:0] fifth_step_size;
    wire [15:0] root_preview_raw;
    wire [15:0] third_preview_raw;
    wire [15:0] fifth_preview_raw;
    wire root_preview_ready;
    wire third_preview_ready;
    wire fifth_preview_ready;

    frequency_rom root_freq_rom(
        .clk(clk),
        .addr(active_root_note),
        .dout(root_step_size)
    );

    frequency_rom third_freq_rom(
        .clk(clk),
        .addr(active_third_note),
        .dout(third_step_size)
    );

    frequency_rom fifth_freq_rom(
        .clk(clk),
        .addr(active_fifth_note),
        .dout(fifth_step_size)
    );

    harmonics root_preview(
        .clk(clk),
        .reset(reset | song_change),
        .step_size(root_step_size),
        .generate_next(new_sample),
        .sample_ready(root_preview_ready),
        .sample(root_preview_raw)
    );

    harmonics third_preview(
        .clk(clk),
        .reset(reset | song_change),
        .step_size(third_step_size),
        .generate_next(new_sample),
        .sample_ready(third_preview_ready),
        .sample(third_preview_raw)
    );

    harmonics fifth_preview(
        .clk(clk),
        .reset(reset | song_change),
        .step_size(fifth_step_size),
        .generate_next(new_sample),
        .sample_ready(fifth_preview_ready),
        .sample(fifth_preview_raw)
    );

    wire signed [15:0] root_preview_sample = $signed(root_preview_raw) >>> 1;
    wire signed [15:0] third_preview_sample =
        very_low_register_note ? 16'sd0 :
        low_register_note ? ($signed(third_preview_raw) >>> 3) >>> 1 :
        ($signed(third_preview_raw) >>> 1) >>> 1;
    wire signed [15:0] fifth_preview_sample =
        very_low_register_note ? ($signed(fifth_preview_raw) >>> 3) >>> 1 :
        low_register_note ? ($signed(fifth_preview_raw) >>> 2) >>> 1 :
        ($signed(fifth_preview_raw) >>> 1) >>> 1;
    wire preview_write_en = preview_write_en_d2 & root_preview_ready & third_preview_ready & fifth_preview_ready;

    // captures audio samples to be stored in the RAM
    // swaps buffers only when the display is idle
    wave_capture wc(
        .clk(clk),
        .reset(reset),
        .new_sample_ready(new_sample),
        .new_sample_in(sample), // 16 bit signed audio sample from codec
        .write_address(write_address),
        .write_enable(write_en), // address into sample RAM 
        .wave_display_idle(wave_display_idle), // 8 bit unsigned sample written to RAM
        .read_index(read_index) // which buffer the display reads while the other is writing
    );
    
    ram_1w2r #(.WIDTH(8), .DEPTH(9)) mixed_sample_ram(
        .clka(clk),
        .clkb(clk),
        .wea(write_en), // write enable from wave_capture
        .addra(write_address), 
        .dina(captured_sample(sample)), // sample data to write
        .douta(), // unused write side read port
        .addrb(mix_read_address), // read address from wave_display
        .doutb(mix_read_sample) // sample value read for display
    );

    ram_1w2r #(.WIDTH(8), .DEPTH(9)) root_sample_ram(
        .clka(clk),
        .clkb(clk),
        .wea(preview_write_en),
        .addra(preview_write_address_d2),
        .dina(captured_sample(root_preview_sample)),
        .douta(),
        .addrb(root_read_address),
        .doutb(root_read_sample)
    );

    ram_1w2r #(.WIDTH(8), .DEPTH(9)) third_sample_ram(
        .clka(clk),
        .clkb(clk),
        .wea(preview_write_en),
        .addra(preview_write_address_d2),
        .dina(captured_sample(third_preview_sample)),
        .douta(),
        .addrb(third_read_address),
        .doutb(third_read_sample)
    );

    ram_1w2r #(.WIDTH(8), .DEPTH(9)) fifth_sample_ram(
        .clka(clk),
        .clkb(clk),
        .wea(preview_write_en),
        .addra(preview_write_address_d2),
        .dina(captured_sample(fifth_preview_sample)),
        .douta(),
        .addrb(fifth_read_address),
        .doutb(fifth_read_sample)
    );
 
    // Convert each stored waveform into a colored display layer.
    wire mixed_valid_pixel;
    wire [7:0] mixed_r, mixed_g, mixed_b;
    wire root_valid_pixel;
    wire [7:0] root_r, root_g, root_b;
    wire third_valid_pixel;
    wire [7:0] third_r, third_g, third_b;
    wire fifth_valid_pixel;
    wire [7:0] fifth_r, fifth_g, fifth_b;
    wire note_valid_pixel;
    wire [7:0] note_r, note_g, note_b;

    wave_display wd_mix(
        .clk(clk),
        .reset(reset),
        .x(x), // pixel x coordinate from VGA
        .y(y), // pixel y coordinate from VGA
        .valid(valid), // high during the active video region
        .read_address(mix_read_address), // address into the RAM
        .read_value(mix_read_sample), // value read from RAM
        .read_index(read_index), // which buffer to read from
        .trace_r(8'hFF),
        .trace_g(8'hFF),
        .trace_b(8'hFF),
        .valid_pixel(mixed_valid_pixel),
        .r(mixed_r),
        .g(mixed_g),
        .b(mixed_b)
    );

    wave_display wd_root(
        .clk(clk),
        .reset(reset),
        .x(x),
        .y(y),
        .valid(valid),
        .read_address(root_read_address),
        .read_value(root_read_sample),
        .read_index(read_index),
        .trace_r(ROOT_R),
        .trace_g(ROOT_G),
        .trace_b(ROOT_B),
        .valid_pixel(root_valid_pixel),
        .r(root_r),
        .g(root_g),
        .b(root_b)
    );

    wave_display wd_third(
        .clk(clk),
        .reset(reset),
        .x(x),
        .y(y),
        .valid(valid),
        .read_address(third_read_address),
        .read_value(third_read_sample),
        .read_index(read_index),
        .trace_r(THIRD_R),
        .trace_g(THIRD_G),
        .trace_b(THIRD_B),
        .valid_pixel(third_valid_pixel),
        .r(third_r),
        .g(third_g),
        .b(third_b)
    );

    wave_display wd_fifth(
        .clk(clk),
        .reset(reset),
        .x(x),
        .y(y),
        .valid(valid),
        .read_address(fifth_read_address),
        .read_value(fifth_read_sample),
        .read_index(read_index),
        .trace_r(FIFTH_R),
        .trace_g(FIFTH_G),
        .trace_b(FIFTH_B),
        .valid_pixel(fifth_valid_pixel),
        .r(fifth_r),
        .g(fifth_g),
        .b(fifth_b)
    );

    note_display nd(
        .clk(clk),
        .reset(reset),
        .x(x),
        .y(y),
        .valid(valid),
        .current_song(current_song),
        .current_note(current_note),
        .new_note(display_new_note),
        .next_note_addr(next_note_addr),
        .valid_pixel(note_valid_pixel),
        .r(note_r),
        .g(note_g),
        .b(note_b)
    );

    wire [7:0] wave_r = mixed_r | root_r | third_r | fifth_r;
    wire [7:0] wave_g = mixed_g | root_g | third_g | fifth_g;
    wire [7:0] wave_b = mixed_b | root_b | third_b | fifth_b;
    
    assign {r, g, b} = note_valid_pixel ? {note_r, note_g, note_b} :
                       (mixed_valid_pixel | root_valid_pixel | third_valid_pixel | fifth_valid_pixel) ? {wave_r, wave_g, wave_b} :
                       {3{8'b0}};

endmodule
