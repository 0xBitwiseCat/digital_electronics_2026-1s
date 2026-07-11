
// uart_tx.v — Transmisor UART para FPGA Altera Cyclone IV (A-C4E6E10)
// Reloj:    50 MHz
// Baudrate: 9600 bps  →  CLKS_PER_BIT = 50_000_000 / 9600 = 5208
// Formato:  8N1 (8 bits de datos, sin paridad, 1 bit de stop)
//
// Señales:
//   clk        — Reloj del sistema (12 MHz)
//   rst_n      — Reset activo en bajo
//   tx_start   — Pulso de 1 ciclo: iniciar transmisión del byte en tx_data
//   tx_data    — Byte a transmitir (debe estar estable cuando tx_start sube)
//   tx         — Línea serie TX (va al CH340 / USB → Python)
//   tx_busy    — Alto mientras está transmitiendo (no enviar nuevo dato)
// =============================================================================

module uart_tx (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       tx_start,
    input  wire [7:0] tx_data,
    output reg        tx,
    output reg        tx_busy
);

    // -------------------------------------------------------------------------
    // Parámetros de temporización
    // -------------------------------------------------------------------------
    parameter CLKS_PER_BIT = 1250;

    // -------------------------------------------------------------------------
    // Estados de la máquina de estados
    // -------------------------------------------------------------------------
    localparam IDLE  = 3'd0;
    localparam START = 3'd1;
    localparam DATA  = 3'd2;
    localparam STOP  = 3'd3;

    // -------------------------------------------------------------------------
    // Registros internos
    // -------------------------------------------------------------------------
    reg [2:0]  state;
    reg [12:0] clk_cnt;   // Contador de ciclos por bit
    reg [2:0]  bit_idx;   // Índice del bit actual (0–7)
    reg [7:0]  tx_shift;  // Registro de desplazamiento

    // -------------------------------------------------------------------------
    // Máquina de estados principal
    // -------------------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state    <= IDLE;
            clk_cnt  <= 13'd0;
            bit_idx  <= 3'd0;
            tx_shift <= 8'd0;
            tx       <= 1'b1;   // Línea en reposo = HIGH (estándar UART)
            tx_busy  <= 1'b0;
        end else begin
            case (state)

                // ---------------------------------------------------------
                // IDLE: Línea en reposo, espera orden de transmisión
                // ---------------------------------------------------------
                IDLE: begin
                    tx      <= 1'b1;
                    tx_busy <= 1'b0;
                    clk_cnt <= 13'd0;
                    bit_idx <= 3'd0;

                    if (tx_start) begin
                        tx_shift <= tx_data;  // Captura el byte a enviar
                        tx_busy  <= 1'b1;
                        state    <= START;
                    end
                end

                // ---------------------------------------------------------
                // START: Envía el bit de inicio (LOW durante 1 período)
                // ---------------------------------------------------------
                START: begin
                    tx <= 1'b0;  // Bit de start = LOW

                    if (clk_cnt == CLKS_PER_BIT - 1) begin
                        clk_cnt <= 13'd0;
                        bit_idx <= 3'd0;
                        state   <= DATA;
                    end else begin
                        clk_cnt <= clk_cnt + 1'b1;
                    end
                end

                // ---------------------------------------------------------
                // DATA: Envía 8 bits de datos, LSB primero
                // ---------------------------------------------------------
                DATA: begin
                    tx <= tx_shift[bit_idx];  // Bit actual (LSB primero)

                    if (clk_cnt == CLKS_PER_BIT - 1) begin
                        clk_cnt <= 13'd0;
                        if (bit_idx == 3'd7) begin
                            state <= STOP;
                        end else begin
                            bit_idx <= bit_idx + 1'b1;
                        end
                    end else begin
                        clk_cnt <= clk_cnt + 1'b1;
                    end
                end

                // ---------------------------------------------------------
                // STOP: Envía el bit de stop (HIGH durante 1 período)
                // ---------------------------------------------------------
                STOP: begin
                    tx <= 1'b1;  // Bit de stop = HIGH

                    if (clk_cnt == CLKS_PER_BIT - 1) begin
                        clk_cnt <= 13'd0;
                        tx_busy <= 1'b0;
                        state   <= IDLE;
                    end else begin
                        clk_cnt <= clk_cnt + 1'b1;
                    end
                end

                default: begin
                    tx    <= 1'b1;
                    state <= IDLE;
                end

            endcase
        end
    end

endmodule
