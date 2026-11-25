

module router_read_wrapper (
    input wire rd_clk,
    input wire rrst_n,
    input wire read_enb,
    input wire empty,             // Arrives directly from Async FIFO
    input wire [8:0] fifo_rdata,  // 9-bit data from Async FIFO
    output reg [7:0] data_out,    // 8-bit data to destination network
    output reg soft_reset_rd      // Timeout flag sent back to synchronizer
);

    reg [6:0] payload_count;
    reg [4:0] clk_counter;
    wire payload_count_wire;
    wire vld_out;

    // The data is valid whenever the FIFO is not empty
    assign vld_out = !empty;
    assign payload_count_wire = (payload_count == 7'd1) ? 1'b1 : 1'b0;

    // 1. The 30-Cycle Timeout Logic (Moved from Synchronizer)
    always @(posedge rd_clk or negedge rrst_n) begin
        if (!rrst_n) begin
            clk_counter <= 5'd0;
            soft_reset_rd <= 1'b0;
        end else begin
            if (vld_out) begin
                if (read_enb) begin
                    clk_counter <= 5'd0;
                    soft_reset_rd <= 1'b0;
                end else if (clk_counter < 5'd30) begin
                    clk_counter <= clk_counter + 1'b1;
                    soft_reset_rd <= 1'b0;
                end else begin
                    clk_counter <= 5'd0;
                    soft_reset_rd <= 1'b1; // Trigger soft reset
                end
            end else begin
                clk_counter <= 5'd0;
                soft_reset_rd <= 1'b0;
            end
        end
    end

    // 2. The Smart Payload Tracking Logic
    always @(posedge rd_clk or negedge rrst_n) begin
        if (!rrst_n) begin
            payload_count <= 7'd0;
            data_out <= 8'bzz;
        end else if (soft_reset_rd) begin // Flush wrapper on timeout
            payload_count <= 7'd0;
            data_out <= 8'bzz;
        end else if (read_enb && !empty) begin
            
            // Check 9th bit for header
            if (fifo_rdata[8] == 1'b1) begin
                payload_count <= fifo_rdata[7:2] + 7'd2;
                data_out <= fifo_rdata[7:0];
                
            // Process payload bytes
            end else if (payload_count != 7'd1) begin
                payload_count <= payload_count - 7'd1;
                data_out <= fifo_rdata[7:0];
                
            end else begin
                data_out <= data_out;
            end
            
        // Tri-state output at packet boundary
        end else if (payload_count_wire) begin
            data_out <= 8'bzz;
            payload_count <= 7'd0;
        end else begin
            data_out <= data_out;
        end
    end

endmodule
