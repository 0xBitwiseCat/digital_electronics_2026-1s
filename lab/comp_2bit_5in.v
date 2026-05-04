module comp_2bit_5in (
    input [1:0] A, B,
    input en,          // 5ta entrada: Habilitación
    output reg [1:0] out // 01: A>B, 10: A<B, 11: A=B
);
    always @(*) begin
        if (!en) out = 2'b00;
        else if (A > B)  out = 2'b01;
        else if (A < B)  out = 2'b10;
        else             out = 2'b11;
    end
endmodule
