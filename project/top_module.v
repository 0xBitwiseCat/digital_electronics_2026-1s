module top_module (
    input CLK_50M,
    input UART_RX,
    output D2, D3, D4, D5, D6, D7, D8, D9, D10 // Nuevos nombres de pines
);

    wire [7:0] rx_byte;
    wire rx_ready;
    reg [7:0] data_saved = 8'hFF; // Empezamos con todos apagados (lógica negativa)

    // Instancia del receptor
    uart_rx receptor (
        .clk(CLK_50M),
        .rx(UART_RX),
        .data_out(rx_byte),
        .rx_done(rx_ready)
    );

    always @(posedge CLK_50M) begin
        if (rx_ready) begin
            data_saved <= rx_byte;
        end
    end

    // Asignación a los pines que mostraste en el Pin Planner
    // Usamos lógica inversa (~) porque dijiste que tu placa es lógica negativa
    assign D2 = ~data_saved[0];
    assign D3 = ~data_saved[1];
    assign D4 = ~data_saved[2];
    assign D5 = ~data_saved[3];
    assign D6 = ~data_saved[4];
    assign D7 = ~data_saved[5];
    assign D8 = ~data_saved[6];
    assign D9 = ~data_saved[7];
    
    // El D10 lo dejamos como indicador de que llega señal (parpadeo rápido)
    assign D10 = UART_RX; 

endmodule





