module pantallatop (
    input  wire clk,
    output reg  tft_cs,
    output reg  tft_rst,
    output reg  tft_dc,
    output reg  tft_mosi,
    output reg  tft_sck,
    output wire tft_led
);

assign tft_led = 1'b1;

parameter COLOR_H = 8'h00;
parameter COLOR_L = 8'h00;

reg [7:0]  shift_reg;
reg [3:0]  bit_cnt;
reg [24:0] delay_cnt;
reg [6:0]  cmd_idx;
reg [16:0] pix_cnt;
reg [4:0]  state;
reg [4:0]  ret_state;
reg [8:0]  px;
reg [8:0]  py;

// ===== INICIALIZACIÓN EXPLÍCITA =====
initial begin
    state     = 0;  // RESET1
    tft_rst   = 0;
    tft_cs    = 1;
    tft_sck   = 0;
    tft_dc    = 0;
    tft_mosi  = 0;
    delay_cnt = 0;
    cmd_idx   = 0;
    pix_cnt   = 0;
    ret_state = 0;
    shift_reg = 0;
    bit_cnt   = 0;
	 px        = 0;
	 py        = 0;
end

localparam  RESET1   = 0,
            RESET2   = 1,
            CMD_LOAD = 2,
            CMD_SEND = 3,
            CMD_CLK  = 4,
            CMD_NEXT = 5,
            DELAY    = 6,
            PIX_H    = 7,
            PIX_H_TX = 8,
            PIX_H_CK = 9,
            PIX_L    = 10,
            PIX_L_TX = 11,
            PIX_L_CK = 12,
            PIX_NEXT = 13,
            DONE     = 14;

reg [8:0] cmds [0:45];

initial begin
    cmds[0]  = {1'b0, 8'hCF};
    cmds[1]  = {1'b1, 8'h00};
    cmds[2]  = {1'b1, 8'hC1};
    cmds[3]  = {1'b1, 8'h30};
    cmds[4]  = {1'b0, 8'hED};
    cmds[5]  = {1'b1, 8'h64};
    cmds[6]  = {1'b1, 8'h03};
    cmds[7]  = {1'b1, 8'h12};
    cmds[8]  = {1'b1, 8'h81};
    cmds[9]  = {1'b0, 8'hE8};
    cmds[10] = {1'b1, 8'h85};
    cmds[11] = {1'b1, 8'h00};
    cmds[12] = {1'b1, 8'h78};
    cmds[13] = {1'b0, 8'hCB};
    cmds[14] = {1'b1, 8'h39};
    cmds[15] = {1'b1, 8'h2C};
    cmds[16] = {1'b1, 8'h00};
    cmds[17] = {1'b1, 8'h34};
    cmds[18] = {1'b1, 8'h02};
    cmds[19] = {1'b0, 8'hF7};
    cmds[20] = {1'b1, 8'h20};
    cmds[21] = {1'b0, 8'hEA};
    cmds[22] = {1'b1, 8'h00};
    cmds[23] = {1'b1, 8'h00};
    cmds[24] = {1'b0, 8'h36};
    cmds[25] = {1'b1, 8'hC8};
    cmds[26] = {1'b0, 8'h3A};
    cmds[27] = {1'b1, 8'h55};
    cmds[28] = {1'b0, 8'hB1};
    cmds[29] = {1'b1, 8'h00};
    cmds[30] = {1'b1, 8'h1B};
    cmds[31] = {1'b0, 8'hB6};
    cmds[32] = {1'b1, 8'h0A};
    cmds[33] = {1'b1, 8'h82};
    cmds[34] = {1'b1, 8'h27};
    cmds[35] = {1'b0, 8'h11}; // Sleep Out
    cmds[36] = {1'b0, 8'h29}; // Display ON
    cmds[37] = {1'b0, 8'h2A}; // Column
    cmds[38] = {1'b1, 8'h00};
    cmds[39] = {1'b1, 8'h00};
    cmds[40] = {1'b1, 8'h00};
    cmds[41] = {1'b1, 8'hEF};
    cmds[42] = {1'b0, 8'h2B}; // Row
    cmds[43] = {1'b1, 8'h00};
    cmds[44] = {1'b1, 8'h00};
    cmds[45] = {1'b1, 8'h01};
end

