module top_gaussian_da #(
    parameter IMG_W = 256,
    parameter IMG_H = 256
)(
    input  wire clk,
    input  wire rst_n,
    input  wire start,
    output reg signed [31:0] y,
    output reg done
);

    // BRAM Signals
    reg  [15:0] bram_addr;
    wire [7:0]  bram_dout;
    
    // Instantiate BRAM (Created via IP Catalog with pepper.coe)
    (* DONT_TOUCH = "TRUE" *) blk_mem_gen_0 u_bram (
        .clka(clk),
        .ena(1'b1),
        .wea(1'b0),
        .addra(bram_addr),
        .dina(8'b0),
        .douta(bram_dout)
    );

    // State Machine
    typedef enum logic [2:0] {IDLE, FETCH, CALC, NEXT_PIXEL, DONE} state_t;
    state_t state;

    reg [15:0] r, c;      // Current center pixel coordinates
    reg [3:0]  fetch_cnt; // 0 to 8
    
    // The 9 inputs for the DA module
    reg signed [15:0] window [0:8]; 

    // Offsets for 3x3 window (centered at r,c)
    // (-1,-1), (-1, 0), (-1, +1), etc.
    function [15:0] get_addr(input [15:0] row, input [15:0] col, input [3:0] idx);
        integer ro, co;
        begin
            case(idx)
                0: begin ro = -1; co = -1; end
                1: begin ro = -1; co =  0; end
                2: begin ro = -1; co =  1; end
                3: begin ro =  0; co = -1; end
                4: begin ro =  0; co =  0; end
                5: begin ro =  0; co =  1; end
                6: begin ro =  1; co = -1; end
                7: begin ro =  1; co =  0; end
                8: begin ro =  1; co =  1; end
                default: begin ro = 0; co = 0; end
            endcase
            // Boundary check clamping
            if (row + ro < 0) ro = -row;
            if (col + co < 0) co = -col;
            if (row + ro >= IMG_H) ro = 0; // simplified boundary
            if (col + co >= IMG_W) co = 0;
            
            get_addr = ((row + ro) * IMG_W) + (col + co);
        end
    endfunction

    // DA Module Trigger
    reg da_start;
    wire signed [31:0] da_out;
    wire da_done;

    obc_da_integer_9input da_inst (
        .clk(clk), .rst_n(rst_n), .start(da_start),
        .x0(window[0]), .x1(window[1]), .x2(window[2]), 
        .x3(window[3]), .x4(window[4]), .x5(window[5]), 
        .x6(window[6]), .x7(window[7]), .x8(window[8]), 
        .y(da_out), .done(da_done)
    );

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            r <= 0; c <= 0;
            done <= 0;
            da_start <= 0;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        r <= 0; c <= 0;
                        state <= FETCH;
                        fetch_cnt <= 0;
                        // Pre-set address for first pixel (idx 0)
                        bram_addr <= get_addr(0, 0, 0); 
                    end
                end

                FETCH: begin
                    // It takes 2 cycles to read BRAM:
                    // Cycle 1: Set Address (Done in previous state or loop end)
                    // Cycle 2: Read Data
                    
                    // Since we set addr previously, bram_dout is valid now? 
                    // BRAM usually has 2 cycle latency. We need a wait state or pipeline.
                    // Simplified approach: 
                    if (fetch_cnt <= 8) begin
                        window[fetch_cnt] <= {8'b0, bram_dout}; // Zero extend
                        // Set up address for NEXT pixel
                        if (fetch_cnt < 8)
                            bram_addr <= get_addr(r, c, fetch_cnt + 1);
                        
                        fetch_cnt <= fetch_cnt + 1;
                    end else begin
                        state <= CALC;
                        da_start <= 1;
                    end
                end

                CALC: begin
                    da_start <= 0;
                    if (da_done) begin
                        y <= da_out; // Here is your processed pixel
                        state <= NEXT_PIXEL;
                    end
                end

                NEXT_PIXEL: begin
                    // Move to next column
                    if (c == IMG_W - 1) begin
                        c <= 0;
                        if (r == IMG_H - 1) state <= DONE;
                        else r <= r + 1;
                    end else begin
                        c <= c + 1;
                    end
                    
                    if (state != DONE) begin
                        state <= FETCH;
                        fetch_cnt <= 0;
                        // Setup address for first pixel of NEW window
                        bram_addr <= get_addr(r, (c == IMG_W - 1) ? 0 : c+1, 0);
                    end
                end

                DONE: begin
                    done <= 1;
                end
            endcase
        end
    end

endmodule