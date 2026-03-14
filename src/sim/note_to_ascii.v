`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 13.03.2026 23:36:14
// Design Name: 
// Module Name: note_to_ascii.v
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module note_to_ascii(
    input  [5:0] note,
    output reg [23:0] ascii
);

/*
ascii format (3 chars):

[23:16] = octave
[15:8]  = note letter
[7:0]   = # or space

*/

always @(*) begin
    case(note)

        6'd0:  ascii = {"R","E","S"};   // rest

        // octave 1
        6'd1:  ascii = {"1","A"," "};
        6'd2:  ascii = {"1","A","#"};
        6'd3:  ascii = {"1","B"," "};
        6'd4:  ascii = {"1","C"," "};
        6'd5:  ascii = {"1","C","#"};
        6'd6:  ascii = {"1","D"," "};
        6'd7:  ascii = {"1","D","#"};
        6'd8:  ascii = {"1","E"," "};
        6'd9:  ascii = {"1","F"," "};
        6'd10: ascii = {"1","F","#"};
        6'd11: ascii = {"1","G"," "};
        6'd12: ascii = {"1","G","#"};

        // octave 2
        6'd13: ascii = {"2","A"," "};
        6'd14: ascii = {"2","A","#"};
        6'd15: ascii = {"2","B"," "};
        6'd16: ascii = {"2","C"," "};
        6'd17: ascii = {"2","C","#"};
        6'd18: ascii = {"2","D"," "};
        6'd19: ascii = {"2","D","#"};
        6'd20: ascii = {"2","E"," "};
        6'd21: ascii = {"2","F"," "};
        6'd22: ascii = {"2","F","#"};
        6'd23: ascii = {"2","G"," "};
        6'd24: ascii = {"2","G","#"};

        // octave 3
        6'd25: ascii = {"3","A"," "};
        6'd26: ascii = {"3","A","#"};
        6'd27: ascii = {"3","B"," "};
        6'd28: ascii = {"3","C"," "};
        6'd29: ascii = {"3","C","#"};
        6'd30: ascii = {"3","D"," "};
        6'd31: ascii = {"3","D","#"};
        6'd32: ascii = {"3","E"," "};
        6'd33: ascii = {"3","F"," "};
        6'd34: ascii = {"3","F","#"};
        6'd35: ascii = {"3","G"," "};
        6'd36: ascii = {"3","G","#"};

        // octave 4
        6'd37: ascii = {"4","A"," "};
        6'd38: ascii = {"4","A","#"};
        6'd39: ascii = {"4","B"," "};
        6'd40: ascii = {"4","C"," "};
        6'd41: ascii = {"4","C","#"};
        6'd42: ascii = {"4","D"," "};
        6'd43: ascii = {"4","D","#"};
        6'd44: ascii = {"4","E"," "};
        6'd45: ascii = {"4","F"," "};
        6'd46: ascii = {"4","F","#"};
        6'd47: ascii = {"4","G"," "};
        6'd48: ascii = {"4","G","#"};

        // octave 5
        6'd49: ascii = {"5","A"," "};
        6'd50: ascii = {"5","A","#"};
        6'd51: ascii = {"5","B"," "};
        6'd52: ascii = {"5","C"," "};
        6'd53: ascii = {"5","C","#"};
        6'd54: ascii = {"5","D"," "};
        6'd55: ascii = {"5","D","#"};
        6'd56: ascii = {"5","E"," "};
        6'd57: ascii = {"5","F"," "};
        6'd58: ascii = {"5","F","#"};
        6'd59: ascii = {"5","G"," "};
        6'd60: ascii = {"5","G","#"};

        // octave 6
        6'd61: ascii = {"6","A"," "};
        6'd62: ascii = {"6","A","#"};
        6'd63: ascii = {"6","B"," "};

        default: ascii = {"?","?","?"};

    endcase
end

endmodule
