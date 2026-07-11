// =============================================================================
// uart_rx.v — Receptor UART para FPGA Altera Cyclone IV (A-C4E6E10)
// Reloj: 50 MHz — Baudrate: 9600 bps — CLKS_PER_BIT = 5208
// =============================================================================

module uart_rx (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       rx,
    output reg  [7:0] rx_data,
    output reg        rx_ready
);

    parameter CLKS_PER_BIT = 1250;
    parameter HALF_BIT     = 625;

    localparam IDLE = 3'd0;
    localparam START = 3'd1;
    localparam DATA  = 3'd2;
    localparam STOP  = 3'd3;
    localparam DONE  = 3'd4;

    reg [2:0]  state;
    reg [12:0] clk_cnt;
    reg [2:0]  bit_idx;
    reg [7:0]  rx_shift;

    // Sincronizador — atributo keep para evitar optimizacion
    (* keep = "true" *) reg rx_sync0;
    (* keep = "true" *) reg rx_sync1;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_sync0 <= 1'b1;
            rx_sync1 <= 1'b1;
        end else begin
            rx_sync0 <= rx;
            rx_sync1 <= rx_sync0;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state    <= IDLE;
            clk_cnt  <= 13'd0;
            bit_idx  <= 3'd0;
            rx_shift <= 8'd0;
            rx_data  <= 8'd0;
            rx_ready <= 1'b0;
        end else begin
            rx_ready <= 1'b0;

            case (state)
                IDLE: begin
                    clk_cnt <= 13'd0;
                    bit_idx <= 3'd0;
                    if (rx_sync1 == 1'b0)
                        state <= START;
                end

                START: begin
                    if (clk_cnt == HALF_BIT - 1) begin
                        clk_cnt <= 13'd0;
                        if (rx_sync1 == 1'b0) begin
                            bit_idx <= 3'd0;
                            state   <= DATA;
                        end else
                            state <= IDLE;
                    end else
                        clk_cnt <= clk_cnt + 1'b1;
                end

                DATA: begin
                    if (clk_cnt == CLKS_PER_BIT - 1) begin
                        clk_cnt           <= 13'd0;
                        rx_shift[bit_idx] <= rx_sync1;
                        if (bit_idx == 3'd7)
                            state <= STOP;
                        else
                            bit_idx <= bit_idx + 1'b1;
                    end else
                        clk_cnt <= clk_cnt + 1'b1;
                end

                STOP: begin
                    if (clk_cnt == CLKS_PER_BIT - 1) begin
                        clk_cnt <= 13'd0;
                        state   <= DONE;
                    end else
                        clk_cnt <= clk_cnt + 1'b1;
                end

                DONE: begin
                    rx_data  <= rx_shift;
                    rx_ready <= 1'b1;
                    state    <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule

