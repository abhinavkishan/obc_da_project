module tb_top_gaussian_da;

    parameter IMG_W = 256;
    parameter IMG_H = 256;
    parameter RAM_DEPTH = IMG_W * IMG_H;

    reg clk, rst_n, start;
    wire signed [31:0] y;
    wire done;

    // Instantiate DUT
    top_gaussian_da #(
        .IMG_W(IMG_W),
        .IMG_H(IMG_H)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .y(y),
        .done(done)
    );

    // Output buffer
    reg [7:0] img_out [0:RAM_DEPTH-1];

    integer row, col, idx, fd_out;
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    initial begin
        rst_n = 0;
        start = 0;
        #40;
        rst_n = 1;
        @(posedge clk);

        // Wait for all pixels to be processed
        for (row = 0; row < IMG_H; row = row + 1) begin
            for (col = 0; col < IMG_W; col = col + 1) begin
                idx = row * IMG_W + col;
                start = 1;
                @(posedge clk);
                start = 0;
                // Wait for done
                wait (done);
                // Clamp y to 0..255 and store
                if (y < 0) img_out[idx] = 0;
                else if (y > 255) img_out[idx] = 255;
                else img_out[idx] = y[7:0];
            end
        end

        // Write PGM file
        fd_out = $fopen("out.pgm", "w");
        if (fd_out == 0) begin
            $display("ERROR: cannot open out.pgm for write");
        end else begin
            $fwrite(fd_out, "P2\n%d %d\n255\n", IMG_W, IMG_H);
            for (idx = 0; idx < RAM_DEPTH; idx = idx + 1) begin
                $fwrite(fd_out, "%d\n", img_out[idx]);
            end
            $fclose(fd_out);
            $display("Wrote out.pgm (%0d x %0d)", IMG_W, IMG_H);
        end

        $finish;
    end

endmodule