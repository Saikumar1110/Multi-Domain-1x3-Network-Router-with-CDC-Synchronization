module rd_pointer #(parameter ADDR_WIDTH = 7)
(
    input wire rclk,
    input wire rrst_n, 
    input wire r_en,
    input wire [ADDR_WIDTH-1:0] wgray_sync, 
    output reg [ADDR_WIDTH-1:0] rbin,
    output reg [ADDR_WIDTH-1:0] rgray, 
    output reg rempty
);

    wire [ADDR_WIDTH-1:0] rbin_next;
    wire [ADDR_WIDTH-1:0] rgray_next;
    wire rinc;

    // Increment logic safeguarded against under-run
    assign rinc = r_en && !rempty;
    
    // Binary pointer calculation
    assign rbin_next = rbin + rinc;

    // Binary to Gray code conversion
    assign rgray_next = rbin_next ^ (rbin_next >> 1);

    always @(posedge rclk or negedge rrst_n) begin
        if (!rrst_n) begin
            rbin   <= 0;
            rgray  <= 0;
            rempty <= 1'b1;
        end else begin
            rbin   <= rbin_next;
            rgray  <= rgray_next;
            rempty <= (wgray_sync == rgray_next);
        end
    end

endmodule

