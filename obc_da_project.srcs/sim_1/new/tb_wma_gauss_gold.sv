`timescale 1ns/1ps

module tb_wma_da_obc_top_debug;

    // ----------------------------------------------------------------
    // Limits (for array sizes)
    // ----------------------------------------------------------------
    parameter int MAX_W        = 1024;
    parameter int MAX_H        = 1024;
    parameter int MAX_PIXELS   = MAX_W * MAX_H;

    // ----------------------------------------------------------------
    // DUT interface
    // ----------------------------------------------------------------
    reg         clk;
    reg         rst_n;
    reg         in_valid;
    reg  [7:0]  in_pixel;
    reg  [15:0] width;
    reg  [15:0] height;
    wire        out_valid;
    wire [7:0]  out_pixel;

    // Instantiate DUT (golden debug module)
    wma_da_obc_top_debug #(
        .PIX_W(8),
        .MAX_WIDTH(MAX_W)
    ) dut (
        .clk       (clk),
        .rst_n     (rst_n),
        .in_valid  (in_valid),
        .in_pixel  (in_pixel),
        .width     (width),
        .height    (height),
        .out_valid (out_valid),
        .out_pixel (out_pixel)
    );

    // ----------------------------------------------------------------
    // Clock
    // ----------------------------------------------------------------
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;  // 100 MHz
    end

    // ----------------------------------------------------------------
    // Storage for input and output images
    // ----------------------------------------------------------------
    reg [7:0] img_in  [0:MAX_PIXELS-1];
    reg [7:0] img_out [0:MAX_PIXELS-1];
    integer   idx_in;
    integer   idx_out;

    // Capture output pixels when valid
    always @(posedge clk) begin
        if (!rst_n) begin
            idx_out <= 0;
        end else begin
            if (out_valid && idx_out < (width*height)) begin
                img_out[idx_out] <= out_pixel;
                idx_out          <= idx_out + 1;
            end
        end
    end

    // ----------------------------------------------------------------
    // Helper: read next non-comment line from PGM (ASCII)
    // ----------------------------------------------------------------
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

    // ----------------------------------------------------------------
    // Stimulus + PGM I/O
    // ----------------------------------------------------------------
    integer fd_in, fd_out;
    string  line;
    int     maxval;
    int     total_pixels;
    integer i;
    int     pix_val;

    initial begin
        rst_n    = 1'b0;
        in_valid = 1'b0;
        in_pixel = 8'd0;

        width    = 0;
        height   = 0;
        idx_in   = 0;
        idx_out  = 0;

        // Reset
        #40;
        rst_n = 1'b1;
        @(posedge clk);

        // -------------------------------------------------------------
        // READ in.pgm  (ASCII PGM, likely P2)
        // -------------------------------------------------------------
        fd_in = $fopen("in.pgm", "r");
        if (fd_in == 0) begin
            $display("ERROR: cannot open in.pgm for reading");
            $finish;
        end

        // 1) magic ("P2" or "P5", we'll accept either, but expect ASCII data)
        void'($fgets(line, fd_in));
        if (line.len() < 2 || (line.substr(0,1) != "P2" && line.substr(0,1) != "P5")) begin
            $display("ERROR: only P2/P5 PGM supported, got: %s", line);
            $finish;
        end

        // 2) width & height (skip comment lines)
        line = next_non_comment_line(fd_in);
        if (line == "") begin
            $display("ERROR: could not read width/height line");
            $finish;
        end
        void'($sscanf(line, "%d %d", width, height));

        // 3) maxval (skip comments)
        line = next_non_comment_line(fd_in);
        if (line == "") begin
            $display("ERROR: could not read maxval line");
            $finish;
        end
        void'($sscanf(line, "%d", maxval));
        if (maxval != 255) begin
            $display("WARNING: maxval=%0d (expected 255), continuing anyway", maxval);
        end

        total_pixels = width * height;
        if (total_pixels > MAX_PIXELS) begin
            $display("ERROR: image too large (%0d pixels), increase MAX_W/MAX_H", total_pixels);
            $finish;
        end

        // 4) ASCII pixel data: read total_pixels integers with fscanf
        for (idx_in = 0; idx_in < total_pixels; idx_in = idx_in + 1) begin
            if ($fscanf(fd_in, "%d", pix_val) != 1) begin
                $display("ERROR: not enough pixel data in in.pgm (idx=%0d)", idx_in);
                $finish;
            end
            img_in[idx_in] = pix_val[7:0];
        end
        $fclose(fd_in);
        $display("Read in.pgm: %0d x %0d, maxval=%0d, total_pixels=%0d",
                 width, height, maxval, total_pixels);

        // -------------------------------------------------------------
        // FEED IMAGE INTO DUT
        // -------------------------------------------------------------
        for (idx_in = 0; idx_in < total_pixels; idx_in = idx_in + 1) begin
            @(posedge clk);
            in_valid <= 1'b1;
            in_pixel <= img_in[idx_in];
        end

        @(posedge clk);
        in_valid <= 1'b0;
        in_pixel <= 8'd0;

        // wait for pipeline to flush
        repeat (200) @(posedge clk);

        // -------------------------------------------------------------
        // WRITE out.pgm (binary P5)
        // -------------------------------------------------------------
        fd_out = $fopen("out.pgm", "wb");
        if (fd_out == 0) begin
            $display("ERROR: cannot open out.pgm for writing");
        end else begin
            // header
            $fwrite(fd_out, "P5\n%0d %0d\n255\n", width, height);
            // data
            for (i = 0; i < total_pixels; i = i + 1) begin
                $fwrite(fd_out, "%c", img_out[i]);
            end
            $fclose(fd_out);
            $display("Wrote out.pgm (%0d x %0d)", width, height);
        end

        $finish;
    end

endmodule