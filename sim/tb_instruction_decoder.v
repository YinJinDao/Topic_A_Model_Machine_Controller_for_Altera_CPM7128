// ============================================================
// 文件名: tb_instruction_decoder.v  ——  指令译码器 Testbench
// 所属项目: TEC-8 模型机控制器（题目A）
//
// 测试目标:
//   验证 instruction_decoder 是否能正确将 4 位操作码（IR7-IR4）
//   翻译为 10 个单指令标识信号（is_add ~ is_stp）。
//
// 测试策略:
//   遍历 16 种可能的 4 位输入（0000 ~ 1111），对每条合法指令
//   检查对应信号是否为 1、其余是否全为 0；对非法指令检查全部
//   信号是否为 0。
// ============================================================

`timescale 1ns / 100ps

module tb_instruction_decoder;

    // ---- 被测模块的输入输出 ----
    reg  [3:0] ir;            // 测试驱动：依次给不同操作码
    wire       is_add;        // 被测输出：10 个指令标识
    wire       is_sub;
    wire       is_and;
    wire       is_inc;
    wire       is_ld;
    wire       is_st;
    wire       is_jc;
    wire       is_jz;
    wire       is_jmp;
    wire       is_stp;

    // ---- 例化被测模块 ----
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

    // ---- 辅助：把 10 个输出信号打包方便快速检查 ----
    wire [9:0] decoded;
    assign decoded = {is_stp, is_jmp, is_jz, is_jc, is_st,  is_ld,  is_inc, is_and, is_sub, is_add};

    // ---- 预期值表（ir → decoded 对照） ----
    // 格式：decoded = {is_stp, is_jmp, is_jz, is_jc,
    //                   is_st,  is_ld,  is_inc, is_and,
    //                   is_sub, is_add}
    reg [9:0] expected [0:15];   // 索引 0~15 对应 ir=0~15

    // 全局测试计数器
    integer pass_cnt, fail_cnt;
    integer i;

    initial begin
        // ---- 初始化预期值表 ----
        // 合法指令：
        expected[4'h1] = 10'b00_0000_0001;   // ADD  (0001) → is_add=1
        expected[4'h2] = 10'b00_0000_0010;   // SUB  (0010) → is_sub=1
        expected[4'h3] = 10'b00_0000_0100;   // AND  (0011) → is_and=1
        expected[4'h4] = 10'b00_0000_1000;   // INC  (0100) → is_inc=1
        expected[4'h5] = 10'b00_0001_0000;   // LD   (0101) → is_ld=1
        expected[4'h6] = 10'b00_0010_0000;   // ST   (0110) → is_st=1
        expected[4'h7] = 10'b00_0100_0000;   // JC   (0111) → is_jc=1
        expected[4'h8] = 10'b00_1000_0000;   // JZ   (1000) → is_jz=1
        expected[4'h9] = 10'b01_0000_0000;   // JMP  (1001) → is_jmp=1
        expected[4'hE] = 10'b10_0000_0000;   // STP  (1110) → is_stp=1
        // 非法指令：全部为 0
        expected[4'h0] = 10'b00_0000_0000;   // 0000
        expected[4'hA] = 10'b00_0000_0000;   // 1010
        expected[4'hB] = 10'b00_0000_0000;   // 1011
        expected[4'hC] = 10'b00_0000_0000;   // 1100
        expected[4'hD] = 10'b00_0000_0000;   // 1101
        expected[4'hF] = 10'b00_0000_0000;   // 1111

        // ---- 测试开始 ----
        pass_cnt = 0;
        fail_cnt = 0;

        $display("");
        $display("============================================================");
        $display("  指令译码器 (instruction_decoder) 仿真测试");
        $display("============================================================");
        $display("测试范围: 遍历 ir=0000 ~ 1111 全部 16 种输入");
        $display("合法指令: ADD(0001) SUB(0010) AND(0011) INC(0100) LD(0101)");
        $display("          ST(0110)  JC(0111)  JZ(1000)  JMP(1001) STP(1110)");
        $display("非法指令: 0000, 1010, 1011, 1100, 1101, 1111");
        $display("");

        // ----------------------------------------------------------
        // 测试 1: 遍历全部 16 种输入（一键回归测试）
        // 意义：保证每条指令的译码结果有且仅有一个信号为 1，
        //       非法指令全部输出为 0。这是译码器最基本的正确性。
        // 预期：每次 ir 变化后，组合逻辑立即产生对应输出。
        // ----------------------------------------------------------
        $display("--- 测试1: 遍历全部 16 种输入 ---");
        for (i = 0; i < 16; i = i + 1) begin
            ir = i[3:0];
            #50;  // 等组合逻辑稳定（无时钟，但给仿真器一点时间）

            if (decoded === expected[i]) begin
                pass_cnt = pass_cnt + 1;
                $display("[PASS]ir=%b,decoded=%b", i[3:0], decoded);
            end else begin
                fail_cnt = fail_cnt + 1;
                $display("[FAIL]ir=%b:%b %b", i[3:0], expected[i], decoded);

                // 详细列出哪一位错了（帮助调试）
                if (decoded[0] !== expected[i][0])
                    $display("位0(is_add): 期望%b 实际%b", expected[i][0], decoded[0]);
                if (decoded[1] !== expected[i][1])
                    $display("位1(is_sub): 期望%b 实际%b", expected[i][1], decoded[1]);
                if (decoded[2] !== expected[i][2])
                    $display("位2(is_and): 期望%b 实际%b", expected[i][2], decoded[2]);
                if (decoded[3] !== expected[i][3])
                    $display("位3(is_inc): 期望%b 实际%b", expected[i][3], decoded[3]);
                if (decoded[4] !== expected[i][4])
                    $display("位4(is_ld):  期望%b 实际%b", expected[i][4], decoded[4]);
                if (decoded[5] !== expected[i][5])
                    $display("位5(is_st):  期望%b 实际%b", expected[i][5], decoded[5]);
                if (decoded[6] !== expected[i][6])
                    $display("位6(is_jc):  期望%b 实际%b", expected[i][6], decoded[6]);
                if (decoded[7] !== expected[i][7])
                    $display("位7(is_jz):  期望%b 实际%b", expected[i][7], decoded[7]);
                if (decoded[8] !== expected[i][8])
                    $display("位8(is_jmp): 期望%b 实际%b", expected[i][8], decoded[8]);
                if (decoded[9] !== expected[i][9])
                    $display("位9(is_stp): 期望%b 实际%b", expected[i][9], decoded[9]);
            end
        end

        // ----------------------------------------------------------
        // 测试 2: 互斥性检查（没有两条指令同时为 1）
        // 意义：译码器的一个重要约束——同一时刻只能识别一条指令。
        //       如果同时有 ≥2 个信号为 1，说明译码逻辑有 bug
        //       （例如 case 分支遗漏了对其它信号清零）。
        // 预期：每条合法指令有且仅有一个信号为 1；
        //       非法指令全部为 0。
        // ----------------------------------------------------------
        $display("");
        $display("--- 测试2: 互斥性检查（每次最多一个信号为 1）---");
        for (i = 0; i < 16; i = i + 1) begin
            ir = i[3:0];
            #50;

            // $countones 是 SystemVerilog 函数，Verilog-2001 用加法手动实现
            if ((is_add + is_sub + is_and + is_inc + is_ld +
                 is_st + is_jc + is_jz + is_jmp + is_stp) > 1) begin
                fail_cnt = fail_cnt + 1;
                $display("  [FAIL] ir=%b: 同时有多个信号为 1! decoded=%b", i[3:0], decoded);
            end
        end

        // ----------------------------------------------------------
        // 测试 3: 组合逻辑响应速度（切换输入后是否立即变化）
        // 意义：译码器是纯组合逻辑，输出必须在输入变化后极短时间内
        //       稳定。如果输出有 glitch（毛刺）或者延迟过大，
        //       可能导致后续模块采样到错误信号。
        // 预期：ir 切换后 #20 内输出稳定到正确值。
        // ----------------------------------------------------------
        $display("");
        $display("--- 测试3: 组合逻辑响应速度检查 ---");
        ir = 4'b0001;  // ADD
        #50;
        if (is_add !== 1'b1) begin
            fail_cnt = fail_cnt + 1;
            $display("  [FAIL] ir=0001 时 ADD 未正确响应: is_add=%b", is_add);
        end else begin
            $display("  [OK] ADD 指令译码正确: is_add=1, 其余=0");
        end

        // 快速切换：ADD → SUB → AND → LD → 非法
        ir = 4'b0010;  // SUB
        #20;
        if (is_sub !== 1'b1 || is_add !== 1'b0) begin
            fail_cnt = fail_cnt + 1;
            $display("  [FAIL] 切换到 SUB: is_sub=%b is_add=%b (应 1,0)", is_sub, is_add);
        end

        ir = 4'b0011;  // AND
        #20;
        if (is_and !== 1'b1 || is_sub !== 1'b0) begin
            fail_cnt = fail_cnt + 1;
            $display("  [FAIL] 切换到 AND: is_and=%b is_sub=%b (应 1,0)", is_and, is_sub);
        end

        ir = 4'b0101;  // LD
        #20;
        if (is_ld !== 1'b1 || is_and !== 1'b0) begin
            fail_cnt = fail_cnt + 1;
            $display("  [FAIL] 切换到 LD: is_ld=%b is_and=%b (应 1,0)", is_ld, is_and);
        end

        ir = 4'b1100;  // 非法
        #20;
        if (is_ld !== 1'b0) begin
            fail_cnt = fail_cnt + 1;
            $display("  [FAIL] 切换到非法指令 1100: is_ld=%b (应 0)", is_ld);
        end

        // ----------------------------------------------------------
        // 测试 4: 边界码检查（最高位和最低位）
        // 意义：确保译码器不会混淆只差一位的编码，比如
        //       STP(1110) vs 1111，JMP(1001) vs 1000(JZ)。
        // 预期：相邻编码之间严格区分。
        // ----------------------------------------------------------
        $display("");
        $display("--- 测试4: 边界码区分检查 ---");
        // 1110(STP) vs 1111(非法)
        ir = 4'b1110;
        #50;
        if (is_stp !== 1'b1) begin
            fail_cnt = fail_cnt + 1;
            $display("  [FAIL] ir=1110: is_stp=%b (应 1)", is_stp);
        end else
            $display("  [OK] ir=1110 (STP): is_stp=1 ✓");

        ir = 4'b1111;
        #50;
        if (decoded !== 10'b00_0000_0000) begin
            fail_cnt = fail_cnt + 1;
            $display("  [FAIL] ir=1111: decoded=%b (应全 0)", decoded);
        end else
            $display("  [OK] ir=1111 (非法): 全部输出 0 ✓");

        // JMP(1001) vs JZ(1000)
        ir = 4'b1001;
        #50;
        if (is_jmp !== 1'b1 || is_jz !== 1'b0) begin
            fail_cnt = fail_cnt + 1;
            $display("  [FAIL] ir=1001: is_jmp=%b is_jz=%b (应 1,0)", is_jmp, is_jz);
        end else
            $display("  [OK] ir=1001 (JMP) vs 1000 (JZ) 区分正确 ✓");

        // ============================================================
        // 测试总结
        // ============================================================
        $display("");
        $display("============================================================");
        $display("  测试结果: 通过 %0d / 失败 %0d", pass_cnt, fail_cnt);
        if (fail_cnt == 0)
            $display("  结论: instruction_decoder 全部测试通过! ✓");
        else
            $display("  结论: 存在 %0d 个失败用例，请检查译码逻辑 ✗", fail_cnt);
        $display("============================================================");

        $finish;
    end

endmodule
