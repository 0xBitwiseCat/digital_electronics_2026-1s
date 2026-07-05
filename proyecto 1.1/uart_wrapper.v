// =============================================================================
// uart_wrapper.v — Controlador Principal (FSM) para PRESENT-80
// FPGA: Altera Cyclone IV (A-C4E6E10) — Reloj: 12 MHz
// =============================================================================

module uart_wrapper (
    input  wire        clk,
    input  wire        rst_n,

    // Interfaz con uart_rx
    input  wire [7:0]  rx_data,
    input  wire        rx_ready,

    // Interfaz con uart_tx
    output reg  [7:0]  tx_data,
    output reg         tx_start,
    input  wire        tx_busy,

    // Interfaz con present_80_core
    output reg  [63:0] plaintext,
    output reg  [79:0] key_out,
    output reg         start,
    input  wire [63:0] ciphertext,
    input  wire        done,

    // Debug: estado visible en 7 segmentos
    output reg  [3:0]  debug_state
);

    // -------------------------------------------------------------------------
    // Estados
    // -------------------------------------------------------------------------
    localparam S_IDLE      = 4'd0;
    localparam S_RECV      = 4'd1;
    localparam S_CHECK_CRC = 4'd2;
    localparam S_START_CORE= 4'd3;
    localparam S_WAIT_CORE = 4'd4;
    localparam S_PREP_TX   = 4'd5;
    localparam S_SEND_WAIT = 4'd6;
    localparam S_SEND_BYTE = 4'd7;
    localparam S_DONE      = 4'd8;

    // -------------------------------------------------------------------------
    // Registros internos
    // -------------------------------------------------------------------------
    reg [3:0]  state;
    reg [4:0]  byte_cnt;
    reg [4:0]  tx_cnt;
    reg [7:0]  rx_buf[0:18];
    reg [7:0]  tx_buf[0:8];
    reg [7:0]  crc_calc;
    reg [7:0]  crc_tx_reg;

    // -------------------------------------------------------------------------
    // CRC-8 función (polinomio 0x07)
    // -------------------------------------------------------------------------
    function [7:0] crc8_byte;
        input [7:0] crc_in;
        input [7:0] data;
        reg [7:0] crc;
        integer i;
        begin
            crc = crc_in ^ data;
            for (i = 0; i < 8; i = i + 1) begin
                if (crc[7])
                    crc = (crc << 1) ^ 8'h07;
                else
                    crc = crc << 1;
            end
            crc8_byte = crc;
        end
    endfunction

    // -------------------------------------------------------------------------
    // FSM Principal
    // -------------------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state       <= S_IDLE;
            byte_cnt    <= 5'd0;
            tx_cnt      <= 5'd0;
            crc_calc    <= 8'd0;
            crc_tx_reg  <= 8'd0;
            tx_start    <= 1'b0;
            tx_data     <= 8'd0;
            start       <= 1'b0;
            plaintext   <= 64'd0;
            key_out     <= 80'd0;
            debug_state <= 4'd0;
        end else begin
            tx_start <= 1'b0;
            start    <= 1'b0;

            case (state)

                // -------------------------------------------------------------
                // IDLE: Espera primer byte
                // -------------------------------------------------------------
                S_IDLE: begin
                    debug_state <= 4'd0;
                    byte_cnt    <= 5'd0;
                    crc_calc    <= 8'd0;

                    if (rx_ready) begin
                        rx_buf[0] <= rx_data;
                        crc_calc  <= crc8_byte(8'd0, rx_data);
                        byte_cnt  <= 5'd1;
                        state     <= S_RECV;
                    end
                end

                // -------------------------------------------------------------
                // RECV: Acumula 19 bytes
                // -------------------------------------------------------------
                S_RECV: begin
                    debug_state <= 4'd1;

                    if (rx_ready) begin
                        rx_buf[byte_cnt] <= rx_data;

                        if (byte_cnt < 5'd18)
                            crc_calc <= crc8_byte(crc_calc, rx_data);

                        if (byte_cnt == 5'd18)
                            state <= S_CHECK_CRC;
                        else
                            byte_cnt <= byte_cnt + 1'b1;
                    end
                end

                // -------------------------------------------------------------
                // CHECK_CRC: Verifica integridad
                // -------------------------------------------------------------
                S_CHECK_CRC: begin
                    debug_state <= 4'd2;

                    if (crc_calc == rx_buf[18]) begin
                        // Ensambla plaintext (bytes 0-7)
                        plaintext <= { rx_buf[0], rx_buf[1], rx_buf[2], rx_buf[3],
                                       rx_buf[4], rx_buf[5], rx_buf[6], rx_buf[7] };
                        // Ensambla key (bytes 8-17)
                        key_out   <= { rx_buf[8],  rx_buf[9],  rx_buf[10], rx_buf[11],
                                       rx_buf[12], rx_buf[13], rx_buf[14], rx_buf[15],
                                       rx_buf[16], rx_buf[17] };
                        state <= S_START_CORE;
                    end else begin
                        state <= S_IDLE;
                    end
                end

                // -------------------------------------------------------------
                // START_CORE: Dispara el core por 1 ciclo
                // -------------------------------------------------------------
                S_START_CORE: begin
                    debug_state <= 4'd3;
                    start       <= 1'b1;
                    state       <= S_WAIT_CORE;
                end

                // -------------------------------------------------------------
                // WAIT_CORE: Espera que done llegue
                // -------------------------------------------------------------
                S_WAIT_CORE: begin
                    debug_state <= 4'd4;

                    if (done) begin
                        state <= S_PREP_TX;
                    end
                end

                // -------------------------------------------------------------
                // PREP_TX: Arma buffer de salida y calcula CRC
                // -------------------------------------------------------------
                S_PREP_TX: begin
                    debug_state <= 4'd5;

                    tx_buf[0] <= ciphertext[63:56];
                    tx_buf[1] <= ciphertext[55:48];
                    tx_buf[2] <= ciphertext[47:40];
                    tx_buf[3] <= ciphertext[39:32];
                    tx_buf[4] <= ciphertext[31:24];
                    tx_buf[5] <= ciphertext[23:16];
                    tx_buf[6] <= ciphertext[15:8];
                    tx_buf[7] <= ciphertext[7:0];

                    // CRC del ciphertext calculado paso a paso
                    crc_tx_reg <= crc8_byte(
                                    crc8_byte(
                                      crc8_byte(
                                        crc8_byte(
                                          crc8_byte(
                                            crc8_byte(
                                              crc8_byte(
                                                crc8_byte(8'd0, ciphertext[63:56]),
                                                ciphertext[55:48]),
                                              ciphertext[47:40]),
                                            ciphertext[39:32]),
                                          ciphertext[31:24]),
                                        ciphertext[23:16]),
                                      ciphertext[15:8]),
                                    ciphertext[7:0]);

                    tx_cnt <= 5'd0;
                    state  <= S_SEND_WAIT;
                end

                // -------------------------------------------------------------
                // SEND_WAIT: Espera TX libre
                // -------------------------------------------------------------
                S_SEND_WAIT: begin
                    debug_state <= 4'd6;

                    // Carga el CRC en el último slot cuando llegamos al byte 8
                    if (tx_cnt == 5'd8)
                        tx_buf[8] <= crc_tx_reg;

                    if (!tx_busy) begin
                        tx_data  <= (tx_cnt == 5'd8) ? crc_tx_reg : tx_buf[tx_cnt];
                        tx_start <= 1'b1;
                        state    <= S_SEND_BYTE;
                    end
                end

                // -------------------------------------------------------------
                // SEND_BYTE: Espera confirmación TX
                // -------------------------------------------------------------
                S_SEND_BYTE: begin
                    debug_state <= 4'd7;

                    if (tx_busy) begin
                        if (tx_cnt == 5'd8)
                            state <= S_DONE;
                        else begin
                            tx_cnt <= tx_cnt + 1'b1;
                            state  <= S_SEND_WAIT;
                        end
                    end
                end

                // -------------------------------------------------------------
                // DONE: Vuelve a IDLE
                // -------------------------------------------------------------
                S_DONE: begin
                    debug_state <= 4'd8;
                    state       <= S_IDLE;
                end

                default: state <= S_IDLE;

            endcase
        end
    end

endmodule

