// ============================================================
// 文件名: tb_alu_control.v  ——  ALU 控制接口 Testbench
// 所属项目: TEC-8 模型机控制器（题目A）
//
// 测试目标:
//   验证 alu_control 是否能在正确的节拍下，为每条运算指令产生
//   正确的 cin（进位输入）、ldz（Z 标志加载）、ldc（C 标志加载）。
//
// 测试策略:
//   场景驱动：模拟"当前正在执行某条指令，时序推进到某个节拍"，
//   检查 alu_control 在该节拍下的输出是否正确。
//   不测试 LD/ST/Jxx/STP —— 它们不由 alu_control 处理。
// ============================================================

`timescale 1ns / 100ps

module tb_alu_control;

    // ---- 被测模块的输入 ----
    reg        is_add, is_sub, is_and, is_inc, is_ld;
    reg        t1, t2, t3;
    // ---- 被测模块的输出 ----
    wire       cin, ldz, ldc;

    // ---- 例化被测模块 ----
    alu_control uut (
        .is_add (is_add),
        .is_sub (is_sub),
        .is_and (is_and),
        .is_inc (is_inc),
        .is_ld  (is_ld),
        .t1     (t1),
        .t2     (t2),
        .t3     (t3),
        .cin    (cin),
        .ldz    (ldz),
        .ldc    (ldc)
    );

    integer pass_cnt, fail_cnt;

    // ================================================================
    // 辅助任务: set_inst — 设置当前执行的指令为指定类型
    // 和单指令译码器不同,这里 already @(*) 中直接判断信号组合
    // ================================================================
    task set_inst;
        input [3:0] code;  // 1=ADD, 2=SUB, 3=AND, 4=INC, 5=LD, 0=NONE
        begin
            {is_add, is_sub, is_and, is_inc, is_ld} = 5'b00000;
            case (code)
                1: is_add = 1;
                2: is_sub = 1;
                3: is_and = 1;
                4: is_inc = 1;
                5: is_ld  = 1;
                default: ;  // 全 0 = 无有效指令
            endcase
        end
    endtask

    // ================================================================
    // 辅助任务: set_timing — 设置当前节拍
    // ================================================================
    task set_timing;
        input [1:0] phase;  // 0=idle, 1=T1, 2=T2, 3=T3
        begin
            {t1, t2, t3} = 3'b000;
            case (phase)
                1: t1 = 1;
                2: t2 = 1;
                3: t3 = 1;
                default: ;  // idle = 全部 0
            endcase
        end
    endtask

    // ================================================================
    // 辅助任务: check — 检查 cin/ldz/ldc 是否等于预期值
    // ================================================================
    task check;
        input [255:0] case_name;    // 测试用例描述
        input         exp_cin;      // 预期 cin
        input         exp_ldz;      // 预期 ldz
        input         exp_ldc;      // 预期 ldc
        begin
            if (cin === exp_cin && ldz === exp_ldz && ldc === exp_ldc) begin
                pass_cnt = pass_cnt + 1;
                $display("  [PASS] %0s: cin=%b ldz=%b ldc=%b  ✓", case_name, cin, ldz, ldc);
            end else begin
                fail_cnt = fail_cnt + 1;
                $display("  [FAIL] %0s:", case_name);
                $display("         期望 cin=%b ldz=%b ldc=%b", exp_cin, exp_ldz, exp_ldc);
                $display("         实际 cin=%b ldz=%b ldc=%b  ✗", cin, ldz, ldc);
            end
        end
    endtask


    // ================================================================
    // 主测试流程
    // ================================================================
    initial begin
        pass_cnt = 0;
        fail_cnt = 0;

        $display("");
        $display("============================================================");
        $display("  alu_control ALU 控制接口仿真测试");
        $display("============================================================");
        $display("测试内容:");
        $display("  - 每条算术指令在正确节拍的 cin/ldz/ldc 输出");
        $display("  - 非运算节拍（T2/T3/idle）下所有输出应为 0");
        $display("  - 无指令时所有输出应为 0");
        $display("  - LD 指令不产生 ALU 控制信号");
        $display("");

        // ---- 初始状态（无指令，无节拍）----
        set_inst(0);
        set_timing(0);
        #50;

        // ============================================================
        // 测试 1-4: 每条算术指令在 T1 节拍下的行为
        //
        // 意义：T1 是 ALU 运算节拍。所有算术指令（ADD/SUB/AND/INC）
        //       都在 T1 发出正确的进位输入和标志加载信号。
        //       如果这里错了，ALU 就算不出正确结果。
        //
        // 预期波形（以 ADD 为例）：
        //   is_add:  ▁▁▁▁▁█████████████▁▁▁▁▁
        //   t1:      ▁▁▁▁▁▁▁▁▁▁████▁▁▁▁▁▁▁▁
        //   cin:     ▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁  (ADD: cin=0)
        //   ldz:     ▁▁▁▁▁▁▁▁▁▁████▁▁▁▁▁▁▁▁  (T1 期间 ldz=1)
        //   ldc:     ▁▁▁▁▁▁▁▁▁▁████▁▁▁▁▁▁▁▁  (T1 期间 ldc=1)
        // ============================================================

        // ----- Test 1: ADD -----
        $display("--- 测试组A: 算术指令在 T1 节拍 ---");
        set_inst(1);    // ADD
        set_timing(1);  // T1
        #50;
        check("ADD @ T1: cin=0 ldz=1 ldc=1", 1'b0, 1'b1, 1'b1);

        // ----- Test 2: SUB -----
        // 意义：减法实质是补码加法，需要 cin=1（借位初始值）。
        //       SUB 和 ADD 的区别只有 cin，如果混淆则结果完全错误。
        // 预期：cin=1, ldz=1, ldc=1
        set_inst(2);    // SUB
        set_timing(1);  // T1
        #50;
        check("SUB @ T1: cin=1 ldz=1 ldc=1", 1'b1, 1'b1, 1'b1);

        // ----- Test 3: AND -----
        // 意义：逻辑运算无进位概念，ldc 应为 0。
        //       ldz=1 因为 AND 结果可能为 0（需要更新 Z 标志）。
        //       如果 ldc 因为惯性为 1，会错误更新进位标志。
        // 预期：cin=0, ldz=1, ldc=0
        set_inst(3);    // AND
        set_timing(1);  // T1
        #50;
        check("AND @ T1: cin=0 ldz=1 ldc=0", 1'b0, 1'b1, 1'b0);

        // ----- Test 4: INC -----
        // 意义：INC 实现自增 1，实质是 +1 运算，需要 cin=1。
        //       ldz/ldc 都要更新（INC 可能溢出，影响 Z 和 C）。
        // 预期：cin=1, ldz=1, ldc=1
        set_inst(4);    // INC
        set_timing(1);  // T1
        #50;
        check("INC @ T1: cin=1 ldz=1 ldc=1", 1'b1, 1'b1, 1'b1);

        // ============================================================
        // 测试 5-7: 算术指令在非运算节拍（T2 / T3）下输出应为 0
        //
        // 意义：alu_control 只在 T1 才产生控制信号。T2/T3 期间
        //       如果仍然有信号输出，会导致 ALU 重复操作或标志位
        //       被意外覆盖，破坏后面的执行步骤。
        //
        // 预期波形（ADD 在 T2、T3）：
        //   is_add:  ▁▁▁▁▁███████████████████████▁▁▁
        //   t2:      ▁▁▁▁▁▁▁▁▁▁▁▁▁▁████▁▁▁▁▁▁▁▁▁▁▁
        //   ldz:     ▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁  (T2 期间 ldz=0)
        //   ldc:     ▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁  (T2 期间 ldc=0)
        // ============================================================
        $display("");
        $display("--- 测试组B: 算术指令在非 T1 节拍（应全 0）---");

        set_inst(1);    // ADD
        set_timing(2);  // T2
        #50;
        check("ADD @ T2: 全部输出应为 0", 1'b0, 1'b0, 1'b0);

        set_timing(3);  // T3
        #50;
        check("ADD @ T3: 全部输出应为 0", 1'b0, 1'b0, 1'b0);

        set_inst(2);    // SUB
        set_timing(2);  // T2
        #50;
        check("SUB @ T2: 全部输出应为 0", 1'b0, 1'b0, 1'b0);

        set_inst(3);    // AND
        set_timing(3);  // T3
        #50;
        check("AND @ T3: 全部输出应为 0", 1'b0, 1'b0, 1'b0);

        // ============================================================
        // 测试 8: 无有效指令时的输出（空闲状态）
        //
        // 意义：取指周期或指令间空隙，所有 is_xxx 都是 0。
        //       此时 alu_control 不应产生任何有效输出。
        // 预期：全部输出为 0。
        // ============================================================
        $display("");
        $display("--- 测试组C: 无有效指令（空闲）---");

        set_inst(0);    // 无指令
        set_timing(1);  // T1（即使有时钟，没有指令也应输出 0）
        #50;
        check("idle @ T1: 无指令时全部为 0", 1'b0, 1'b0, 1'b0);

        set_timing(2);
        #50;
        check("idle @ T2: 无指令时全部为 0", 1'b0, 1'b0, 1'b0);

        set_timing(3);
        #50;
        check("idle @ T3: 无指令时全部为 0", 1'b0, 1'b0, 1'b0);

        // ============================================================
        // 测试 9: LD 指令不产生 ALU 控制信号
        //
        // 意义：LD 是访存指令，运算不由 ALU 处理。
        //       alu_control 即使收到 is_ld=1 也不应输出信号，
        //       否则会和 control_unit 的控制信号冲突。
        // 预期：全部输出为 0。
        // ============================================================
        $display("");
        $display("--- 测试组D: LD 指令不产生 ALU 信号 ---");

        set_inst(5);    // LD
        set_timing(1);  // T1
        #50;
        check("LD @ T1: cin=0 ldz=0 ldc=0", 1'b0, 1'b0, 1'b0);

        set_timing(2);
        #50;
        check("LD @ T2: 全部为 0", 1'b0, 1'b0, 1'b0);

        set_timing(3);
        #50;
        check("LD @ T3: 全部为 0", 1'b0, 1'b0, 1'b0);

        // ============================================================
        // 测试 10: 节拍切换检查（T1→T2 过渡时信号是否正确清零）
        //
        // 意义：模拟真实运行时从 T1 进入 T2 的时刻。
        //       T1 期间有控制信号，T1 结束后信号应立刻清零。
        //       如果信号没有及时清零，会污染 T2 节拍的操作。
        //
        // 预期波形：
        //   t1:      ▁▁▁▁▁▁▁▁████▁▁▁▁▁▁▁▁▁▁▁▁▁▁
        //   ldz/ldc: ▁▁▁▁▁▁▁▁████▁▁▁▁▁▁▁▁▁▁▁▁▁▁
        //   (T1 结束时应立即回到 0)
        // ============================================================
        $display("");
        $display("--- 测试组E: 节拍切换——信号清零检查 ---");

        set_inst(1);    // ADD
        set_timing(1);  // T1
        #50;
        if (ldz !== 1'b1 || ldc !== 1'b1) begin
            fail_cnt = fail_cnt + 1;
            $display("  [FAIL] ADD @ T1 信号未正确建立: ldz=%b ldc=%b", ldz, ldc);
        end

        set_timing(0);  // 切换到空闲（模拟 T1 结束）
        #20;
        if (ldz !== 1'b0 || ldc !== 1'b0) begin
            fail_cnt = fail_cnt + 1;
            $display("  [FAIL] ADD T1 结束后信号未清零: ldz=%b ldc=%b", ldz, ldc);
        end else begin
            pass_cnt = pass_cnt + 1;
            $display("  [PASS] ADD T1→idle 切换: ldz=%b ldc=%b (正确清零) ✓", ldz, ldc);
        end

        // ---- 同类检查：INC 在 T3 进入后不应有输出 ----
        set_inst(4);    // INC
        set_timing(1);  // T1
        #50;
        set_timing(3);  // 切换到 T3（中间跳过了 T2）
        #20;
        if (ldz !== 1'b0 || ldc !== 1'b0) begin
            fail_cnt = fail_cnt + 1;
            $display("  [FAIL] INC T1→T3 切换: ldz=%b ldc=%b (应全 0)", ldz, ldc);
        end else begin
            pass_cnt = pass_cnt + 1;
            $display("  [PASS] INC T1→T3 切换: 输出正确清零 ✓");
        end

        // ============================================================
        // 测试总结
        // ============================================================
        $display("");
        $display("============================================================");
        $display("  测试结果: 通过 %0d / 失败 %0d", pass_cnt, fail_cnt);
        if (fail_cnt == 0)
            $display("  结论: alu_control 全部测试通过! ✓");
        else
            $display("  结论: 存在 %0d 个失败用例，请检查 alu_control.v ✗", fail_cnt);
        $display("============================================================");

        $finish;
    end

endmodule
