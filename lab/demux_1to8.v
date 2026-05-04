module demux_1to8 (
    input data,
    input [2:0] sel,
    output reg [7:0] y
);
    always @(*) begin
        y = 8'b00000000; // Reset de salidas
        y[sel] = data;   // Asigna el dato a la posición seleccionada
    end
endmodule
