
module router_top (
    input wire wr_clk,
    input wire wrst_n,
    input wire pkt_valid,
    input wire [7:0] data_in,
    input wire rd_clk_0,
    input wire rrst_n_0,
    input wire read_enb_0,
    input wire rd_clk_1,
    input wire rrst_n_1,
    input wire read_enb_1,
    input wire rd_clk_2,
    input wire rrst_n_2,
    input wire read_enb_2,

    output wire valid_out_0,
    output wire valid_out_1,
    output wire valid_out_2,
    output wire error,
    output wire busy,
    output wire [7:0] data_out_0,
    output wire [7:0] data_out_1,
    output wire [7:0] data_out_2
);

    // Internal Control and Data Wires
    wire [2:0] write_enb;
    wire lfd_state, detect_add, write_enb_reg, fifo_full, parity_done, low_pkt_valid;
    wire ld_state, laf_state, full_state, rst_int_reg;
    wire [7:0] dout;
    
    // 9-bit Data Bus to Asynchronous FIFOs (Appending Header Marker)
    wire [8:0] fifo_wdata;
    assign fifo_wdata = {lfd_state, dout};

    // FIFO Boundary Flags
    wire empty_0, empty_1, empty_2;
    wire full_0, full_1, full_2;
    
    wire [8:0] fifo_rdata_0, fifo_rdata_1, fifo_rdata_2;
    
    // Asynchronous Soft Resets from Read Wrappers
    wire soft_reset_0_rd, soft_reset_1_rd, soft_reset_2_rd;
    
    // Synchronized Soft Resets to FSM
    wire soft_reset_0_wr, soft_reset_1_wr, soft_reset_2_wr;
    
    // Synchronized Empty Flags to FSM
    wire empty_0_wr, empty_1_wr, empty_2_wr;

    // Valid Out logic (Driven by read-domain empty flags)
    assign valid_out_0 = ~empty_0;
    assign valid_out_1 = ~empty_1;
    assign valid_out_2 = ~empty_2;

    // =========================================================================
    // CHANNEL 0 INSTANTIATIONS (rd_clk_0)
    // =========================================================================
    asynchronous_fifo_top #(.DATA_WIDTH(9), .ADDR_WIDTH(7), .DEPTH(64)) FIFO_0 (
        .wclk(wr_clk), .rclk(rd_clk_0), .rrst_n(rrst_n_0), .wrst_n(wrst_n),
        .w_en(write_enb[0]), .r_en(read_enb_0), .wdata(fifo_wdata),
        .rdata(fifo_rdata_0), .rempty(empty_0), .wfull(full_0)
    );

    router_read_wrapper RW_0 (
        .rd_clk(rd_clk_0), .rrst_n(rrst_n_0), .read_enb(read_enb_0),
        .empty(empty_0), .fifo_rdata(fifo_rdata_0), .data_out(data_out_0),
        .soft_reset_rd(soft_reset_0_rd)
    );

    // =========================================================================
    // CHANNEL 1 INSTANTIATIONS (rd_clk_1)
    // =========================================================================
    asynchronous_fifo_top #(.DATA_WIDTH(9), .ADDR_WIDTH(7), .DEPTH(64)) FIFO_1 (
        .wclk(wr_clk), .rclk(rd_clk_1), .rrst_n(rrst_n_1), .wrst_n(wrst_n),
        .w_en(write_enb[1]), .r_en(read_enb_1), .wdata(fifo_wdata),
        .rdata(fifo_rdata_1), .rempty(empty_1), .wfull(full_1)
    );

    router_read_wrapper RW_1 (
        .rd_clk(rd_clk_1), .rrst_n(rrst_n_1), .read_enb(read_enb_1),
        .empty(empty_1), .fifo_rdata(fifo_rdata_1), .data_out(data_out_1),
        .soft_reset_rd(soft_reset_1_rd)
    );

    // =========================================================================
    // CHANNEL 2 INSTANTIATIONS (rd_clk_2)
    // =========================================================================
    asynchronous_fifo_top #(.DATA_WIDTH(9), .ADDR_WIDTH(7), .DEPTH(64)) FIFO_2 (
        .wclk(wr_clk), .rclk(rd_clk_2), .rrst_n(rrst_n_2), .wrst_n(wrst_n),
        .w_en(write_enb[2]), .r_en(read_enb_2), .wdata(fifo_wdata),
        .rdata(fifo_rdata_2), .rempty(empty_2), .wfull(full_2)
    );

    router_read_wrapper RW_2 (
        .rd_clk(rd_clk_2), .rrst_n(rrst_n_2), .read_enb(read_enb_2),
        .empty(empty_2), .fifo_rdata(fifo_rdata_2), .data_out(data_out_2),
        .soft_reset_rd(soft_reset_2_rd)
    );

    // =========================================================================
    // FEEDBACK SYNCHRONIZERS (Read Domain -> Write Domain for FSM)
    // =========================================================================
    // Passing the asynchronous empty flags into the FSM's 125 MHz clock domain
    synchronizer #(.ADDR_WIDTH(1)) sync_empty_0 ( .clk(wr_clk), .rst_n(wrst_n), .async_in(empty_0), .sync_out(empty_0_wr) );
    synchronizer #(.ADDR_WIDTH(1)) sync_empty_1 ( .clk(wr_clk), .rst_n(wrst_n), .async_in(empty_1), .sync_out(empty_1_wr) );
    synchronizer #(.ADDR_WIDTH(1)) sync_empty_2 ( .clk(wr_clk), .rst_n(wrst_n), .async_in(empty_2), .sync_out(empty_2_wr) );

    // =========================================================================
    // WRITE DOMAIN LOGIC
    // =========================================================================
    router_sync Synchronizer (
        .wr_clk(wr_clk), 
        .wrst_n(wrst_n), 
        .detect_add(detect_add), 
        .data_in(data_in[1:0]),
        .write_enb_reg(write_enb_reg), 
        .full_0(full_0), 
        .full_1(full_1), 
        .full_2(full_2),
        .soft_reset_0_rd(soft_reset_0_rd), 
        .soft_reset_1_rd(soft_reset_1_rd), 
        .soft_reset_2_rd(soft_reset_2_rd),
        .fifo_full(fifo_full), 
        .write_enb(write_enb),
        .soft_reset_0_wr(soft_reset_0_wr), 
        .soft_reset_1_wr(soft_reset_1_wr), 
        .soft_reset_2_wr(soft_reset_2_wr)
    );

    router_fsm FSM (
        .wr_clk(wr_clk), 
        .wrst_n(wrst_n), 
        .pkt_valid(pkt_valid), 
        .parity_done(parity_done),
        .data_in(data_in[1:0]), 
        .soft_reset_0_wr(soft_reset_0_wr), 
        .soft_reset_1_wr(soft_reset_1_wr), 
        .soft_reset_2_wr(soft_reset_2_wr),
        .fifo_full(fifo_full), 
        .low_pkt_valid(low_pkt_valid),
        .fifo_empty_0_wr(empty_0_wr), 
        .fifo_empty_1_wr(empty_1_wr), 
        .fifo_empty_2_wr(empty_2_wr),
        .busy(busy), 
        .detect_add(detect_add), 
        .ld_state(ld_state), 
        .laf_state(laf_state),
        .full_state(full_state), 
        .write_enb_reg(write_enb_reg), 
        .rst_int_reg(rst_int_reg), 
        .lfd_state(lfd_state)
    );

    router_reg Register (
        .wr_clk(wr_clk), 
        .wrst_n(wrst_n), 
        .pkt_valid(pkt_valid), 
        .data_in(data_in),
        .fifo_full(fifo_full), 
        .rst_int_reg(rst_int_reg), 
        .detect_add(detect_add),
        .ld_state(ld_state), 
        .laf_state(laf_state), 
        .full_state(full_state),
        .lfd_state(lfd_state), 
        .parity_done(parity_done), 
        .low_pkt_valid(low_pkt_valid),
        .err(error), 
        .dout(dout)
    );

endmodule
