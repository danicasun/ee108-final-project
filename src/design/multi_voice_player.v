module multi_voice_player(
    input clk,
    input reset,
    input play_enable,
    input [5:0] note_to_load,
    input [5:0] duration_to_load,
    input load_new_note,
    output done_with_note,
    input beat,
    input generate_next_sample,
    output [15:0] left_sample_out,
    output [15:0] right_sample_out,
    output [15:0] sample_out,
    output new_sample_ready,
    output signed [15:0] voice_root_sample,
    output signed [15:0] voice_third_sample,
    output signed [15:0] voice_fifth_sample
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

    //found that low registers are rlly staticky - a small fix here
    //adjusted these values by listening (tldr this took a long time)
    wire low_register_note = (note_to_load != 6'd0) && (note_to_load < 6'd28);
    wire very_low_register_note = (note_to_load != 6'd0) && (note_to_load < 6'd20);
    wire [5:0] third_interval = low_register_note ? 6'd16 : 6'd4;
    wire [5:0] fifth_interval = low_register_note ? 6'd19 : 6'd7;
    wire [5:0] third_note = very_low_register_note ? 6'd0 : chord_tone(note_to_load, third_interval);
    wire [5:0] fifth_note = chord_tone(note_to_load, fifth_interval);

    wire [15:0] root_sample_u;
    wire [15:0] third_sample_u;
    wire [15:0] fifth_sample_u;
    wire root_ready;
    wire third_ready;
    wire fifth_ready;
    wire root_done;
    wire third_done;
    wire fifth_done;

    note_player root_voice(
        .clk(clk),
        .reset(reset),
        .play_enable(play_enable),
        .note_to_load(note_to_load),
        .duration_to_load(duration_to_load),
        .load_new_note(load_new_note),
        .done_with_note(root_done),
        .beat(beat),
        .generate_next_sample(generate_next_sample),
        .sample_out(root_sample_u),
        .new_sample_ready(root_ready)
    );

    note_player third_voice(
        .clk(clk),
        .reset(reset),
        .play_enable(play_enable),
        .note_to_load(third_note),
        .duration_to_load(duration_to_load),
        .load_new_note(load_new_note),
        .done_with_note(third_done),
        .beat(beat),
        .generate_next_sample(generate_next_sample),
        .sample_out(third_sample_u),
        .new_sample_ready(third_ready)
    );

    note_player fifth_voice(
        .clk(clk),
        .reset(reset),
        .play_enable(play_enable),
        .note_to_load(fifth_note),
        .duration_to_load(duration_to_load),
        .load_new_note(load_new_note),
        .done_with_note(fifth_done),
        .beat(beat),
        .generate_next_sample(generate_next_sample),
        .sample_out(fifth_sample_u),
        .new_sample_ready(fifth_ready)
    );

    wire signed [15:0] root_sample = $signed(root_sample_u);
    wire signed [15:0] third_sample = $signed(third_sample_u);
    wire signed [15:0] fifth_sample = $signed(fifth_sample_u);

    //again some manual modifications for low sounds
    wire signed [15:0] third_sample_scaled =
        very_low_register_note ? 16'sd0 :
        low_register_note ? (third_sample >>> 3) :
        (third_sample >>> 1);
    wire signed [15:0] fifth_sample_scaled =
        very_low_register_note ? (fifth_sample >>> 3) :
        low_register_note ? (fifth_sample >>> 2) :
        (fifth_sample >>> 1);
    wire signed [17:0] mixed_sum = root_sample + third_sample_scaled + fifth_sample_scaled;
    wire signed [15:0] mixed_sample = mixed_sum >>> 1;
    wire signed [17:0] left_sum =
        (root_sample >>> 1) +
        third_sample_scaled +
        (fifth_sample_scaled >>> 2);
    wire signed [17:0] right_sum =
        (root_sample >>> 1) +
        (third_sample_scaled >>> 2) +
        fifth_sample_scaled;
    wire signed [15:0] left_sample = left_sum >>> 1;
    wire signed [15:0] right_sample = right_sum >>> 1;

    assign done_with_note = root_done;
    assign new_sample_ready = root_ready & third_ready & fifth_ready;
    assign left_sample_out = left_sample;
    assign right_sample_out = right_sample;
    assign sample_out = mixed_sample;
    assign voice_root_sample = root_sample;
    assign voice_third_sample = third_sample_scaled;
    assign voice_fifth_sample = fifth_sample_scaled;

endmodule

