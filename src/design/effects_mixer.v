module effects_mixer #(
    parameter integer NUM_VOICES = 4,
    parameter integer SAMPLE_WIDTH = 16,
    parameter integer PAN_WIDTH = 3,
    parameter integer MIX_SHIFT = 0,
    parameter integer MAX_DELAY_SAMPLES = 24000,
    parameter integer ECHO_ADDR_WIDTH = 15,
    parameter integer ECHO_SHIFT_WIDTH = 4
)(
    input clk,
    input reset,
    input sample_tick,

    // Voice 0 occupies the least-significant slice of each packed bus.
    input [NUM_VOICES-1:0] voice_active,
    input [NUM_VOICES*SAMPLE_WIDTH-1:0] voice_samples,
    input [NUM_VOICES*PAN_WIDTH-1:0] voice_pan,

    input echo_enable,
    input [ECHO_ADDR_WIDTH-1:0] echo_delay_samples,
    input [ECHO_SHIFT_WIDTH-1:0] echo_atten_shift,

    // mono_sample is the dry mixed result before stereo echo is applied.
    output reg signed [SAMPLE_WIDTH-1:0] mono_sample,
    output reg signed [SAMPLE_WIDTH-1:0] left_sample,
    output reg signed [SAMPLE_WIDTH-1:0] right_sample
);

    function integer clog2;
        input integer value;
        integer value_minus_one;
        begin
            value_minus_one = value - 1;
            for (clog2 = 0; value_minus_one > 0; clog2 = clog2 + 1) begin
                value_minus_one = value_minus_one >> 1;
            end
        end
    endfunction

    parameter integer VOICE_SUM_WIDTH = clog2(NUM_VOICES + 1);
    parameter integer ACCUM_WIDTH = SAMPLE_WIDTH + PAN_WIDTH + VOICE_SUM_WIDTH + 2;
    parameter [PAN_WIDTH-1:0] PAN_FULL_SCALE = {PAN_WIDTH{1'b1}};
    parameter [ECHO_ADDR_WIDTH-1:0] LAST_ECHO_ADDR = MAX_DELAY_SAMPLES - 1;

    function signed [SAMPLE_WIDTH-1:0] unpack_sample;
        input [NUM_VOICES*SAMPLE_WIDTH-1:0] packed_samples;
        input integer voice_index;
        reg [NUM_VOICES*SAMPLE_WIDTH-1:0] shifted_samples;
        begin
            shifted_samples = packed_samples >> (voice_index * SAMPLE_WIDTH);
            unpack_sample = shifted_samples[SAMPLE_WIDTH-1:0];
        end
    endfunction

    function [PAN_WIDTH-1:0] unpack_pan;
        input [NUM_VOICES*PAN_WIDTH-1:0] packed_pan;
        input integer voice_index;
        reg [NUM_VOICES*PAN_WIDTH-1:0] shifted_pan;
        begin
            shifted_pan = packed_pan >> (voice_index * PAN_WIDTH);
            unpack_pan = shifted_pan[PAN_WIDTH-1:0];
        end
    endfunction

    function signed [SAMPLE_WIDTH-1:0] clip_sample;
        input signed [ACCUM_WIDTH-1:0] sample_in;
        reg signed [ACCUM_WIDTH-1:0] max_value;
        reg signed [ACCUM_WIDTH-1:0] min_value;
        begin
            max_value = {
                {(ACCUM_WIDTH-SAMPLE_WIDTH){1'b0}},
                1'b0,
                {(SAMPLE_WIDTH-1){1'b1}}
            };
            min_value = {
                {(ACCUM_WIDTH-SAMPLE_WIDTH){1'b1}},
                1'b1,
                {(SAMPLE_WIDTH-1){1'b0}}
            };

            if (sample_in > max_value) begin
                clip_sample = {1'b0, {(SAMPLE_WIDTH-1){1'b1}}};
            end else if (sample_in < min_value) begin
                clip_sample = {1'b1, {(SAMPLE_WIDTH-1){1'b0}}};
            end else begin
                clip_sample = sample_in[SAMPLE_WIDTH-1:0];
            end
        end
    endfunction

    integer voice_index;
    reg signed [SAMPLE_WIDTH-1:0] current_voice_sample;
    reg [PAN_WIDTH-1:0] current_pan;
    reg [PAN_WIDTH-1:0] left_gain;
    reg [PAN_WIDTH-1:0] right_gain;

    reg signed [ACCUM_WIDTH-1:0] mono_mix_next;
    reg signed [ACCUM_WIDTH-1:0] left_mix_next;
    reg signed [ACCUM_WIDTH-1:0] right_mix_next;
    reg signed [ACCUM_WIDTH-1:0] left_voice_term;
    reg signed [ACCUM_WIDTH-1:0] right_voice_term;

    always @(*) begin
        mono_mix_next = {ACCUM_WIDTH{1'b0}};
        left_mix_next = {ACCUM_WIDTH{1'b0}};
        right_mix_next = {ACCUM_WIDTH{1'b0}};

        for (voice_index = 0; voice_index < NUM_VOICES; voice_index = voice_index + 1) begin
            current_voice_sample = unpack_sample(voice_samples, voice_index);
            current_pan = unpack_pan(voice_pan, voice_index);
            left_gain = PAN_FULL_SCALE - current_pan;
            right_gain = current_pan;

            left_voice_term =
                ($signed(current_voice_sample) * $signed({1'b0, left_gain})) >>> PAN_WIDTH;
            right_voice_term =
                ($signed(current_voice_sample) * $signed({1'b0, right_gain})) >>> PAN_WIDTH;

            if (voice_active[voice_index]) begin
                mono_mix_next = mono_mix_next + ($signed(current_voice_sample) >>> MIX_SHIFT);
                left_mix_next = left_mix_next + (left_voice_term >>> MIX_SHIFT);
                right_mix_next = right_mix_next + (right_voice_term >>> MIX_SHIFT);
            end
        end
    end

    reg [ECHO_ADDR_WIDTH-1:0] echo_write_addr;
    reg [ECHO_ADDR_WIDTH-1:0] echo_read_addr;
    reg [ECHO_ADDR_WIDTH:0] wrapped_read_addr;
    reg [ECHO_ADDR_WIDTH:0] echo_fill_count;
    wire [ECHO_ADDR_WIDTH-1:0] bounded_echo_delay =
        (echo_delay_samples > LAST_ECHO_ADDR) ? LAST_ECHO_ADDR : echo_delay_samples;
    wire [ECHO_ADDR_WIDTH:0] bounded_echo_delay_ext = {1'b0, bounded_echo_delay};
    wire echo_has_valid_sample = (echo_fill_count >= bounded_echo_delay_ext);

    always @(*) begin
        wrapped_read_addr = {ECHO_ADDR_WIDTH+1{1'b0}};
        if (echo_write_addr >= bounded_echo_delay) begin
            echo_read_addr = echo_write_addr - bounded_echo_delay;
        end else begin
            wrapped_read_addr = echo_write_addr + MAX_DELAY_SAMPLES - bounded_echo_delay;
            echo_read_addr = wrapped_read_addr[ECHO_ADDR_WIDTH-1:0];
        end
    end

    wire [SAMPLE_WIDTH-1:0] echo_read_sample_bits;
    wire signed [SAMPLE_WIDTH-1:0] echo_read_sample = echo_read_sample_bits;
    wire signed [ACCUM_WIDTH-1:0] echo_term =
        (echo_enable && echo_has_valid_sample) ?
            ($signed(echo_read_sample) >>> echo_atten_shift) :
            {ACCUM_WIDTH{1'b0}};

    ram_1w2r #(
        .WIDTH(SAMPLE_WIDTH),
        .DEPTH(ECHO_ADDR_WIDTH)
    ) echo_ram (
        .clka(clk),
        .wea(sample_tick),
        .addra(echo_write_addr),
        .dina(clip_sample(mono_mix_next)),
        .douta(),
        .clkb(clk),
        .addrb(echo_read_addr),
        .doutb(echo_read_sample_bits)
    );

    always @(posedge clk) begin
        if (reset) begin
            echo_write_addr <= {ECHO_ADDR_WIDTH{1'b0}};
            echo_fill_count <= {ECHO_ADDR_WIDTH+1{1'b0}};
            mono_sample <= {SAMPLE_WIDTH{1'b0}};
            left_sample <= {SAMPLE_WIDTH{1'b0}};
            right_sample <= {SAMPLE_WIDTH{1'b0}};
        end else if (sample_tick) begin
            mono_sample <= clip_sample(mono_mix_next);
            left_sample <= clip_sample(left_mix_next + echo_term);
            right_sample <= clip_sample(right_mix_next + echo_term);

            if (echo_fill_count < MAX_DELAY_SAMPLES) begin
                echo_fill_count <= echo_fill_count + 1'b1;
            end

            if (echo_write_addr == LAST_ECHO_ADDR) begin
                echo_write_addr <= {ECHO_ADDR_WIDTH{1'b0}};
            end else begin
                echo_write_addr <= echo_write_addr + 1'b1;
            end
        end
    end

endmodule
