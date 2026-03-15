module wave_display_top(
    input clk,
    input reset,
    input new_sample,
    input [15:0] sample,
    input [1:0] current_song,
    input [5:0] current_note,
    input display_new_note,
    input [6:0] next_note_addr,
    input signed [15:0] voice_root_sample,
    input signed [15:0] voice_third_sample,
    input signed [15:0] voice_fifth_sample,
    input [10:0] x,  // [0..1279]
    input [9:0]  y,  // [0..1023]     
    input valid,
    input vsync,
    output [7:0] r,
    output [7:0] g,
    output [7:0] b
);

    wire [7:0] read_sample, write_sample;
    wire [8:0] read_address, write_address;
    wire read_index;
    wire write_en;
    wire [7:0] read_sample_root, write_sample_root;
    wire [8:0] read_address_root, write_address_root;
    wire read_index_root;
    wire write_en_root;
    wire [7:0] read_sample_third, write_sample_third;
    wire [8:0] read_address_third, write_address_third;
    wire read_index_third;
    wire write_en_third;
    wire [7:0] read_sample_fifth, write_sample_fifth;
    wire [8:0] read_address_fifth, write_address_fifth;
    wire read_index_fifth;
    wire write_en_fifth;
    // wrong because vsync is a synchronnization pulse at the start/end of frames
    //wire wave_display_idle = ~vsync;
    
    // use valid instead as those are the moments when we are in the active visible region, where it is not safe to swap buffer
    // so this will only allow buffer swap when we're not outputting visible pixels
    wire wave_display_idle = ~valid; 

    // captures audio samples to be stored in the RAM
    // swaps buffers only when the display is idle
    wave_capture wc(
        .clk(clk),
        .reset(reset),
        .new_sample_ready(new_sample),
        .new_sample_in(sample), // 16 bit signed audio sample from codec
        .write_address(write_address),
        .write_enable(write_en), // address into sample RAM 
        .write_sample(write_sample), // high when writing
        .wave_display_idle(wave_display_idle), // 8 bit unsigned sample written to RAM
        .read_index(read_index) // which buffer the display reads while the other is writing
    );
    
    wave_capture wc_root(
        .clk(clk),
        .reset(reset),
        .new_sample_ready(new_sample),
        .new_sample_in(voice_root_sample),
        .write_address(write_address_root),
        .write_enable(write_en_root),
        .write_sample(write_sample_root),
        .wave_display_idle(wave_display_idle),
        .read_index(read_index_root)
    );
    
    wave_capture wc_third(
        .clk(clk),
        .reset(reset),
        .new_sample_ready(new_sample),
        .new_sample_in(voice_third_sample),
        .write_address(write_address_third),
        .write_enable(write_en_third),
        .write_sample(write_sample_third),
        .wave_display_idle(wave_display_idle),
        .read_index(read_index_third)
    );
    
    wave_capture wc_fifth(
        .clk(clk),
        .reset(reset),
        .new_sample_ready(new_sample),
        .new_sample_in(voice_fifth_sample),
        .write_address(write_address_fifth),
        .write_enable(write_en_fifth),
        .write_sample(write_sample_fifth),
        .wave_display_idle(wave_display_idle),
        .read_index(read_index_fifth)
    );
    
    // sample RAM: stores waveform samples to be displayed
    // write port driven by wave_capture, read port driven by wave_display
    ram_1w2r #(.WIDTH(8), .DEPTH(9)) sample_ram( // width = 8 bit samples, depth = 9 bit address
        .clka(clk),
        .clkb(clk),
        .wea(write_en), // write enable from wave_capture
        .addra(write_address), 
        .dina(write_sample), // sample data to write
        .douta(), // unused write side read port
        .addrb(read_address), // read address from wave_display
        .doutb(read_sample) // sample value read for display
    );
    
    ram_1w2r #(.WIDTH(8), .DEPTH(9)) sample_ram_root(
        .clka(clk),
        .clkb(clk),
        .wea(write_en_root),
        .addra(write_address_root),
        .dina(write_sample_root),
        .douta(),
        .addrb(read_address_root),
        .doutb(read_sample_root)
    );
    
    ram_1w2r #(.WIDTH(8), .DEPTH(9)) sample_ram_third(
        .clka(clk),
        .clkb(clk),
        .wea(write_en_third),
        .addra(write_address_third),
        .dina(write_sample_third),
        .douta(),
        .addrb(read_address_third),
        .doutb(read_sample_third)
    );
    
    ram_1w2r #(.WIDTH(8), .DEPTH(9)) sample_ram_fifth(
        .clka(clk),
        .clkb(clk),
        .wea(write_en_fifth),
        .addra(write_address_fifth),
        .dina(write_sample_fifth),
        .douta(),
        .addrb(read_address_fifth),
        .doutb(read_sample_fifth)
    );
 
    // converts RAM samples into pixels
    wire valid_pixel;
    wire [7:0] wd_r, wd_g, wd_b;
    wire note_valid_pixel;
    wire [7:0] note_r, note_g, note_b;
    wave_display wd(
        .clk(clk),
        .reset(reset),
        .x(x), // pixel x coordinate from VGA
        .y(y), // pixel y coordinate from VGA
        .valid(valid), // high during the active video region
        .read_address(read_address), // address into the RAM
        .read_value(read_sample), // value read from RAM
        .read_index(read_index), // which buffer to read from
        .read_address_voice0(read_address_root),
        .read_value_voice0(read_sample_root),
        .read_index_voice0(read_index_root),
        .read_address_voice1(read_address_third),
        .read_value_voice1(read_sample_third),
        .read_index_voice1(read_index_third),
        .read_address_voice2(read_address_fifth),
        .read_value_voice2(read_sample_fifth),
        .read_index_voice2(read_index_fifth),
        .valid_pixel(valid_pixel), // high when the pixel should be drawn
        .r(wd_r), .g(wd_g), .b(wd_b) // white RGB to display wave
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
    
    assign {r, g, b} = note_valid_pixel ? {note_r, note_g, note_b} :
                       valid_pixel ? {wd_r, wd_g, wd_b} :
                       {3{8'b0}};

endmodule

