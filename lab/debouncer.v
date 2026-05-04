module debouncer (
    input clk, btn_in,
    output reg btn_out
);
    reg [15:0] count; 
    always @(posedge clk) begin
        if (btn_in == btn_out) count <= 0;
        else begin
            count <= count + 1;
            if (count == 16'hFFFF) btn_out <= btn_in;
        end
    end
endmodule
