module note_display(
    input clk,
    input reset,
    input [10:0] x,
    input [9:0] y,
    input valid,
    input [1:0] current_song,
    input [5:0] current_note,
    input new_note,
    input [6:0] next_note_addr,
    output valid_pixel,
    output [7:0] r,
    output [7:0] g,
    output [7:0] b
);
    //manual display stuff 
    localparam integer SCALE = 2;
    localparam integer CHAR_WIDTH = 8 * SCALE;
    localparam integer CHAR_HEIGHT = 8 * SCALE;
    localparam integer LABEL_CHARS = 6;
    localparam integer ENTRY_CHARS = 11;
    localparam integer TOTAL_CHARS = LABEL_CHARS + ENTRY_CHARS;
    localparam integer TOTAL_LINES = 7;
    localparam [10:0] ORIGIN_X = 11'd120;
    localparam [9:0] ORIGIN_Y = 10'd272;
    localparam [10:0] TEXT_WIDTH = TOTAL_CHARS * CHAR_WIDTH;
    localparam [9:0] TEXT_HEIGHT = TOTAL_LINES * CHAR_HEIGHT;
    localparam [10:0] BOX_X0 = ORIGIN_X - 11'd8;
    localparam [10:0] BOX_X1 = ORIGIN_X + TEXT_WIDTH + 11'd8;
    localparam [9:0] BOX_Y0 = ORIGIN_Y - 10'd8;
    localparam [9:0] BOX_Y1 = ORIGIN_Y + TEXT_HEIGHT + 10'd8;

    localparam [5:0] FONT_A = 6'd1;
    localparam [5:0] FONT_B = 6'd2;
    localparam [5:0] FONT_C = 6'd3;
    localparam [5:0] FONT_D = 6'd4;
    localparam [5:0] FONT_E = 6'd5;
    localparam [5:0] FONT_F = 6'd6;
    localparam [5:0] FONT_G = 6'd7;
    localparam [5:0] FONT_H = 6'd8;
    localparam [5:0] FONT_I = 6'd9;
    localparam [5:0] FONT_J = 6'd10;
    localparam [5:0] FONT_K = 6'd11;
    localparam [5:0] FONT_L = 6'd12;
    localparam [5:0] FONT_M = 6'd13;
    localparam [5:0] FONT_N = 6'd14;
    localparam [5:0] FONT_O = 6'd15;
    localparam [5:0] FONT_P = 6'd16;
    localparam [5:0] FONT_Q = 6'd17;
    localparam [5:0] FONT_R = 6'd18;
    localparam [5:0] FONT_S = 6'd19;
    localparam [5:0] FONT_T = 6'd20;
    localparam [5:0] FONT_U = 6'd21;
    localparam [5:0] FONT_V = 6'd22;
    localparam [5:0] FONT_W = 6'd23;
    localparam [5:0] FONT_X = 6'd24;
    localparam [5:0] FONT_Y = 6'd25;
    localparam [5:0] FONT_Z = 6'd26;
    localparam [5:0] FONT_SPACE = 6'd32;
    localparam [5:0] FONT_HASH = 6'd35;
    localparam [5:0] FONT_DASH = 6'd45;
    localparam [5:0] FONT_0 = 6'd48;
    localparam [5:0] FONT_1 = 6'd49;
    localparam [5:0] FONT_2 = 6'd50;
    localparam [5:0] FONT_3 = 6'd51;
    localparam [5:0] FONT_4 = 6'd52;
    localparam [5:0] FONT_5 = 6'd53;
    localparam [5:0] FONT_6 = 6'd54;

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

    function [5:0] third_note_for;
        input [5:0] root_note;
        begin
            third_note_for = chord_tone(root_note, ((root_note != 6'd0) && (root_note < 6'd28)) ? 6'd16 : 6'd4);
        end
    endfunction

    function [5:0] fifth_note_for;
        input [5:0] root_note;
        begin
            fifth_note_for = chord_tone(root_note, ((root_note != 6'd0) && (root_note < 6'd28)) ? 6'd19 : 6'd7);
        end
    endfunction

    function [5:0] normalized_note;
        input [5:0] note;
        reg [5:0] reduced_note;
        begin
            reduced_note = note;
            if (reduced_note > 6'd60) begin
                reduced_note = reduced_note - 6'd60;
            end else if (reduced_note > 6'd48) begin
                reduced_note = reduced_note - 6'd48;
            end else if (reduced_note > 6'd36) begin
                reduced_note = reduced_note - 6'd36;
            end else if (reduced_note > 6'd24) begin
                reduced_note = reduced_note - 6'd24;
            end else if (reduced_note > 6'd12) begin
                reduced_note = reduced_note - 6'd12;
            end
            normalized_note = reduced_note;
        end
    endfunction

    function [5:0] note_letter_code;
        input [5:0] note;
        reg [5:0] reduced_note;
        begin
            reduced_note = normalized_note(note);
            case (reduced_note)
                6'd1, 6'd2: note_letter_code = FONT_A;
                6'd3: note_letter_code = FONT_B;
                6'd4, 6'd5: note_letter_code = FONT_C;
                6'd6, 6'd7: note_letter_code = FONT_D;
                6'd8: note_letter_code = FONT_E;
                6'd9, 6'd10: note_letter_code = FONT_F;
                6'd11, 6'd12: note_letter_code = FONT_G;
                default: note_letter_code = FONT_SPACE;
            endcase
        end
    endfunction

    function [5:0] note_accidental_code;
        input [5:0] note;
        reg [5:0] reduced_note;
        begin
            reduced_note = normalized_note(note);
            case (reduced_note)
                6'd2, 6'd5, 6'd7, 6'd10, 6'd12: note_accidental_code = FONT_HASH;
                default: note_accidental_code = FONT_SPACE;
            endcase
        end
    endfunction

    function [5:0] note_octave_code;
        input [5:0] note;
        begin
            if ((note >= 6'd1) && (note <= 6'd12)) begin
                note_octave_code = FONT_1;
            end else if ((note >= 6'd13) && (note <= 6'd24)) begin
                note_octave_code = FONT_2;
            end else if ((note >= 6'd25) && (note <= 6'd36)) begin
                note_octave_code = FONT_3;
            end else if ((note >= 6'd37) && (note <= 6'd48)) begin
                note_octave_code = FONT_4;
            end else if ((note >= 6'd49) && (note <= 6'd60)) begin
                note_octave_code = FONT_5;
            end else if ((note >= 6'd61) && (note <= 6'd63)) begin
                note_octave_code = FONT_6;
            end else begin
                note_octave_code = FONT_SPACE;
            end
        end
    endfunction

    function [5:0] note_char;
        input [5:0] note;
        input [1:0] char_index;
        begin
            if (note == 6'd0) begin
                note_char = FONT_SPACE;
            end else begin
                case (char_index)
                    2'd0: note_char = note_letter_code(note);
                    2'd1: note_char = note_accidental_code(note);
                    2'd2: note_char = note_octave_code(note);
                    default: note_char = FONT_SPACE;
                endcase
            end
        end
    endfunction

    function [5:0] entry_char;
        input [5:0] root_note;
        input entry_valid;
        input [4:0] char_index;
        reg [5:0] third_note;
        reg [5:0] fifth_note;
        begin
            if (!entry_valid) begin
                entry_char = FONT_SPACE;
            end else if (root_note == 6'd0) begin
                case (char_index)
                    5'd0: entry_char = FONT_R;
                    5'd1: entry_char = FONT_S;
                    5'd2: entry_char = FONT_T;
                    default: entry_char = FONT_SPACE;
                endcase
            end else begin
                third_note = third_note_for(root_note);
                fifth_note = fifth_note_for(root_note);
                case (char_index)
                    5'd0: entry_char = note_char(root_note, 2'd0);
                    5'd1: entry_char = note_char(root_note, 2'd1);
                    5'd2: entry_char = note_char(root_note, 2'd2);
                    5'd3: entry_char = FONT_SPACE;
                    5'd4: entry_char = note_char(third_note, 2'd0);
                    5'd5: entry_char = note_char(third_note, 2'd1);
                    5'd6: entry_char = note_char(third_note, 2'd2);
                    5'd7: entry_char = FONT_SPACE;
                    5'd8: entry_char = note_char(fifth_note, 2'd0);
                    5'd9: entry_char = note_char(fifth_note, 2'd1);
                    5'd10: entry_char = note_char(fifth_note, 2'd2);
                    default: entry_char = FONT_SPACE;
                endcase
            end
        end
    endfunction

    function [5:0] label_char;
        input [2:0] line_index;
        input [4:0] char_index;
        begin
            case (line_index)
                3'd0: begin
                    case (char_index)
                        5'd0: label_char = FONT_N;
                        5'd1: label_char = FONT_O;
                        5'd2: label_char = FONT_W;
                        default: label_char = FONT_SPACE;
                    endcase
                end

                3'd1, 3'd2, 3'd3: begin
                    case (char_index)
                        5'd0: label_char = FONT_P;
                        5'd1: label_char = FONT_A;
                        5'd2: label_char = FONT_S;
                        5'd3: label_char = FONT_T;
                        5'd4: label_char = FONT_1 + (line_index - 3'd1);
                        default: label_char = FONT_SPACE;
                    endcase
                end

                3'd4, 3'd5, 3'd6: begin
                    case (char_index)
                        5'd0: label_char = FONT_N;
                        5'd1: label_char = FONT_E;
                        5'd2: label_char = FONT_X;
                        5'd3: label_char = FONT_T;
                        5'd4: label_char = FONT_1 + (line_index - 3'd4);
                        default: label_char = FONT_SPACE;
                    endcase
                end

                default: begin
                    label_char = FONT_SPACE;
                end
            endcase
        end
    endfunction

    reg [1:0] song_q;
    reg [5:0] current_note_q;
    reg [5:0] past_note_0;
    reg [5:0] past_note_1;
    reg [5:0] past_note_2;
    reg current_valid_q;
    reg past_valid_0;
    reg past_valid_1;
    reg past_valid_2;

    always @(posedge clk) begin
        if (reset) begin
            song_q <= current_song;
            current_note_q <= 6'd0;
            past_note_0 <= 6'd0;
            past_note_1 <= 6'd0;
            past_note_2 <= 6'd0;
            current_valid_q <= 1'b0;
            past_valid_0 <= 1'b0;
            past_valid_1 <= 1'b0;
            past_valid_2 <= 1'b0;
        end else if (current_song != song_q) begin
            song_q <= current_song;
            current_note_q <= 6'd0;
            past_note_0 <= 6'd0;
            past_note_1 <= 6'd0;
            past_note_2 <= 6'd0;
            current_valid_q <= 1'b0;
            past_valid_0 <= 1'b0;
            past_valid_1 <= 1'b0;
            past_valid_2 <= 1'b0;
        end else if (new_note) begin
            past_note_2 <= past_note_1;
            past_note_1 <= past_note_0;
            past_note_0 <= current_note_q;
            current_note_q <= current_note;
            past_valid_2 <= past_valid_1;
            past_valid_1 <= past_valid_0;
            past_valid_0 <= current_valid_q;
            current_valid_q <= 1'b1;
        end
    end

    wire future_0_in_range = (next_note_addr[4:0] <= 5'd31);
    wire future_1_in_range = (next_note_addr[4:0] <= 5'd30);
    wire future_2_in_range = (next_note_addr[4:0] <= 5'd29);

    wire [11:0] future_word_0;
    wire [11:0] future_word_1;
    wire [11:0] future_word_2;

    song_rom future_rom_0(
        .clk(clk),
        .addr(next_note_addr),
        .dout(future_word_0)
    );

    song_rom future_rom_1(
        .clk(clk),
        .addr(next_note_addr + 7'd1),
        .dout(future_word_1)
    );

    song_rom future_rom_2(
        .clk(clk),
        .addr(next_note_addr + 7'd2),
        .dout(future_word_2)
    );

    wire [5:0] future_note_0 = future_word_0[11:6];
    wire [5:0] future_note_1 = future_word_1[11:6];
    wire [5:0] future_note_2 = future_word_2[11:6];
    wire future_valid_0 = future_0_in_range && (future_word_0[5:0] != 6'd0);
    wire future_valid_1 = future_1_in_range && (future_word_1[5:0] != 6'd0);
    wire future_valid_2 = future_2_in_range && (future_word_2[5:0] != 6'd0);

    wire in_box = valid && (x >= BOX_X0) && (x < BOX_X1) && (y >= BOX_Y0) && (y < BOX_Y1);
    wire in_text_region = valid && (x >= ORIGIN_X) && (x < (ORIGIN_X + TEXT_WIDTH)) &&
                          (y >= ORIGIN_Y) && (y < (ORIGIN_Y + TEXT_HEIGHT));

    wire [10:0] text_x = in_text_region ? (x - ORIGIN_X) : 11'd0;
    wire [9:0] text_y = in_text_region ? (y - ORIGIN_Y) : 10'd0;
    wire [4:0] char_col = text_x / CHAR_WIDTH;
    wire [2:0] char_line = text_y / CHAR_HEIGHT;
    wire [2:0] font_row = (text_y % CHAR_HEIGHT) / SCALE;
    wire [2:0] font_col = (text_x % CHAR_WIDTH) / SCALE;

    reg [5:0] line_note;
    reg line_note_valid;
    always @(*) begin
        case (char_line)
            3'd0: begin
                line_note = current_note_q;
                line_note_valid = current_valid_q;
            end
            3'd1: begin
                line_note = past_note_0;
                line_note_valid = past_valid_0;
            end
            3'd2: begin
                line_note = past_note_1;
                line_note_valid = past_valid_1;
            end
            3'd3: begin
                line_note = past_note_2;
                line_note_valid = past_valid_2;
            end
            3'd4: begin
                line_note = future_note_0;
                line_note_valid = future_valid_0;
            end
            3'd5: begin
                line_note = future_note_1;
                line_note_valid = future_valid_1;
            end
            3'd6: begin
                line_note = future_note_2;
                line_note_valid = future_valid_2;
            end
            default: begin
                line_note = 6'd0;
                line_note_valid = 1'b0;
            end
        endcase
    end

    wire [5:0] char_code =
        (char_col < LABEL_CHARS) ? label_char(char_line, char_col) :
        entry_char(line_note, line_note_valid, char_col - LABEL_CHARS);

    wire [7:0] glyph_row;
    tcgrom font_rom(
        .addr({char_code, font_row}),
        .data(glyph_row)
    );

    wire glyph_on = in_text_region && glyph_row[7 - font_col];

    reg [7:0] fg_r;
    reg [7:0] fg_g;
    reg [7:0] fg_b;
    always @(*) begin
        case (char_line)
            3'd0: begin
                fg_r = 8'hFF;
                fg_g = 8'hE0;
                fg_b = 8'h80;
            end
            3'd1, 3'd2, 3'd3: begin
                fg_r = 8'hC0;
                fg_g = 8'hC0;
                fg_b = 8'hC0;
            end
            default: begin
                fg_r = 8'h80;
                fg_g = 8'hE8;
                fg_b = 8'hFF;
            end
        endcase
    end

    assign valid_pixel = in_box;
    assign r = !in_box ? 8'h00 : (glyph_on ? fg_r : 8'h08);
    assign g = !in_box ? 8'h00 : (glyph_on ? fg_g : 8'h10);
    assign b = !in_box ? 8'h00 : (glyph_on ? fg_b : 8'h28);

endmodule
