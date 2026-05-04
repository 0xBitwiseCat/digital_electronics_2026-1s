module enc_4_to_7seg (
    input [3:0] sw,
    output reg [6:0] seg // abcdefg
);
    always @(*) begin
        case (sw)
            4'b0001: seg = 7'b1111110; // Ejemplo: solo segmento 'a'
            4'b0010: seg = 7'b1111101; // Ejemplo: solo segmento 'b'
            4'b0100: seg = 7'b1111011; // Ejemplo: solo segmento 'c'
            4'b1000: seg = 7'b1110111; // Ejemplo: solo segmento 'd'
            default: seg = 7'b1111111; // Todo apagado
        endcase
    end
endmodule
