module wma_da_obc_top_debug #(
    parameter integer PIX_W     = 8,
    parameter integer MAX_WIDTH = 8192
)(
    input  wire                  clk,
    input  wire                  rst_n,      // active-low reset

    // Input pixel stream
    input  wire                  in_valid,
    input  wire [PIX_W-1:0]      in_pixel,
    input  wire [15:0]           width,
    input  wire [15:0]           height,     // unused, kept for interface

    // Output pixel stream
    output reg                   out_valid,
    output reg  [PIX_W-1:0]      out_pixel
);

    // Line buffers
    reg [PIX_W-1:0] line0 [0:MAX_WIDTH-1];
    reg [PIX_W-1:0] line1 [0:MAX_WIDTH-1];

    // 3×3 window
    reg [PIX_W-1:0] w_top [0:2];
    reg [PIX_W-1:0] w_mid [0:2];
    reg [PIX_W-1:0] w_bot [0:2];

    // Position counters
    reg [15:0] row;
    reg [15:0] col;

    // internal
    reg         full;
    integer     i;
    integer     acc;
    integer     norm;
    reg [PIX_W-1:0] top_val, mid_val, bot_val;

    always @(*) begin
        full = (row >= 16'd2) && (col >= 16'd2);
    end

    integer idx;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            row       <= 16'd0;
            col       <= 16'd0;
            out_valid <= 1'b0;
            out_pixel <= {PIX_W{1'b0}};

            for (idx = 0; idx < MAX_WIDTH; idx = idx + 1) begin
                line0[idx] <= {PIX_W{1'b0}};
                line1[idx] <= {PIX_W{1'b0}};
            end

            w_top[0] <= line1[col]; w_top[1] <= line1[col]; w_top[2] <= line1[col];
            w_mid[0] <= line0[col]; w_mid[1] <= line0[col]; w_mid[2] <= line0[col];
            w_bot[0] <= in_pixel; w_bot[1] <= in_pixel; w_bot[2] <= in_pixel;
        end
        else begin
            out_valid <= 1'b0;

            if (in_valid) begin
                // read line buffers
                top_val = line1[col];
                mid_val = line0[col];
                bot_val = in_pixel;

                // shift window
                w_top[0] <= w_top[1];
                w_top[1] <= w_top[2];
                w_top[2] <= top_val;

                w_mid[0] <= w_mid[1];
                w_mid[1] <= w_mid[2];
                w_mid[2] <= mid_val;

                w_bot[0] <= w_bot[1];
                w_bot[1] <= w_bot[2];
                w_bot[2] <= bot_val;

                // update line buffers
                line1[col] <= line0[col];
                line0[col] <= bot_val;

                // --- NEW BORDER HANDLING ---
                // For border (no full 3x3 yet): treat all missing neighbors as center pixel.
                // Equivalent to convolving a 3x3 block filled with center pixel -> output = center.
                if (full) begin
                    // Gaussian kernel:
                    // [1 2 1; 2 4 2; 1 2 1] / 16
                    acc = 0;
                    acc = acc
                        + 1 * w_top[0]
                        + 2 * w_top[1]
                        + 1 * w_top[2]
                        + 2 * w_mid[0]
                        + 4 * w_mid[1]
                        + 2 * w_mid[2]
                        + 1 * w_bot[0]
                        + 2 * w_bot[1]
                        + 1 * w_bot[2];
                end else begin
                    // center pixel = current pixel (in_pixel)
                    acc = 16 * in_pixel;
                end

                // divide by 16
                norm = acc >>> 4;

                // clamp
                if (norm < 0)
                    norm = 0;
                else if (norm > 255)
                    norm = 255;

                out_pixel <= norm[7:0];
                out_valid <= 1'b1;

                // advance coords
                if (col == width - 1) begin
                    col <= 16'd0;
                    row <= row + 16'd1;
                end else begin
                    col <= col + 16'd1;
                end
            end
        end
    end

endmodule