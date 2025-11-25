`timescale 1ns/1ps

module tb_obc_da_integer_9input;

    // -----------------------------
    // Image limits
    // -----------------------------
    parameter int MAX_W      = 1024;
    parameter int MAX_H      = 1024;
    parameter int MAX_PIXELS = MAX_W * MAX_H;

    // -----------------------------
    // DUT interface
    // -----------------------------
    reg         clk;
    reg         rst_n;
    reg         start;

    reg  signed [15:0] x0, x1, x2, x3, x4, x5, x6, x7, x8;
    wire signed [31:0] y;
    wire        done;

    // Instantiate your OBC+DA core
    obc_da_integer_9input #(
        .N(9),
        .W(16),
        .LUT_WIDTH(16)
    ) dut (
        .clk  (clk),
        .rst_n(rst_n),
        .start(start),
        .x0   (x0),
        .x1   (x1),
        .x2   (x2),
        .x3   (x3),
        .x4   (x4),
        .x5   (x5),
        .x6   (x6),
        .x7   (x7),
        .x8   (x8),
        .y    (y),
        .done (done)
    );

    // -----------------------------
    // Clock
    // -----------------------------
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;  // 100 MHz
    end

    // -----------------------------
    // Image buffers
    // -----------------------------
    reg [7:0] img_in  [0:MAX_PIXELS-1];
    reg [7:0] img_out [0:MAX_PIXELS-1];

    int width, height;
    int total_pixels;

    // -----------------------------
    // Helper: read next non-comment line
    // -----------------------------
    function string next_non_comment_line (input int fd);
        string l;
        int    r;
        begin
            l = "";
            do begin
                r = $fgets(l, fd);
                if (r == 0) return "";
            end while (l.len() > 0 && l.getc(0) == "#");
            return l;
        end
    endfunction

    // -----------------------------
    // Task: one DA evaluation for 3x3 window
    // x0..x8 must already be set before calling
    // -----------------------------
    task automatic do_da_for_window(
        input  signed [15:0] in_x0,
        input  signed [15:0] in_x1,
        input  signed [15:0] in_x2,
        input  signed [15:0] in_x3,
        input  signed [15:0] in_x4,
        input  signed [15:0] in_x5,
        input  signed [15:0] in_x6,
        input  signed [15:0] in_x7,
        input  signed [15:0] in_x8,
        output signed [31:0] out_y
    );
        begin
            // drive inputs
            x0 <= in_x0;
            x1 <= in_x1;
            x2 <= in_x2;
            x3 <= in_x3;
            x4 <= in_x4;
            x5 <= in_x5;
            x6 <= in_x6;
            x7 <= in_x7;
            x8 <= in_x8;

            $display("[TB] DA window start: x0=%0d x1=%0d x2=%0d x3=%0d x4=%0d x5=%0d x6=%0d x7=%0d x8=%0d", in_x0, in_x1, in_x2, in_x3, in_x4, in_x5, in_x6, in_x7, in_x8);

//            // pulse start
//            @(posedge clk);
//            start <= 1'b1;
//            $display("[TB] Start pulsed HIGH at %t", $time);
//            @(negedge clk);
//            start <= 1'b0;
//            $display("[TB] Start pulsed LOW at %t", $time);

            // wait until done
            wait (done == 1'b1);
            $display("[TB] Done detected. y=%0d", y);
            // capture result at next edge
            @(posedge clk);
            out_y = y;
        end
    endtask

    // -----------------------------
    // Main stimulus
    // -----------------------------
    integer fd_in, fd_out;
    string  line;
    int     maxval;
    int     i;
    int     r, c;
    int     idx;

    int     pix_val;
    int     rr, cc;
    reg [7:0] p00,p01,p02,
              p10,p11,p12,
              p20,p21,p22;

    reg signed [15:0] gx0,gx1,gx2,gx3,gx4,gx5,gx6,gx7,gx8;
    reg signed [31:0] y_da;
    integer           norm;

    initial begin
        // reset
        rst_n = 1'b0;
        start = 1'b0;
        x0    = 16'sd0;
        x1    = 16'sd0;
        x2    = 16'sd0;
        x3    = 16'sd0;
        x4    = 16'sd0;
        x5    = 16'sd0;
        x6    = 16'sd0;
        x7    = 16'sd0;
        x8    = 16'sd0;

        #40;
        rst_n = 1'b1;
        @(posedge clk);

        // -----------------------------------------------------
        // READ in.pgm (ASCII PGM, P2 or P5 header but ASCII data)
        // -----------------------------------------------------
        fd_in = $fopen("in.pgm", "r");
        if (fd_in == 0) begin
            $display("ERROR: cannot open in.pgm");
            $finish;
        end

        // magic "P2" or "P5"
        void'($fgets(line, fd_in));
        if (line.len() < 2 || (line.substr(0,1) != "P2" && line.substr(0,1) != "P5")) begin
            $display("ERROR: only P2/P5 PGM supported as ASCII pixel data.");
            $finish;
        end

        // width & height
        line = next_non_comment_line(fd_in);
        if (line == "") begin
            $display("ERROR: could not read width/height");
            $finish;
        end
        void'($sscanf(line, "%d %d", width, height));

        // maxval
        line = next_non_comment_line(fd_in);
        if (line == "") begin
            $display("ERROR: could not read maxval");
            $finish;
        end
        void'($sscanf(line, "%d", maxval));
        if (maxval != 255) begin
            $display("WARNING: maxval=%0d (expected 255), continuing", maxval);
        end

        total_pixels = width * height;
        if (total_pixels > MAX_PIXELS) begin
            $display("ERROR: image too large (%0d pixels)", total_pixels);
            $finish;
        end

        // read ASCII pixels
        for (i = 0; i < total_pixels; i = i + 1) begin
            if ($fscanf(fd_in, "%d", pix_val) != 1) begin
                $display("ERROR: not enough pixel data at i=%0d", i);
                $finish;
            end
            img_in[i] = pix_val[7:0];
        end

        $fclose(fd_in);
        $display("Read in.pgm: %0d x %0d", width, height);

        // -----------------------------------------------------
        // PROCESS: 3x3 Gaussian via OBC+DA per pixel
        // Border: if neighbor is out of bounds, use center pixel
        // -----------------------------------------------------
        for (r = 0; r < height; r = r + 1) begin
            for (c = 0; c < width; c = c + 1) begin
                idx = r*width + c;
                p11 = img_in[idx];

                // Helper: for each neighbor, if out-of-bounds -> use center
                // row-1, col-1
                rr = r-1; cc = c-1;
                if (rr < 0 || rr >= height || cc < 0 || cc >= width) p00 = p11;
                else p00 = img_in[rr*width + cc];

                // row-1, col
                rr = r-1; cc = c;
                if (rr < 0 || rr >= height || cc < 0 || cc >= width) p01 = p11;
                else p01 = img_in[rr*width + cc];

                // row-1, col+1
                rr = r-1; cc = c+1;
                if (rr < 0 || rr >= height || cc < 0 || cc >= width) p02 = p11;
                else p02 = img_in[rr*width + cc];

                // row, col-1
                rr = r;   cc = c-1;
                if (rr < 0 || rr >= height || cc < 0 || cc >= width) p10 = p11;
                else p10 = img_in[rr*width + cc];

                // row, col (center)
                p11 = img_in[idx];

                // row, col+1
                rr = r;   cc = c+1;
                if (rr < 0 || rr >= height || cc < 0 || cc >= width) p12 = p11;
                else p12 = img_in[rr*width + cc];

                // row+1, col-1
                rr = r+1; cc = c-1;
                if (rr < 0 || rr >= height || cc < 0 || cc >= width) p20 = p11;
                else p20 = img_in[rr*width + cc];

                // row+1, col
                rr = r+1; cc = c;
                if (rr < 0 || rr >= height || cc < 0 || cc >= width) p21 = p11;
                else p21 = img_in[rr*width + cc];

                // row+1, col+1
                rr = r+1; cc = c+1;
                if (rr < 0 || rr >= height || cc < 0 || cc >= width) p22 = p11;
                else p22 = img_in[rr*width + cc];

                // Map to Gaussian weights:
                // [1 2 1
                //  2 4 2
                //  1 2 1]
                // and extend to 16-bit signed
                gx0 = $signed({8'd0, p00}) * 16'sd1;
                gx1 = $signed({8'd0, p01}) * 16'sd2;
                gx2 = $signed({8'd0, p02}) * 16'sd1;
                gx3 = $signed({8'd0, p10}) * 16'sd2;
                gx4 = $signed({8'd0, p11}) * 16'sd4;
                gx5 = $signed({8'd0, p12}) * 16'sd2;
                gx6 = $signed({8'd0, p20}) * 16'sd1;
                gx7 = $signed({8'd0, p21}) * 16'sd2;
                gx8 = $signed({8'd0, p22}) * 16'sd1;

                // Call DA core for this window
                start = 1'b1;
                do_da_for_window(
                    gx0,gx1,gx2,gx3,gx4,gx5,gx6,gx7,gx8,
                    y_da
                );
                
                wait(done);
                start = 1'b0;
//                rst_n = 1'b1;

                // -----------------------------------------
                // Convert DA output to 8-bit pixel
                // NOTE: This depends on your DA scaling
                // (accum >>> 15) + d_extra in the core.
                // You may need to adjust the shift below.
                // For now we just clamp y_da to 0..255.
                // -----------------------------------------
                norm = y_da;   // simple: use as-is
                if (norm < 0)      norm = 0;
                else if (norm > 255) norm = 255;

                img_out[idx] = norm[7:0];
            end
        end

        // -----------------------------------------------------
        // WRITE out.pgm (binary P5)
        // -----------------------------------------------------
        fd_out = $fopen("out.pgm", "wb");
        if (fd_out == 0) begin
            $display("ERROR: cannot open out.pgm for write");
        end else begin
            $fwrite(fd_out, "P5\n%0d %0d\n255\n", width, height);
            for (i = 0; i < total_pixels; i = i + 1) begin
                $fwrite(fd_out, "%c", img_out[i]);
            end
            $fclose(fd_out);
            $display("Wrote out.pgm (%0d x %0d)", width, height);
        end

        $finish;
    end

endmodule