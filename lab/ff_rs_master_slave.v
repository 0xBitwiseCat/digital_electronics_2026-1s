module ff_rs_master_slave (
    input R, S, clk,
    output reg Q,
    output Qn
);
    // Definimos Qn como la inversa de Q
    assign Qn = ~Q;

    always @(posedge clk) begin
        case ({R, S})
            2'b00: Q <= Q;    // Memoria: no hay cambios
            2'b01: Q <= 1'b1; // Set: Q pasa a 1
            2'b10: Q <= 1'b0; // Reset: Q pasa a 0
            2'b11: Q <= 1'bx; // Estado inválido/indeterminado
        endcase
    end
endmodule
