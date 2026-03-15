module song_reader(
    input clk,
    input reset,
    input play,
    input [1:0] song,
    input note_done,
    output reg song_done,
    output reg [5:0] note,
    output reg [5:0] duration,
    output reg new_note,
    output [6:0] next_addr
);

    reg [6:0] song_addr;
    wire [11:0] song_word;
    wire [5:0] rom_note = song_word[11:6];
    wire [5:0] rom_dur = song_word[5:0];
    
    //retrieve song rom
    song_rom rom (
        .clk(clk),
        .addr(song_addr),
        .dout(song_word)
    );
    
    //states
    localparam WAIT_DONE = 3'd0;
    localparam WAIT_ROM = 3'd1; 
    localparam READ_AND_LOAD = 3'd2;
    localparam WAIT_BUSY = 3'd3; 
    localparam SONG_DONE = 3'd4;
    
    reg [2:0] state;
    
    //track song changes
    reg [1:0] song_q; 
    reg end_after_current_note;

    
    always @(posedge clk) begin
        if (reset) begin
            //zero everything goto WAIT_DONE
            state <= WAIT_DONE;
            song_q <= song;
            song_addr <= {song, 5'd0}; 
            end_after_current_note <= 1'b0;
            note <= 6'd0;
            duration <= 6'd0;
            new_note <= 1'b0;
            song_done <= 1'b0;
        end else begin
            new_note <= 1'b0;
            song_done <= 1'b0;
            
            if(song != song_q) begin 
                song_q <= song;
                song_addr <= {song, 5'd0};
                end_after_current_note <= 1'b0;
                state <= WAIT_DONE;
            end 
            case(state)
                WAIT_DONE: begin
                    //wait for note_player to be ready
                    if (!play) begin
                        state <= WAIT_DONE;
                    end else if (note_done) begin
                        state <= WAIT_ROM;
                    end
                end
                
                WAIT_ROM: begin
                    //need valid ROM data
                    if (!play) begin
                        state <= WAIT_ROM;
                    end else begin
                        state <= READ_AND_LOAD;
                    end
                end
                
                READ_AND_LOAD: begin
                    if (!play) begin
                        state <= READ_AND_LOAD;
                    end else if (rom_dur == 6'd0) begin
                        state <= SONG_DONE;
                    end else begin
                        note <= rom_note;
                        duration <= rom_dur;
                        new_note <= 1'b1;
                        end_after_current_note <= (song_addr[4:0] == 5'd31);

                        //inc address inside current song block only.
                        if (song_addr[4:0] != 5'd31) begin
                            song_addr <= song_addr + 7'd1;
                        end
                        
                        state <= WAIT_BUSY;
                    end
                end

                WAIT_BUSY: begin
                    //wait 1 cycle here to allow the note_player to see new_note
                    if (end_after_current_note) begin
                        end_after_current_note <= 1'b0;
                        state <= SONG_DONE;
                    end else begin
                        state <= WAIT_DONE;
                    end
                end

                SONG_DONE: begin
                    new_note <= 1'b0;
                    song_done <= 1'b1;
                    //until reset
                    state <= SONG_DONE;
                end
                
                default: begin
                    state <= WAIT_DONE;
                end
                
            endcase
        end
   end

   assign next_addr = song_addr;
endmodule
