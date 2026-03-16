//
//  music_player module
//
//  This music_player module connects up the MCU, song_reader, note_player,
//  beat_generator, and codec_conditioner. It provides an output that indicates
//  a new sample (new_sample_generated) which will be used in lab 5.
//

module music_player(
    // Standard system clock and reset
    input clk,
    input reset,

    // Our debounced and one-pulsed button inputs.
    input play_button,
    input next_button,

    // The raw new_frame signal from the ac97_if codec.
    input new_frame,

    // This output must go high for one cycle when a new sample is generated.
    output wire new_sample_generated,

    // Our final output sample to the codec. This needs to be synced to
    // new_frame.
    output wire [15:0] sample_out,
    output wire [15:0] sample_out_right,

    // Display/debug outputs for note visualization.
    output wire [1:0] display_song,
    output wire [5:0] display_note,
    output wire display_new_note,
    output wire [6:0] display_next_addr,
    output wire signed [15:0] display_voice_root_sample,
    output wire signed [15:0] display_voice_third_sample,
    output wire signed [15:0] display_voice_fifth_sample
);
    // The BEAT_COUNT is parameterized so you can reduce this in simulation.
    // If you reduce this to 100 your simulation will be 10x faster.
    parameter BEAT_COUNT = 1000;


//
//  ****************************************************************************
//      Master Control Unit
//  ****************************************************************************
//   The reset_player output from the MCU is run only to the song_reader because
//   we don't need to reset any state in the note_player. If we do it may make
//   a pop when it resets the output sample.
//
 
    wire play;
    wire reset_player;
    wire [1:0] current_song;
    wire song_done;
    mcu mcu(
        .clk(clk),
        .reset(reset),
        .play_button(play_button),
        .next_button(next_button),
        .play(play),
        .reset_player(reset_player),
        .song(current_song),
        .song_done(song_done)
    );

//
//  ****************************************************************************
//      Song Reader
//  ****************************************************************************
//
    wire [5:0] note_to_play;
    wire [5:0] duration_for_note;
    wire new_note;
    wire note_done;
    wire [6:0] next_note_addr;
    song_reader song_reader(
        .clk(clk),
        .reset(reset | reset_player),
        .play(play),
        .song(current_song),
        .song_done(song_done),
        .note(note_to_play),
        .duration(duration_for_note),
        .new_note(new_note),
        .note_done(note_done),
        .next_addr(next_note_addr)
    );

//   
//  ****************************************************************************
//      Multi Voice Player
//  ****************************************************************************
//  
    wire beat;
    wire generate_next_sample, generate_next_sample0;
    wire signed [15:0] voice_root_sample0;
    wire signed [15:0] voice_third_sample0;
    wire signed [15:0] voice_fifth_sample0;
    wire [15:0] left_note_sample, left_note_sample0;
    wire [15:0] right_note_sample, right_note_sample0;
    wire note_sample_ready, note_sample_ready0;
    wire [15:0] echoed_sample_left;
    wire [15:0] echoed_sample_right;
    wire echoed_sample_ready_left;
    wire echoed_sample_ready_right;

    // These pipeline registers were added to decrease the length of the critical path!
    dffr pipeline_ff_gen_next_sample (.clk(clk), .r(reset), .d(generate_next_sample0), .q(generate_next_sample));
    dffr #(.WIDTH(16)) pipeline_ff_left_note_sample (.clk(clk), .r(reset), .d(left_note_sample0), .q(left_note_sample));
    dffr #(.WIDTH(16)) pipeline_ff_right_note_sample (.clk(clk), .r(reset), .d(right_note_sample0), .q(right_note_sample));
    dffr pipeline_ff_new_sample_ready (.clk(clk), .r(reset), .d(note_sample_ready0), .q(note_sample_ready));

    multi_voice_player multi_voice_player(
        .clk(clk),
        .reset(reset),
        .play_enable(play),
        .note_to_load(note_to_play),
        .duration_to_load(duration_for_note),
        .load_new_note(new_note),
        .done_with_note(note_done),
        .beat(beat),
        .generate_next_sample(generate_next_sample),
        .voice_root_sample(voice_root_sample0),
        .voice_third_sample(voice_third_sample0),
        .voice_fifth_sample(voice_fifth_sample0),
        .left_sample_out(left_note_sample0),
        .right_sample_out(right_note_sample0),
        .sample_out(),
        .new_sample_ready(note_sample_ready0)
    );

    echo #(
        .DELAY_SAMPLES(12000),
        .ATTENUATION_SHIFT(2)
    ) echo_processor_left (
        .clk(clk),
        .reset(reset),
        .sample_in(left_note_sample),
        .sample_valid_in(note_sample_ready),
        .sample_out(echoed_sample_left),
        .sample_valid_out(echoed_sample_ready_left)
    );

    echo #(
        .DELAY_SAMPLES(12000),
        .ATTENUATION_SHIFT(2)
    ) echo_processor_right (
        .clk(clk),
        .reset(reset),
        .sample_in(right_note_sample),
        .sample_valid_in(note_sample_ready),
        .sample_out(echoed_sample_right),
        .sample_valid_out(echoed_sample_ready_right)
    );
      
//   
//  ****************************************************************************
//      Beat Generator
//  ****************************************************************************
//  By default this will divide the generate_next_sample signal (48kHz from the
//  codec's new_frame input) down by 1000, to 48Hz. If you change the BEAT_COUNT
//  parameter when instantiating this you can change it for simulation.
//  
    beat_generator #(.WIDTH(10), .STOP(BEAT_COUNT)) beat_generator(
        .clk(clk),
        .reset(reset),
        .en(generate_next_sample),
        .beat(beat)
    );

//  
//  ****************************************************************************
//      Codec Conditioner
//  ****************************************************************************
//  
    wire new_sample_generated0;
    wire [15:0] sample_out0;
    wire [15:0] sample_out1;

    dffr pipeline_ff_nsg (.clk(clk), .r(reset), .d(new_sample_generated0), .q(new_sample_generated));
    assign sample_out = sample_out0;
    assign sample_out_right = sample_out1;

    assign new_sample_generated0 = generate_next_sample;
    codec_conditioner codec_conditioner_left(
        .clk(clk),
        .reset(reset),
        .new_sample_in(echoed_sample_left),
        .latch_new_sample_in(echoed_sample_ready_left),
        .generate_next_sample(generate_next_sample0),
        .new_frame(new_frame),
        .valid_sample(sample_out0)
    );

    codec_conditioner codec_conditioner_right(
        .clk(clk),
        .reset(reset),
        .new_sample_in(echoed_sample_right),
        .latch_new_sample_in(echoed_sample_ready_right),
        .generate_next_sample(),
        .new_frame(new_frame),
        .valid_sample(sample_out1)
    );

    assign display_song = current_song;
    assign display_note = note_to_play;
    assign display_new_note = new_note;
    assign display_next_addr = next_note_addr;
    assign display_voice_root_sample = voice_root_sample0;
    assign display_voice_third_sample = voice_third_sample0;
    assign display_voice_fifth_sample = voice_fifth_sample0;

endmodule
