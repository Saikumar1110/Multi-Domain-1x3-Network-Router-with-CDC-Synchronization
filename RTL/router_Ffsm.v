module router_fsm (
    input wire wr_clk,
    input wire wrst_n,
    input wire pkt_valid,
    input wire parity_done,
    input wire [1:0] data_in,
    
    // Synchronized soft resets from router_sync (Write Domain)
    input wire soft_reset_0_wr,
    input wire soft_reset_1_wr,
    input wire soft_reset_2_wr,
    
    input wire fifo_full,
    input wire low_pkt_valid,
    
    // Synchronized empty flags from the destination domains
    input wire fifo_empty_0_wr,
    input wire fifo_empty_1_wr,
    input wire fifo_empty_2_wr,
    
    output wire busy,
    output wire detect_add,
    output wire ld_state,
    output wire laf_state,
    output wire full_state,
    output wire write_enb_reg,
    output wire rst_int_reg,
    output wire lfd_state
);

    localparam DECODE_ADDRESS     = 4'd0,
               LOAD_FIRST_DATA    = 4'd1,
               LOAD_DATA          = 4'd2,
               LOAD_PARITY        = 4'd3,
               FIFO_FULL_STATE    = 4'd4,
               LOAD_AFTER_FULL    = 4'd5,
               WAIT_TILL_EMPTY    = 4'd6,
               CHECK_PARITY_ERROR = 4'd7;

    reg [3:0] state, next_state;
    reg parity_loaded_flag, parity_not_loaded_flag;

    // Present State Logic (Asynchronous Reset)
    always @(posedge wr_clk or negedge wrst_n) begin
        if (!wrst_n) begin
            state <= DECODE_ADDRESS;
        end else begin
            state <= next_state;
        end
    end

    // Parity Flag Logic (Separating Physical Async Reset from Logical Sync Reset)
    always @(posedge wr_clk or negedge wrst_n) begin
        if (!wrst_n) begin
            parity_loaded_flag <= 1'b0;
            parity_not_loaded_flag <= 1'b0;
        end else if (state == DECODE_ADDRESS || soft_reset_0_wr || soft_reset_1_wr || soft_reset_2_wr) begin
            parity_loaded_flag <= 1'b0;
            parity_not_loaded_flag <= 1'b0;
        end else if (state == LOAD_PARITY && !fifo_full) begin
            parity_loaded_flag <= 1'b1;
        end else if (state == LOAD_PARITY && fifo_full) begin
            parity_not_loaded_flag <= 1'b1;
        end else begin
            parity_loaded_flag <= parity_loaded_flag;
            parity_not_loaded_flag <= parity_not_loaded_flag;
        end
    end

    // Next State Combinational Logic
    always @(*) begin
        case (state)
            DECODE_ADDRESS: begin
                if (soft_reset_0_wr || soft_reset_1_wr || soft_reset_2_wr) 
                    next_state = DECODE_ADDRESS;
                else if ((pkt_valid && (data_in == 2'd0) && fifo_empty_0_wr) || 
                         (pkt_valid && (data_in == 2'd1) && fifo_empty_1_wr) || 
                         (pkt_valid && (data_in == 2'd2) && fifo_empty_2_wr))
                    next_state = LOAD_FIRST_DATA;
                else if ((pkt_valid && (data_in == 2'd0) && !fifo_empty_0_wr) || 
                         (pkt_valid && (data_in == 2'd1) && !fifo_empty_1_wr) || 
                         (pkt_valid && (data_in == 2'd2) && !fifo_empty_2_wr))
                    next_state = WAIT_TILL_EMPTY;
                else 
                    next_state = DECODE_ADDRESS;
            end
            
            LOAD_FIRST_DATA: next_state = LOAD_DATA;
            
            LOAD_DATA: begin
                if (soft_reset_0_wr || soft_reset_1_wr || soft_reset_2_wr) 
                    next_state = DECODE_ADDRESS;
                else if (fifo_full) 
                    next_state = FIFO_FULL_STATE;
                else if (!fifo_full && !pkt_valid) 
                    next_state = LOAD_PARITY;
                else 
                    next_state = LOAD_DATA;
            end
            
            LOAD_PARITY: next_state = CHECK_PARITY_ERROR;
            
            FIFO_FULL_STATE: begin
                if (soft_reset_0_wr || soft_reset_1_wr || soft_reset_2_wr) 
                    next_state = DECODE_ADDRESS;
                else if (fifo_full) 
                    next_state = FIFO_FULL_STATE;
                else if (!fifo_full && parity_loaded_flag) 
                    next_state = DECODE_ADDRESS;
                else if (!fifo_full && !parity_loaded_flag) 
                    next_state = LOAD_AFTER_FULL;
                else 
                    next_state = FIFO_FULL_STATE;
            end
            
            LOAD_AFTER_FULL: begin
                if (soft_reset_0_wr || soft_reset_1_wr || soft_reset_2_wr) 
                    next_state = DECODE_ADDRESS;
                else if (!parity_done && low_pkt_valid) 
                    next_state = LOAD_PARITY;
                else if (!parity_done && !low_pkt_valid) 
                    next_state = LOAD_DATA;
                else if (parity_done) 
                    next_state = DECODE_ADDRESS;
                else 
                    next_state = LOAD_AFTER_FULL;
            end
            
            WAIT_TILL_EMPTY: begin
                if (soft_reset_0_wr || soft_reset_1_wr || soft_reset_2_wr) 
                    next_state = DECODE_ADDRESS;
                else if ((fifo_empty_0_wr && (data_in == 2'd0)) || 
                         (fifo_empty_1_wr && (data_in == 2'd1)) || 
                         (fifo_empty_2_wr && (data_in == 2'd2)))
                    next_state = LOAD_FIRST_DATA;
                else 
                    next_state = WAIT_TILL_EMPTY;
            end
            
            CHECK_PARITY_ERROR: begin
                if (soft_reset_0_wr || soft_reset_1_wr || soft_reset_2_wr) 
                    next_state = DECODE_ADDRESS;
                else if (fifo_full || parity_not_loaded_flag) 
                    next_state = FIFO_FULL_STATE;
                else if (!fifo_full) 
                    next_state = DECODE_ADDRESS;
                else 
                    next_state = CHECK_PARITY_ERROR;
            end
            
            default: next_state = DECODE_ADDRESS;
        endcase
    end

    // Output Signal Combinational Logic
    assign detect_add    = (state == DECODE_ADDRESS) ? 1'b1 : 1'b0;
    assign lfd_state     = (state == LOAD_FIRST_DATA) ? 1'b1 : 1'b0;
    assign busy          = ((state == LOAD_FIRST_DATA) || (state == LOAD_PARITY) || 
                            (state == FIFO_FULL_STATE) || (state == LOAD_AFTER_FULL) || 
                            (state == WAIT_TILL_EMPTY)) ? 1'b1 : 1'b0;
    assign ld_state      = (state == LOAD_DATA) ? 1'b1 : 1'b0;
    assign write_enb_reg = ((state == LOAD_DATA) || (state == LOAD_PARITY) || 
                            (state == LOAD_AFTER_FULL)) ? 1'b1 : 1'b0;
    assign full_state    = (state == FIFO_FULL_STATE) ? 1'b1 : 1'b0;
    assign laf_state     = (state == LOAD_AFTER_FULL) ? 1'b1 : 1'b0;
    assign rst_int_reg   = (state == CHECK_PARITY_ERROR) ? 1'b1 : 1'b0;

endmodule





















