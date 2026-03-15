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

    wire [7:0] read_sample, write_sample;
    wire [8:0] read_address, write_address;
    wire read_index;
    wire write_en;
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
