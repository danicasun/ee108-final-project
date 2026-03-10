module song_reader(
    input clk,
    input reset,
    input play,
    input [1:0] song,
    input tick_48th,
    output reg valid,
    output reg [5:0] note,
    output reg [5:0] duration,
    output reg [2:0] meta,
    output reg song_done
);

    reg [8:0] song_addr;

    wire [15:0] song_word;
    wire is_wait = song_word[15]; 
    wire [5:0] rom_note = song_word[14:9];
    wire [5:0] rom_dur  = song_word[8:3];
    wire [2:0] rom_meta = song_word[2:0];
    
    reg [5:0] wait_counter;
    
    // TODO: edit the song rom to output the new note format 
    // instance to retrieve from the song rom
    song_rom rom (
        .clk(clk),
        .addr(song_addr),
        .dout(song_word)
    );
    
    // TODO: update states & also double check that the new ones in the doc are correct
    // updated states:
    // do I need a wait_busy and wait_done and wait_rom? how were we able to condense to just waiting
    localparam IDLE      = 3'd0;
    localparam FETCH     = 3'd1;
    localparam DECODE    = 3'd2;
    localparam SCHEDULE  = 3'd3;
    localparam WAITING   = 3'd4;
    localparam DONE      = 3'd5;
   
    //track state
    reg [2:0] state;
    
    //track song changes
    reg [1:0] song_q; 
    wire is_end = (song_word == 16'hFFFF);
    
    // TODO: update to play whatever note should be on at that moment 
    // think about whether i need a larger restructuring 
    // does the current implementation automaticlaly advance or is it run on a similar model where we need to add instructions to do so
    always @(posedge clk) begin
    if (reset) begin
        state        <= FETCH;
        song_q       <= song;
        song_addr    <= {song, 7'd0};   // 128 entries per song
        wait_counter <= 6'd0;

        valid        <= 1'b0;
        note         <= 6'd0;
        duration     <= 6'd0;
        meta         <= 3'd0;
        song_done    <= 1'b0;

    end else begin
        // default pulse 
        valid     <= 1'b0;
        song_done <= 1'b0;

        // restart if the user changes songs
        if (song != song_q) begin
            song_q       <= song; // new song
            song_addr    <= {song, 7'd0};
            wait_counter <= 6'd0;

            valid        <= 1'b0;
            note         <= 6'd0;
            duration     <= 6'd0;
            meta         <= 3'd0;
            song_done    <= 1'b0;

            state <= FETCH;

        end else begin
            case (state)

                IDLE: begin
                    if (!play) begin
                        state <= IDLE;
                    end else begin
                        state <= FETCH;
                    end
                end

                // address to the synchronous ROM
                // on the next cycle, song_word is ready to decode
                FETCH: begin
                    if (!play) begin
                        state <= FETCH;
                    end else begin
                        state <= DECODE;
                    end
                end

                // decode the current ROM
                DECODE: begin
                    if (!play) begin
                        state <= DECODE;

                    end else if (is_end) begin
                        state <= DONE;

                    end else if (is_wait) begin
                        // wait event, advance song time by rom_dur 48th note ticks rather than scheduling a note
                        wait_counter <= rom_dur;

                        // move to next ROM entry now
                        song_addr <= song_addr + 9'd1;

                        // zero wait can just continue immediately
                        if (rom_dur == 6'd0) begin
                            state <= FETCH;
                        end else begin
                            state <= WAITING;
                        end

                    end else begin
                        // note scheduled
                        note     <= rom_note;
                        duration <= rom_dur;
                        meta     <= rom_meta;
                        valid    <= 1'b1;

                        // go to next ROM entry
                        song_addr <= song_addr + 9'd1;
                        state <= FETCH;
                    end
                end

                // wait while musical time advances, wait_counter decrements on tick_48th
                WAITING: begin
                    if (!play) begin
                        state <= WAITING;

                    end else if (tick_48th) begin
                        if (wait_counter <= 6'd1) begin
                            wait_counter <= 6'd0;
                            state <= FETCH;
                        end else begin
                            wait_counter <= wait_counter - 6'd1;
                            state <= WAITING;
                        end

                    end else begin
                        state <= WAITING;
                    end
                end

                DONE: begin
                    song_done <= 1'b1;
                    state <= DONE;
                end

                default: begin
                    state <= FETCH;
                end
            endcase
        end
    end
end
endmodule