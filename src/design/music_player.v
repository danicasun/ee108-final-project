//
//  music_player module
//
//  This music_player module connects up the MCU, song_reader,
//  multi_voice_player, beat_generator, and codec_conditioner. It provides an
//  output that indicates a new sample (new_sample_generated) which will be
//  used in lab 5.
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
    output wire [15:0] sample_out
);
    parameter BEAT_COUNT = 1000;
    parameter SAMPLE_PIPELINE_LATENCY = 7;
    parameter EFFECTS_INPUT_CAPTURE_DELAY = 4;
    parameter EFFECTS_SAMPLE_DELAY = 5;
    parameter EFFECTS_NUM_VOICES = 4;
    parameter EFFECTS_PAN_WIDTH = 3;
    parameter EFFECTS_ECHO_ADDR_WIDTH = 15;
    parameter EFFECTS_ECHO_DELAY_SAMPLES = 15'd6000;
    parameter EFFECTS_ECHO_ATTEN_SHIFT = 4'd2;


//
//  ****************************************************************************
//      Master Control Unit
//  ****************************************************************************
//   reset_player clears the reader and active voices when the user changes
//   songs or playback reaches the end of the current song.
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
    wire [2:0] note_meta;
    wire schedule_note;
    wire tick_48th;
    song_reader song_reader(
        .clk(clk),
        .reset(reset | reset_player),
        .play(play),
        .song(current_song),
        .tick_48th(tick_48th),
        .valid(schedule_note),
        .note(note_to_play),
        .duration(duration_for_note),
        .meta(note_meta),
        .song_done(song_done)
    );

//   
//  ****************************************************************************
//      Voice Player
//  ****************************************************************************
//  
    wire generate_next_sample;
    wire generate_next_sample_raw;
    wire [15:0] dry_sample_raw;
    wire [3:0] voices_active;
    wire [3:0] load_voice;
    wire [EFFECTS_NUM_VOICES*16-1:0] voice_samples_packed;
    reg [3:0] effects_voice_active;
    reg [EFFECTS_NUM_VOICES*16-1:0] effects_voice_samples;

    multi_voice_player multi_voice_player(
        .clk(clk),
        .reset(reset | reset_player),
        .note_in(note_to_play),
        .duration(duration_for_note),
        .meta(note_meta),
        .gen_next(generate_next_sample),
        .tick48th(tick_48th),
        .schedule_note(schedule_note),
        .out(dry_sample_raw),
        .voices_active(voices_active),
        .note0(),
        .note1(),
        .note2(),
        .note3(),
        .load_voice(load_voice),
        .voice_samples_packed(voice_samples_packed)
    );

    wire [EFFECTS_NUM_VOICES*EFFECTS_PAN_WIDTH-1:0] voice_pan =
        {EFFECTS_NUM_VOICES{3'd0}};
    wire [15:0] mixed_sample_mono;
    wire [15:0] mixed_sample_left;
    wire [15:0] mixed_sample_right;
    reg [SAMPLE_PIPELINE_LATENCY-1:0] sample_ready_pipe;
    wire capture_effects_inputs = sample_ready_pipe[EFFECTS_INPUT_CAPTURE_DELAY];
    wire effects_sample_tick = sample_ready_pipe[EFFECTS_SAMPLE_DELAY];
    wire latch_mixed_sample = sample_ready_pipe[SAMPLE_PIPELINE_LATENCY-1];

    always @(posedge clk) begin
        if (reset | reset_player) begin
            sample_ready_pipe <= {SAMPLE_PIPELINE_LATENCY{1'b0}};
            effects_voice_active <= 4'd0;
            effects_voice_samples <= {(EFFECTS_NUM_VOICES*16){1'b0}};
        end else begin
            sample_ready_pipe <= {
                sample_ready_pipe[SAMPLE_PIPELINE_LATENCY-2:0],
                generate_next_sample
            };

            if (capture_effects_inputs) begin
                effects_voice_active <= voices_active;
                effects_voice_samples <= voice_samples_packed;
            end
        end
    end

    effects_mixer #(
        .NUM_VOICES(EFFECTS_NUM_VOICES),
        .SAMPLE_WIDTH(16),
        .PAN_WIDTH(EFFECTS_PAN_WIDTH),
        .ENABLE_PANNING(0),
        .ECHO_ADDR_WIDTH(EFFECTS_ECHO_ADDR_WIDTH)
    ) effects_mixer (
        .clk(clk),
        .reset(reset | reset_player),
        .sample_tick(effects_sample_tick),
        .voice_active(effects_voice_active),
        .voice_samples(effects_voice_samples),
        .voice_pan(voice_pan),
        .echo_enable(play),
        .echo_delay_samples(EFFECTS_ECHO_DELAY_SAMPLES),
        .echo_atten_shift(EFFECTS_ECHO_ATTEN_SHIFT),
        .mono_sample(mixed_sample_mono),
        .left_sample(mixed_sample_left),
        .right_sample(mixed_sample_right)
    );
    
    wire [15:0] mixed_sample = play ? mixed_sample_left : 16'd0;

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
        .reset(reset | reset_player),
        .en(generate_next_sample),
        .beat(tick_48th)
    );

//  
//  ****************************************************************************
//      Codec Conditioner
//  ****************************************************************************
//  
    wire new_sample_generated0;
    wire [15:0] sample_out0;

    dffr pipeline_ff_nsg (.clk(clk), .r(reset), .d(new_sample_generated0), .q(new_sample_generated));
    assign sample_out = sample_out0;

    assign new_sample_generated0 = generate_next_sample;
    codec_conditioner codec_conditioner(
        .clk(clk),
        .reset(reset),
        .new_sample_in(mixed_sample),
        .latch_new_sample_in(latch_mixed_sample),
        .generate_next_sample(generate_next_sample_raw),
        .new_frame(new_frame),
        .valid_sample(sample_out0)
    );

    assign generate_next_sample = generate_next_sample_raw;

endmodule