always @(posedge clk) begin
    case (state)

        RESET1: begin
            tft_rst   <= 0;
            tft_cs    <= 1;
            tft_sck   <= 0;
            delay_cnt <= delay_cnt + 1;
            if (delay_cnt == 25'h1FFFFFF) begin
                tft_rst   <= 1;
                delay_cnt <= 0;
                state     <= RESET2;
            end
        end

        RESET2: begin
            delay_cnt <= delay_cnt + 1;
            if (delay_cnt == 25'h1FFFFFF) begin
                delay_cnt <= 0;
                cmd_idx   <= 0;
                state     <= CMD_LOAD;
            end
        end

        CMD_LOAD: begin
            if (cmd_idx < 46) begin
                tft_dc    <= cmds[cmd_idx][8];
                shift_reg <= cmds[cmd_idx][7:0];
                bit_cnt   <= 7;
                tft_cs    <= 0;
                tft_sck   <= 0;
                tft_mosi  <= cmds[cmd_idx][7];
                state     <= CMD_SEND;
            end else if (cmd_idx == 46) begin
                // Envía 0x3F último dato row
                tft_dc    <= 1;
                shift_reg <= 8'h3F;
                bit_cnt   <= 7;
                tft_cs    <= 0;
                tft_sck   <= 0;
                tft_mosi  <= 1'b0;
                state     <= CMD_SEND;
            end else if (cmd_idx == 47) begin
                // Envía 0x2C memory write
                tft_dc    <= 0;
                shift_reg <= 8'h2C;
                bit_cnt   <= 7;
                tft_cs    <= 0;
                tft_sck   <= 0;
                tft_mosi  <= 1'b0;
                state     <= CMD_SEND;
            end else begin
                // Empieza píxeles
                pix_cnt <= 0;
                state   <= PIX_H;
            end
        end

        CMD_SEND: begin
            tft_sck <= 1;
            state   <= CMD_CLK;
        end

        CMD_CLK: begin
            tft_sck <= 0;
            if (bit_cnt == 0) begin
                tft_cs <= 1;
                state  <= CMD_NEXT;
            end else begin
                bit_cnt   <= bit_cnt - 1;
                shift_reg <= shift_reg << 1;
                tft_mosi  <= shift_reg[6];
                state     <= CMD_SEND;
            end
        end

        CMD_NEXT: begin
            cmd_idx <= cmd_idx + 1;
            if (cmd_idx == 35) begin
                // Delay 120ms tras Sleep Out
                delay_cnt <= 0;
                state     <= DELAY;
            end else begin
                state <= CMD_LOAD;
            end
        end

        DELAY: begin
            delay_cnt <= delay_cnt + 1;
            if (delay_cnt == 25'd6000000) begin
                delay_cnt <= 0;
                state     <= CMD_LOAD;
            end
        end

        // ===== BYTE ALTO =====
        PIX_H: begin
            tft_dc   <= 1;
            tft_cs   <= 0;
            tft_sck  <= 0;
            bit_cnt  <= 7;
            // FPGA Encryptor
            // px=fila, py=columna
            // Texto centrado: px 150-166, py 8-232
            // 14 chars x 16px = 224px
            if (px >= 150 && px < 166 &&
                py >= 8   && py < 232) begin
                case ((py - 8'd8) >> 4)
                    // F
                    4'd0: case((px-9'd150)>>1)
                        3'd0: shift_reg <= 8'h07;
                        3'd1,3'd2: shift_reg <= (((py-8'd8)&4'hF)>>1==0) ? 8'h07:8'h00;
                        3'd3: shift_reg <= (((py-8'd8)&4'hF)>>1<=4) ? 8'h07:8'h00;
                        3'd4,3'd5,3'd6: shift_reg <= (((py-8'd8)&4'hF)>>1==0) ? 8'h07:8'h00;
                        default: shift_reg <= 8'h00;
                    endcase
                    // P
                    4'd1: case((px-9'd150)>>1)
                        3'd0: shift_reg <= (((py-8'd8)&4'hF)>>1<=5) ? 8'h07:8'h00;
                        3'd1: shift_reg <= (((py-8'd8)&4'hF)>>1==0||((py-8'd8)&4'hF)>>1==6) ? 8'h07:8'h00;
                        3'd2: shift_reg <= (((py-8'd8)&4'hF)>>1<=5) ? 8'h07:8'h00;
                        3'd3,3'd4,3'd5,3'd6: shift_reg <= (((py-8'd8)&4'hF)>>1==0) ? 8'h07:8'h00;
                        default: shift_reg <= 8'h00;
                    endcase
                    // G
                    4'd2: case((px-9'd150)>>1)
                        3'd0: shift_reg <= (((py-8'd8)&4'hF)>>1>=1&&((py-8'd8)&4'hF)>>1<=6) ? 8'h07:8'h00;
                        3'd1,3'd2: shift_reg <= (((py-8'd8)&4'hF)>>1==0) ? 8'h07:8'h00;
                        3'd3: shift_reg <= (((py-8'd8)&4'hF)>>1==0||((py-8'd8)&4'hF)>>1>=4) ? 8'h07:8'h00;
                        3'd4,3'd5: shift_reg <= (((py-8'd8)&4'hF)>>1==0||((py-8'd8)&4'hF)>>1==7) ? 8'h07:8'h00;
                        3'd6: shift_reg <= (((py-8'd8)&4'hF)>>1>=1&&((py-8'd8)&4'hF)>>1<=6) ? 8'h07:8'h00;
                        default: shift_reg <= 8'h00;
                    endcase
                    // A
                    4'd3: case((px-9'd150)>>1)
                        3'd0: shift_reg <= (((py-8'd8)&4'hF)>>1>=2&&((py-8'd8)&4'hF)>>1<=5) ? 8'h07:8'h00;
                        3'd1: shift_reg <= (((py-8'd8)&4'hF)>>1==1||((py-8'd8)&4'hF)>>1==6) ? 8'h07:8'h00;
                        3'd2,3'd4,3'd5,3'd6: shift_reg <= (((py-8'd8)&4'hF)>>1==0||((py-8'd8)&4'hF)>>1==7) ? 8'h07:8'h00;
                        3'd3: shift_reg <= 8'h07;
                        default: shift_reg <= 8'h00;
                    endcase
                    // Espacio
                    4'd4: shift_reg <= 8'h00;
                    // E
                    4'd5: case((px-9'd150)>>1)
                        3'd0,3'd6: shift_reg <= 8'h07;
                        3'd1,3'd2: shift_reg <= (((py-8'd8)&4'hF)>>1==0) ? 8'h07:8'h00;
                        3'd3: shift_reg <= (((py-8'd8)&4'hF)>>1<=5) ? 8'h07:8'h00;
                        3'd4,3'd5: shift_reg <= (((py-8'd8)&4'hF)>>1==0) ? 8'h07:8'h00;
                        default: shift_reg <= 8'h00;
                    endcase
                    // n
                    4'd6: case((px-9'd150)>>1)
                        3'd0: shift_reg <= (((py-8'd8)&4'hF)>>1>=1&&((py-8'd8)&4'hF)>>1<=6) ? 8'h07:8'h00;
                        3'd1,3'd2,3'd3,3'd4,3'd5,3'd6: shift_reg <= (((py-8'd8)&4'hF)>>1==0||((py-8'd8)&4'hF)>>1==7) ? 8'h07:8'h00;
                        default: shift_reg <= 8'h00;
                    endcase
                    // c
                    4'd7: case((px-9'd150)>>1)
                        3'd0,3'd6: shift_reg <= (((py-8'd8)&4'hF)>>1>=1&&((py-8'd8)&4'hF)>>1<=6) ? 8'h07:8'h00;
                        3'd1,3'd2,3'd3,3'd4,3'd5: shift_reg <= (((py-8'd8)&4'hF)>>1==0) ? 8'h07:8'h00;
                        default: shift_reg <= 8'h00;
                    endcase
                    // r
                    4'd8: case((px-9'd150)>>1)
                        3'd0: shift_reg <= (((py-8'd8)&4'hF)>>1>=1&&((py-8'd8)&4'hF)>>1<=5) ? 8'h07:8'h00;
                        3'd1: shift_reg <= (((py-8'd8)&4'hF)>>1==0||((py-8'd8)&4'hF)>>1==6) ? 8'h07:8'h00;
                        3'd2,3'd3,3'd4,3'd5,3'd6: shift_reg <= (((py-8'd8)&4'hF)>>1==0) ? 8'h07:8'h00;
                        default: shift_reg <= 8'h00;
                    endcase
                    // y
                    4'd9: case((px-9'd150)>>1)
                        3'd0,3'd1: shift_reg <= (((py-8'd8)&4'hF)>>1==0||((py-8'd8)&4'hF)>>1==7) ? 8'h07:8'h00;
                        3'd2,3'd3: shift_reg <= (((py-8'd8)&4'hF)>>1>=1&&((py-8'd8)&4'hF)>>1<=6) ? 8'h07:8'h00;
                        3'd4,3'd5,3'd6: shift_reg <= (((py-8'd8)&4'hF)>>1==3||((py-8'd8)&4'hF)>>1==4) ? 8'h07:8'h00;
                        default: shift_reg <= 8'h00;
                    endcase
                    // p
                    4'd10: case((px-9'd150)>>1)
                        3'd0: shift_reg <= (((py-8'd8)&4'hF)>>1<=5) ? 8'h07:8'h00;
                        3'd1: shift_reg <= (((py-8'd8)&4'hF)>>1==0||((py-8'd8)&4'hF)>>1==6) ? 8'h07:8'h00;
                        3'd2: shift_reg <= (((py-8'd8)&4'hF)>>1<=5) ? 8'h07:8'h00;
                        3'd3,3'd4,3'd5,3'd6: shift_reg <= (((py-8'd8)&4'hF)>>1==0) ? 8'h07:8'h00;
                        default: shift_reg <= 8'h00;
                    endcase
                    // t
                    4'd11: case((px-9'd150)>>1)
                        3'd0,3'd1: shift_reg <= (((py-8'd8)&4'hF)>>1==3||((py-8'd8)&4'hF)>>1==4) ? 8'h07:8'h00;
                        3'd2: shift_reg <= 8'h07;
                        3'd3,3'd4,3'd5: shift_reg <= (((py-8'd8)&4'hF)>>1==3||((py-8'd8)&4'hF)>>1==4) ? 8'h07:8'h00;
                        3'd6: shift_reg <= (((py-8'd8)&4'hF)>>1>=4&&((py-8'd8)&4'hF)>>1<=6) ? 8'h07:8'h00;
                        default: shift_reg <= 8'h00;
                    endcase
                    // o
                    4'd12: case((px-9'd150)>>1)
                        3'd0,3'd6: shift_reg <= (((py-8'd8)&4'hF)>>1>=1&&((py-8'd8)&4'hF)>>1<=6) ? 8'h07:8'h00;
                        3'd1,3'd2,3'd3,3'd4,3'd5: shift_reg <= (((py-8'd8)&4'hF)>>1==0||((py-8'd8)&4'hF)>>1==7) ? 8'h07:8'h00;
                        default: shift_reg <= 8'h00;
                    endcase
                    // r
                    4'd13: case((px-9'd150)>>1)
                        3'd0: shift_reg <= (((py-8'd8)&4'hF)>>1>=1&&((py-8'd8)&4'hF)>>1<=5) ? 8'h07:8'h00;
                        3'd1: shift_reg <= (((py-8'd8)&4'hF)>>1==0||((py-8'd8)&4'hF)>>1==6) ? 8'h07:8'h00;
                        3'd2,3'd3,3'd4,3'd5,3'd6: shift_reg <= (((py-8'd8)&4'hF)>>1==0) ? 8'h07:8'h00;
                        default: shift_reg <= 8'h00;
                    endcase
                    default: shift_reg <= 8'h00;
                endcase
                tft_mosi <= shift_reg[7];
            end else begin
                shift_reg <= 8'h00;
                tft_mosi  <= 1'b0;
            end
            state <= PIX_H_TX;
        end

        

        PIX_H_TX: begin
            tft_sck <= 1;
            state   <= PIX_H_CK;
        end

        PIX_H_CK: begin
            tft_sck <= 0;
            if (bit_cnt == 0) begin
                state <= PIX_L;
            end else begin
                bit_cnt   <= bit_cnt - 1;
                shift_reg <= shift_reg << 1;
                tft_mosi  <= shift_reg[6];
                state     <= PIX_H_TX;
            end
        end

        // ===== BYTE BAJO =====
        PIX_L: begin
            if (shift_reg == 8'h07)
                shift_reg <= 8'hE0;
            else
                shift_reg <= 8'h00;
            tft_mosi <= shift_reg[7];
            bit_cnt  <= 7;
            tft_sck  <= 0;
            state    <= PIX_L_TX;
        end

        PIX_L_TX: begin
            tft_sck <= 1;
            state   <= PIX_L_CK;
        end

        PIX_L_CK: begin
            tft_sck <= 0;
            if (bit_cnt == 0) begin
                state <= PIX_NEXT;
            end else begin
                bit_cnt   <= bit_cnt - 1;
                shift_reg <= shift_reg << 1;
                tft_mosi  <= shift_reg[6];
                state     <= PIX_L_TX;
            end
        end

        PIX_NEXT: begin
            pix_cnt <= pix_cnt + 1;
            if (px == 239) begin
                px <= 0;
                py <= py + 1;
            end else
                px <= px + 1;
            if (py == 319 && px == 239) begin
                tft_cs <= 1;
                state  <= DONE;
            end else if (pix_cnt >= 96000) begin
                tft_cs <= 1;
                state  <= DONE;
            end else
                state <= PIX_H;
        end
        DONE: begin
            tft_cs <= 1;
        end

        default: state <= RESET1;

    endcase
end
endmodule