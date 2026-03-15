module harmonics(
    input clk,
    input reset,
    input [19:0] step_size,
    input generate_next,
    output sample_ready,
    output [15:0] sample
);

    localparam integer FUNDAMENTAL_SHIFT = 1;
    localparam integer SECOND_SHIFT = 2;
    localparam integer THIRD_SHIFT = 3;
    localparam integer LOW_SECOND_SHIFT = 4;
    localparam [19:0] LOW_NOTE_THRESHOLD = 20'd45787;  // Approx. below 3C

    wire [20:0] second_step_size_wide = {1'b0, step_size} << 1;
    wire [20:0] third_step_size_wide = ({1'b0, step_size} << 1) + {1'b0, step_size};

    wire [19:0] second_step_size = second_step_size_wide[20] ? 20'd0 : second_step_size_wide[19:0];
    wire [19:0] third_step_size = third_step_size_wide[20] ? 20'd0 : third_step_size_wide[19:0];

    wire [15:0] fundamental_sample_u;
    wire [15:0] second_sample_u;
    wire [15:0] third_sample_u;
    wire fundamental_ready;
    wire second_ready;
    wire third_ready;

    sine_reader fundamental_reader(
        .clk(clk),
        .reset(reset),
        .step_size(step_size),
        .generate_next(generate_next),
        .sample_ready(fundamental_ready),
        .sample(fundamental_sample_u)
    );

    sine_reader second_reader(
        .clk(clk),
        .reset(reset),
        .step_size(second_step_size),
        .generate_next(generate_next),
        .sample_ready(second_ready),
        .sample(second_sample_u)
    );

    sine_reader third_reader(
        .clk(clk),
        .reset(reset),
        .step_size(third_step_size),
        .generate_next(generate_next),
        .sample_ready(third_ready),
        .sample(third_sample_u)
    );

    // Keep the fundamental dominant and mix in quieter upper harmonics.
    wire signed [15:0] fundamental_sample = $signed(fundamental_sample_u);
    wire signed [15:0] second_sample = $signed(second_sample_u);
    wire signed [15:0] third_sample = $signed(third_sample_u);
    wire low_fundamental = (step_size != 20'd0) && (step_size < LOW_NOTE_THRESHOLD);
    wire signed [15:0] second_contribution = low_fundamental ? (second_sample >>> LOW_SECOND_SHIFT) : (second_sample >>> SECOND_SHIFT);
    wire signed [15:0] third_contribution = low_fundamental ? 16'sd0 : (third_sample >>> THIRD_SHIFT);
    wire signed [17:0] harmonic_mix =
        (fundamental_sample >>> FUNDAMENTAL_SHIFT) +
        second_contribution +
        third_contribution;

    assign sample_ready = fundamental_ready & second_ready & third_ready;
    assign sample = harmonic_mix[15:0];

endmodule
