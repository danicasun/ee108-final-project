module note_player(
    input clk,
    input reset,
    input play_enable,
    input [5:0] note_to_load,
    input [5:0] duration_to_load,
    input load_new_note, 
    output done_with_note,
    input beat, 
    input generate_next_sample, 
    output [15:0] sample_out,
    output new_sample_ready 
);

    reg [5:0] duration_counter;
    reg [5:0] active_note;
    
    always @(posedge clk) begin
        if (reset) begin
            duration_counter <= 6'b0;
            active_note <= 6'b0;
        end else if (load_new_note) begin
            duration_counter <= duration_to_load;
            active_note <= note_to_load;
        end else if (play_enable && beat && (duration_counter != 0)) begin
            duration_counter <= duration_counter - 1;
        end
    end

    //we are done when the counter hits 0, send next note
    assign done_with_note = (duration_counter == 6'b0);

    wire [19:0] step_size_from_rom;
    wire note_active = (duration_counter != 6'd0) && (active_note != 6'd0);
    wire start_note = load_new_note && (note_to_load != 6'd0);
    wire [15:0] harmonic_sample;
    wire harmonic_sample_ready;
    
    //get freqs from frequency rom
    frequency_rom freq_rom (
        .clk(clk),
        .addr(active_note),
        .dout(step_size_from_rom)
    );

    wire [19:0] effective_step_size = play_enable ? step_size_from_rom : 20'd0;

    //run note through harmonics and dynamics
    harmonics harmonic_gen (
        .clk(clk),
        .reset(reset),
        .step_size(effective_step_size),
        .generate_next(generate_next_sample),
        .sample_ready(harmonic_sample_ready),
        .sample(harmonic_sample)
    );

    dynamics dynamics_gen (
        .clk(clk),
        .reset(reset),
        .trigger(start_note),
        .gate(note_active),
        .sample_in(harmonic_sample),
        .sample_valid_in(harmonic_sample_ready),
        .sample_out(sample_out),
        .sample_valid_out(new_sample_ready)
    );

endmodule
