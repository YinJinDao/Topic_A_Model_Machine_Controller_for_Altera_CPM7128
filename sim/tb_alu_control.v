// ============================================================
// 文件名: tb_alu_control.v  ——  ALU 控制接口 Testbench
// 功能: 测试各指令在不同节拍下的 CIN/LDZ/LDC 输出
// ============================================================
`timescale 1ns / 100ps

module tb_alu_control;

    reg  is_add, is_sub, is_and, is_inc, is_ld;
    reg  t1, t2, t3;
    wire cin, ldz, ldc;

    alu_control uut (
        .is_add(is_add), .is_sub(is_sub), .is_and(is_and),
        .is_inc(is_inc), .is_ld(is_ld),
        .t1(t1), .t2(t2), .t3(t3),
        .cin(cin), .ldz(ldz), .ldc(ldc)
    );

    reg all_pass;

    initial begin
        all_pass = 1;
        $display("=== ALU Control Testbench ===");
        $display("");
        $display(" Testing ADD at T1 (expect cin=0, ldz=1, ldc=1)");
        is_add=1; is_sub=0; is_and=0; is_inc=0; is_ld=0;
        t1=1; t2=0; t3=0;
        #10;
        if (cin===0 && ldz===1 && ldc===1) $display("  PASS"); else begin $display("  FAIL: got %b %b %b", cin, ldz, ldc); all_pass=0; end

        $display(" Testing SUB at T1 (expect cin=1, ldz=1, ldc=1)");
        is_add=0; is_sub=1; is_and=0; is_inc=0; is_ld=0;
        #10;
        if (cin===1 && ldz===1 && ldc===1) $display("  PASS"); else begin $display("  FAIL: got %b %b %b", cin, ldz, ldc); all_pass=0; end

        $display(" Testing AND at T1 (expect cin=0, ldz=1, ldc=0)");
        is_add=0; is_sub=0; is_and=1; is_inc=0; is_ld=0;
        #10;
        if (cin===0 && ldz===1 && ldc===0) $display("  PASS"); else begin $display("  FAIL: got %b %b %b", cin, ldz, ldc); all_pass=0; end

        $display(" Testing INC at T1 (expect cin=1, ldz=1, ldc=1)");
        is_add=0; is_sub=0; is_and=0; is_inc=1; is_ld=0;
        #10;
        if (cin===1 && ldz===1 && ldc===1) $display("  PASS"); else begin $display("  FAIL: got %b %b %b", cin, ldz, ldc); all_pass=0; end

        $display(" Testing LD at T1 (expect cin=0, ldz=0, ldc=0)");
        is_add=0; is_sub=0; is_and=0; is_inc=0; is_ld=1;
        #10;
        if (cin===0 && ldz===0 && ldc===0) $display("  PASS"); else begin $display("  FAIL: got %b %b %b", cin, ldz, ldc); all_pass=0; end

        $display(" Testing ADD at T2 (expect all 0)");
        t1=0; t2=1; t3=0;
        #10;
        if (cin===0 && ldz===0 && ldc===0) $display("  PASS"); else begin $display("  FAIL: got %b %b %b", cin, ldz, ldc); all_pass=0; end

        $display(" Testing ADD at T3 (expect all 0)");
        t1=0; t2=0; t3=1;
        #10;
        if (cin===0 && ldz===0 && ldc===0) $display("  PASS"); else begin $display("  FAIL: got %b %b %b", cin, ldz, ldc); all_pass=0; end

        $display(" Testing no instruction at T1 (expect all 0)");
        is_add=0; is_sub=0; is_and=0; is_inc=0; is_ld=0;
        t1=1; t2=0; t3=0;
        #10;
        if (cin===0 && ldz===0 && ldc===0) $display("  PASS"); else begin $display("  FAIL: got %b %b %b", cin, ldz, ldc); all_pass=0; end

        $display("");
        if (all_pass)
            $display("=== ALL PASS ===");
        else
            $display("=== SOME TESTS FAILED ===");
        $finish;
    end

endmodule
