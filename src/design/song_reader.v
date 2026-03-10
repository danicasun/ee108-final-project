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
    reg end_after_current_note;
    
    // TODO: update to play whatever note should be on at that moment 
    // think about whether i need a larger restructuring 
    // does the current implementation automaticlaly advance or is it run on a similar model where we need to add instructions to do so
    always @(posedge clk) begin
        if (reset) begin
            state <= WAIT_DONE;
            song_q <= song;
            song_addr <= {song, 5'd0}; 
            end_after_current_note <= 1'b0;

            note1 <= 6'd0;
            duration1 <= 6'd0;
            note2 <= 6'd0;
            duration2 <= 6'd0;
            note3 <= 6'd0;
            duration3 <= 6'd0;
            new_note <= 1'b0;
            song_done <= 1'b0;
        end else begin
            new_note <= 1'b0;
            song_done <= 1'b0;
            
            // user incremented to the next song --> reset song addr and state
            if(song != song_q) begin 
                song_q <= song;
                song_addr <= {song, 5'd0};
                end_after_current_note <= 1'b0;
                state <= WAIT_DONE;
            end 
            // TODO: update with the new states 
            case(state)
            // wait until the current playing note is done
                WAIT_DONE: begin
                    // Wait for note_player to be ready
                    if (!play) begin
                        state <= WAIT_DONE;
                    end else if (note_done) begin
                        state <= WAIT_ROM;
                    end
                end
                
                // wait until the next note is done being read from the ROM and data is ready
                WAIT_ROM: begin
                    // Wait for ROM Data to be valid
                    if (!play) begin
                        state <= WAIT_ROM;
                    end else begin
                        state <= READ_AND_LOAD;
                    end
                end
                
                // get the next note and prep it to be played
                // TODO: understand better what exactly I am reading from the ROM 
                DECODE: begin
                    if (!play) begin
                        state <= READ_AND_LOAD;
                    end else if (rom_dur == 6'd0) begin
                        state <= SONG_DONE;
                    end else begin
                    // TOOO: update this so it can read multiple notes from rom_note??? 
                    // or in general how should i handle this, waht if there r more than 3, how exacltly is note_player reading this
                        note1 <= rom_note;
                        duration1 <= rom_dur;
                        new_note <= 1'b1;
                        // if the lower 5 bits are 31 then this is the last note of the song 
                        end_after_current_note <= (song_addr[4:0] == 5'd31);

                        // Increment address inside current song block only.
                        if (song_addr[4:0] != 5'd31) begin
                            song_addr <= song_addr + 7'd1;
                        end
                        
                        state <= WAIT_BUSY;
                    end
                end

                WAIT_BUSY: begin
                    // wait 1 cycle here to allow the note_player to see new_note
                    if (end_after_current_note) begin
                        end_after_current_note <= 1'b0;
                        state <= SONG_DONE;
                    end else begin
                        state <= WAIT_DONE;
                    end
                end

                DECODE: begin
                    new_note <= 1'b0;
                    song_done <= 1'b1;
                    // Stay here until reset
                    state <= SONG_DONE;
                end
                
                // if entering invalid state 
                default: begin
                    state <= WAIT_DONE;
                end
                
            endcase
        end
   end
endmodule