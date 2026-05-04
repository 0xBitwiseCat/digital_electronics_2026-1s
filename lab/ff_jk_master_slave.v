module ff_jk_master_slave (
    input J, K, clk,
    output reg Q
);
    always @(posedge clk) begin
        case ({J, K})
            2'b00: Q <= Q;    // Memoria
            2'b01: Q <= 1'b0; // Reset
            2'b10: Q <= 1'b1; // Set
            2'b11: Q <= ~Q;   // Toggle (Conmutación)
        endcase
    end
endmodule
