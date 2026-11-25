
module router_reg (
    input wire wr_clk,
    input wire wrst_n,
    input wire pkt_valid,
    input wire [7:0] data_in,
    input wire fifo_full,
    input wire rst_int_reg,
    input wire detect_add,
    input wire ld_state,
    input wire laf_state,
    input wire full_state,
    input wire lfd_state,
    output reg parity_done,
    output reg low_pkt_valid,
    output reg err,
    output reg [7:0] dout
);

    reg [7:0] header;
    reg [7:0] FIFO_full_state;
    reg [7:0] internal_parity;
    reg [7:0] pkt_parity;

    // Parity Done signal logic
    always @(posedge wr_clk or negedge wrst_n) begin
        if (!wrst_n) begin
            parity_done <= 1'b0;
        end else if (detect_add) begin
            parity_done <= 1'b0;
        end else if ((ld_state && !fifo_full && !pkt_valid) || (laf_state && low_pkt_valid && !parity_done)) begin
            parity_done <= 1'b1;
        end
    end

    // Low packet valid signal logic
    always @(posedge wr_clk or negedge wrst_n) begin
        if (!wrst_n) begin
            low_pkt_valid <= 1'b0;
        end else if (rst_int_reg) begin
            low_pkt_valid <= 1'b0;
        end else if (ld_state && !pkt_valid) begin
            low_pkt_valid <= 1'b1;
        end
    end

    // Header Register logic
    always @(posedge wr_clk or negedge wrst_n) begin
        if (!wrst_n) begin
            header <= 8'd0;
        end else if (detect_add && pkt_valid && data_in[1:0] != 2'd3) begin
            header <= data_in;
        end
    end

    // FIFO Full-state Register logic
    always @(posedge wr_clk or negedge wrst_n) begin
        if (!wrst_n) begin
            FIFO_full_state <= 8'd0;
        end else if (ld_state && fifo_full) begin
            FIFO_full_state <= data_in;
        end
    end

    // Internal Parity Register logic
    always @(posedge wr_clk or negedge wrst_n) begin
        if (!wrst_n) begin
            internal_parity <= 8'd0;
        end else if (detect_add && pkt_valid) begin
            internal_parity <= 8'd0;
        end else if (lfd_state) begin
            internal_parity <= internal_parity ^ header;
        end else if (ld_state && !full_state && pkt_valid) begin
            internal_parity <= internal_parity ^ data_in;
        end
    end

    // Packet Parity Register logic
    always @(posedge wr_clk or negedge wrst_n) begin
        if (!wrst_n) begin
            pkt_parity <= 8'd0;
        end else if (detect_add) begin
            pkt_parity <= 8'd0;
        end else if (ld_state && !pkt_valid) begin
            pkt_parity <= data_in;
        end
    end

    // Error Checking logic
    always @(posedge wr_clk or negedge wrst_n) begin
        if (!wrst_n) begin
            err <= 1'b0;
        end else if (parity_done) begin
            err <= (internal_parity != pkt_parity);
        end else begin
            err <= 1'b0;
        end
    end

    // Data-out logic
    always @(posedge wr_clk or negedge wrst_n) begin
        if (!wrst_n) begin
            dout <= 8'd0;
        end else if (lfd_state) begin
            dout <= header;
        end else if (laf_state) begin
            dout <= FIFO_full_state;
        end else if (ld_state && !fifo_full) begin
            dout <= data_in;
        end
    end

endmodule









