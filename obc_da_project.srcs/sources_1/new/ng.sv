`timescale 1ns/1ps
module obc_da_integer_9input #(
    parameter integer N         = 9,    // number of inputs (fixed 9)
    parameter integer W         = 16,   // bit width of inputs
    parameter integer LUT_WIDTH = 16    // LUT entry width (signed)
)(
    input  wire                      clk,
    input  wire                      rst_n,
    input  wire                      start,

    // 9 signed W-bit inputs
    input  wire signed [W-1:0]       x0,
    input  wire signed [W-1:0]       x1,
    input  wire signed [W-1:0]       x2,
    input  wire signed [W-1:0]       x3,
    input  wire signed [W-1:0]       x4,
    input  wire signed [W-1:0]       x5,
    input  wire signed [W-1:0]       x6,
    input  wire signed [W-1:0]       x7,
    input  wire signed [W-1:0]       x8,

    output reg  signed [31:0]        y,      // final DA result
    output reg                       done
);

    // ------------------------------------------------------------
    // Internal registers / state
    // ------------------------------------------------------------
    reg  [4:0]                 bit_pos;      // current bit (W-1 .. 0)
    reg  signed [31:0]         accum;        // accumulator
    reg  [N-1:0]               addr;         // full address bits (x0..x8)
    reg  [N-2:0]               lut_addr;     // reduced LUT address (x1..x8)
    reg                        sign_bit;     // MSB bit (x0)
    reg  signed [LUT_WIDTH-1:0] lut_val;     // LUT value
    reg                        state;        // 0 = idle, 1 = processing

    // D_extra term (concept preserved from your original design)
    reg signed [15:0] d_extra;

    // Reduced LUT depth = 2^(N-1) = 256 for N=9
    localparam integer LUT_DEPTH = (1 << (N-1));

    // Reduced LUT: indexed by bits of x1..x8
    reg signed [LUT_WIDTH-1:0] lut [0:LUT_DEPTH-1];

    // Gaussian weights mapped to x0..x8:
    // [ 1 2 1
    //   2 4 2
    //   1 2 1 ]
    // You can change this mapping if your x_i ordering is different.
    reg signed [15:0] c [0:N-1];

    integer i, b;
    integer sum_c;
    integer s;

    // ------------------------------------------------------------
    // INITIAL: set Gaussian coeffs, compute D_extra, build LUT
    // ------------------------------------------------------------
    initial begin
        // 1 Gaussian coefficients (3x3)
        // [1 2 1; 2 4 2; 1 2 1]
        c[0] = 16'sd1; // top-left
        c[1] = 16'sd2; // top-middle
        c[2] = 16'sd1; // top-right
        c[3] = 16'sd2; // mid-left
        c[4] = 16'sd4; // center
        c[5] = 16'sd2; // mid-right
        c[6] = 16'sd1; // bot-left
        c[7] = 16'sd2; // bot-middle
        c[8] = 16'sd1; // bot-right

        // 2) D_extra = -0.5 * sum(c_i)
        sum_c = 0;
        for (i = 0; i < N; i = i + 1) begin
            sum_c = sum_c + c[i];
        end
        // same concept as your original: y = (accum >>> 15) + d_extra
        d_extra = - (sum_c >>> 1);  // -sum_c/2

        // 3) Build reduced LUT for x1..x8
        // Convention:
        //   bit=1 -> +c[b+1]
        //   bit=0 -> -c[b+1]
        // Then MSB x0 controls sign in get_lut_value().
        for (i = 0; i < LUT_DEPTH; i = i + 1) begin
            s = 0;
            // x1..x8 mapped to c[1]..c[8]
            for (b = 0; b < (N-1); b = b + 1) begin
                if (i[b])
                    s = s + c[b+1];
                else
                    s = s - c[b+1];
            end
            // If your derivation expects negative of this, you can flip sign:
            // lut[i] = -s;
            lut[i] = s;
        end
    end

    // ------------------------------------------------------------
    // Symmetry function:
    // full_addr = {x0_bit, x1_bit, ..., x8_bit}
    // reduced_addr = x1..x8
    // MSB x0 flips the sign of the LUT entry.
    // ------------------------------------------------------------
    function automatic signed [LUT_WIDTH-1:0] get_lut_value;
        input [N-1:0] full_addr;
        reg   [N-2:0] reduced_addr;
        reg           msb;
        begin
            msb          = full_addr[N-1];    // x0
            reduced_addr = full_addr[N-2:0];  // x1..x8
            if (msb)
                get_lut_value = -lut[reduced_addr];
            else
                get_lut_value =  lut[reduced_addr];
        end
    endfunction

    // ------------------------------------------------------------
    // FSM for DA computation (same concept as your 5-input version)
    // ------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
            $display("[DUT] always block: clk=%b rst_n=%b state=%0d start=%b bit_pos=%0d done=%b", clk, rst_n, state, start, bit_pos, done);
        if (!rst_n) begin
            bit_pos   <= 5'd0;
            accum     <= 32'sd0;
            y         <= 32'sd0;
            done      <= 1'b0;
            state     <= 1'b0;
            addr      <= {N{1'b0}};
            lut_addr  <= {(N-1){1'b0}};
            sign_bit  <= 1'b0;
            lut_val   <= {LUT_WIDTH{1'b0}};
        end else begin
            // Ensure 'done' is only asserted for one cycle
            if (done) done <= 1'b0;
            case (state)
                1'b0: begin
                    // IDLE
                    // done <= 1'b0; // now handled above
                    if (start) begin
                        bit_pos <= W - 1;
                        accum   <= 32'sd0;
                        state   <= 1'b1;

                        // Build initial address (MSB bits)
                        addr     <= { x0[W-1], x1[W-1], x2[W-1], x3[W-1],
                                      x4[W-1], x5[W-1], x6[W-1], x7[W-1], x8[W-1] };
                        lut_addr <= { x1[W-1], x2[W-1], x3[W-1], x4[W-1],
                                      x5[W-1], x6[W-1], x7[W-1], x8[W-1] };
                        sign_bit <= x0[W-1];

                        // Symmetry-based LUT value
                        lut_val  <= get_lut_value(
                                        { x0[W-1], x1[W-1], x2[W-1], x3[W-1],
                                          x4[W-1], x5[W-1], x6[W-1], x7[W-1], x8[W-1] }
                                   );
                        $display("[DUT] Start detected. State: %0d, bit_pos: %0d", state, bit_pos);
                    end
                end

                1'b1: begin
                    // PROCESSING
                    $display("[DUT] Processing. State: %0d, bit_pos: %0d, accum: %0d", state, bit_pos, accum);
                    // MSB term is subtracted, others added (your original concept)
                    if (bit_pos == W - 1) begin
                        accum <= accum
                              - ({{(32-LUT_WIDTH){lut_val[LUT_WIDTH-1]}}, lut_val} <<< bit_pos);
                    end else begin
                        accum <= accum
                              + ({{(32-LUT_WIDTH){lut_val[LUT_WIDTH-1]}}, lut_val} <<< bit_pos);
                    end

                    if (bit_pos == 0) begin
                        // Final normalization + D_extra
                        // You can tune the shift 15 depending on your scaling.
                        y    <= (accum >>> 7) + d_extra;
                        done <= 1'b1;
                        state <= 1'b0;
                        $display("[DUT] Done asserted. y: %0d", y);
                    end else begin
                        bit_pos <= bit_pos - 1;

                        // Address for next bit
                        addr     <= { x0[bit_pos-1], x1[bit_pos-1], x2[bit_pos-1], x3[bit_pos-1],
                                      x4[bit_pos-1], x5[bit_pos-1], x6[bit_pos-1], x7[bit_pos-1], x8[bit_pos-1] };
                        lut_addr <= { x1[bit_pos-1], x2[bit_pos-1], x3[bit_pos-1], x4[bit_pos-1],
                                      x5[bit_pos-1], x6[bit_pos-1], x7[bit_pos-1], x8[bit_pos-1] };
                        sign_bit <= x0[bit_pos-1];

                        lut_val  <= get_lut_value(
                                        { x0[bit_pos-1], x1[bit_pos-1], x2[bit_pos-1], x3[bit_pos-1],
                                          x4[bit_pos-1], x5[bit_pos-1], x6[bit_pos-1], x7[bit_pos-1], x8[bit_pos-1] }
                                   );
                    end
                end
            endcase
        end
    end

endmodule