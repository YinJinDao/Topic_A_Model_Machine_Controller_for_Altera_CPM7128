// ============================================================
// 文件名: tb_instruction_decoder.v  ——  指令译码器 Testbench
// 功能: 遍历全部 16 种 ir 输入，验证译码输出是否正确
// ============================================================
`timescale 1ns / 100ps

module tb_instruction_decoder;

    reg  [3:0] ir;
    wire is_add, is_sub, is_and, is_inc, is_ld, is_st;
    wire is_jc, is_jz, is_jmp, is_stp;

    instruction_decoder uut (
        .ir     (ir),
        .is_add (is_add),
        .is_sub (is_sub),
        .is_and (is_and),
        .is_inc (is_inc),
        .is_ld  (is_ld),
        .is_st  (is_st),
        .is_jc  (is_jc),
        .is_jz  (is_jz),
        .is_jmp (is_jmp),
        .is_stp (is_stp)
    );

    // 期望结果查找表: {is_stp,is_jmp,is_jz,is_jc,is_st,is_ld,is_inc,is_and,is_sub,is_add}
    reg [9:0] expected [0:15];
    integer   i;
    reg [9:0] actual;
    reg       all_pass;

    initial begin
        // 初始化期望表 (索引 = ir 值)
        expected[0]  = 10'b0000000000;   // 非法
        expected[1]  = 10'b0000000001;   // ADD  0001
        expected[2]  = 10'b0000000010;   // SUB  0010
        expected[3]  = 10'b0000000100;   // AND  0011
        expected[4]  = 10'b0000001000;   // INC  0100
        expected[5]  = 10'b0000010000;   // LD   0101
        expected[6]  = 10'b0000100000;   // ST   0110
        expected[7]  = 10'b0001000000;   // JC   0111
        expected[8]  = 10'b0010000000;   // JZ   1000
        expected[9]  = 10'b0100000000;   // JMP  1001
        expected[10] = 10'b0000000000;   // 非法 1010
        expected[11] = 10'b0000000000;   // 非法 1011
        expected[12] = 10'b0000000000;   // 非法 1100
        expected[13] = 10'b0000000000;   // 非法 1101
        expected[14] = 10'b1000000000;   // STP  1110
        expected[15] = 10'b0000000000;   // 非法 1111

        $display("=== Instruction Decoder Testbench ===");
        $display("");
        $display(" IR  |ADD|SUB|AND|INC|LD |ST |JC |JZ |JMP|STP | Result");
        $display("-----|---|---|---|---|---|---|---|---|---|---|--------");

        all_pass = 1;

        for (i = 0; i < 16; i = i + 1) begin
            ir = i[3:0];
            #10;

            actual = {is_stp, is_jmp, is_jz, is_jc, is_st,
                      is_ld,  is_inc, is_and, is_sub, is_add};

            if (actual === expected[i]) begin
                $display(" %b  | %b | %b | %b | %b | %b | %b | %b | %b | %b  | %b  |  PASS",
                         ir, is_add, is_sub, is_and, is_inc, is_ld, is_st,
                         is_jc, is_jz, is_jmp, is_stp);
            end else begin
                $display(" %b  | %b | %b | %b | %b | %b | %b | %b | %b | %b  | %b  | *FAIL*",
                         ir, is_add, is_sub, is_and, is_inc, is_ld, is_st,
                         is_jc, is_jz, is_jmp, is_stp);
                all_pass = 0;
            end
        end

        $display("");
        if (all_pass) begin
            $display("=== 全部通过！===");
        end else begin
            $display("=== 存在失败用例 ===");
        end
        $finish;
    end

endmodule
