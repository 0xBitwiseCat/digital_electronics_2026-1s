module uart_rx (
    input clk,
    input rx,
    output reg [7:0] data_out,
    output reg rx_done
);

    parameter CLK_FREQ = 50000000;
    parameter BAUD_RATE = 9600;
    localparam TICKS_PER_BIT = CLK_FREQ / BAUD_RATE;

    reg [13:0] tick_count = 0; // CORREGIDO: 14 bits para soportar 5208 ticks
    reg [2:0] bit_index = 0;
    reg [1:0] state = 0;

    // Sincronización para evitar metaestabilidad
    reg rx_s1, rx_s2;
    always @(posedge clk) begin
        rx_s1 <= rx;
        rx_s2 <= rx_s1;
    end

    localparam IDLE = 2'b00, START = 2'b01, DATA = 2'b10, STOP = 2'b11;

    always @(posedge clk) begin
        case (state)
            IDLE: begin
                rx_done <= 0;
                tick_count <= 0;
                bit_index <= 0;
                if (rx_s2 == 0) state <= START; // Detecta bit de inicio
            end

            START: begin
                if (tick_count == (TICKS_PER_BIT / 2)) begin
                    if (rx_s2 == 0) begin
                        tick_count <= 0;
                        state <= DATA;
                    end else state <= IDLE;
                end else tick_count <= tick_count + 1;
            end

            DATA: begin
                if (tick_count == TICKS_PER_BIT - 1) begin
                    tick_count <= 0;
                    data_out[bit_index] <= rx_s2;
                    if (bit_index == 7) state <= STOP;
                    else bit_index <= bit_index + 1;
                end else tick_count <= tick_count + 1;
            end

            STOP: begin
                if (tick_count == TICKS_PER_BIT - 1) begin
                    rx_done <= 1;
                    state <= IDLE;
                end else tick_count <= tick_count + 1;
            end
        endcase
    end
endmodule




