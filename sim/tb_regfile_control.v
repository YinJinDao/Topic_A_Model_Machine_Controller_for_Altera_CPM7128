// ============================================================
// 文件名: tb_regfile_control.v  ——  寄存器组控制 Testbench
// 所属项目: TEC-8 模型机控制器（题目A）
//
// 测试目标:
//   验证 regfile_control 是否能根据指令类型（操作码 IR[7:4]）
//   和时序节拍（T1/T2/T3），正确产生寄存器堆的读写选择信号。
//
//   输出信号含义:
//     rs0, rs1  — 源寄存器选择地址（IR[1:0] 译码）
//     rd0, rd1  — 目标寄存器选择地址：
//                  双操作数指令 = IR[3:2]
//                  单操作数指令(INC/LD) = IR[1:0]
//     lr0~lr3   — 目标寄存器加载使能（二四译码输出，T3 节拍有效）
//     s0~s3     — 寄存器选择器控制（TEC-8 规格：011=读, 100=写）
//
// 测试策略:
//   模拟完整 IR 编码（IR[7:0]），覆盖运算类、访存类指令，
//   检查在不同节拍下 rs/rd/lr/s 信号的正确性。
// ============================================================

`timescale 1ns / 100ps

module tb_regfile_control;

    // ---- 被测模块输入 ----
    reg  [7:0] ir;          // 完整指令 IR[7:0]
    reg        t1, t2, t3;
    // ---- 被测模块输出 ----
    wire       lr0, lr1, lr2, lr3;
    wire       rs0, rs1;
    wire       rd0, rd1;
    wire       s0, s1, s2, s3;

    integer pass_cnt, fail_cnt;

    // ---- 例化被测模块 ----
    regfile_control uut (
        .ir (ir),
        .t1 (t1), .t2 (t2), .t3 (t3),
        .lr0(lr0), .lr1(lr1), .lr2(lr2), .lr3(lr3),
        .rs0(rs0), .rs1(rs1),
        .rd0(rd0), .rd1(rd1),
        .s0(s0), .s1(s1), .s2(s2), .s3(s3)
    );

    // ---- 打包信号方便检查 ----
    wire [3:0] lr;     // {lr3, lr2, lr1, lr0}
    wire [1:0] rs;     // {rs1, rs0}
    wire [1:0] rd;     // {rd1, rd0}
    wire [3:0] ss;     // {s3, s2, s1, s0}

    assign lr = {lr3, lr2, lr1, lr0};
    assign rs = {rs1, rs0};
    assign rd = {rd1, rd0};
    assign ss = {s3, s2, s1, s0};

    initial begin
        pass_cnt = 0;
        fail_cnt = 0;

        {t1, t2, t3} = 3'b000;
        ir = 8'b0;

        $display("");
        $display("============================================================");
        $display("  regfile_control 寄存器组控制仿真测试");
        $display("============================================================");
        $display("测试内容:");
        $display("  - 双操作数指令（ADD/SUB/AND）: T1 读寄存器, T3 写寄存器");
        $display("  - 单操作数指令（INC/LD）: rd=IR[1:0]（只操作一个寄存器）");
        $display("  - 访存指令（ST）: T2 读源寄存器");
        $display("  - 寄存器地址译码（rs/rd/lr）");
        $display("  - 选择器控制信号（s0~s3）");
        $display("");

        // ============================================================
        // 测试 1: ADD R1, R0（IR = 0001_01_00）
        //
        // 译码: opcode=0001(ADD), 目标=Rj=R1(01), 源=Ri=R0(00)
        //
        // 意义：最基本的双操作数指令
        //       rs = Ri = R0 (00)
        //       rd = Rj = R1 (01)
        //       T1: S=011（读寄存器 R0/R1 的数据送 ALU）
        //       T3: lr[1]=1（结果写回 R1），S=100（写操作）
        //
        // 预期波形:
        //   t1:      ▁▁▁▁████▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁
        //   t3:      ▁▁▁▁▁▁▁▁▁▁▁▁████▁▁▁▁▁▁▁▁
        //   rs[1:0]: ▁▁▁▁▁00▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁  始终=00(R0)
        //   rd[1:0]: ▁▁▁▁▁01▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁  始终=01(R1)
        //   lr[3:0]: ▁▁▁▁▁00▁▁▁▁▁▁▁▁▁02▁▁▁▁▁▁  T3: lr1=1
        //   ss[3:0]: ▁▁▁▁▁03▁▁▁▁▁▁▁▁▁04▁▁▁▁▁▁  T1: s1,s0=1(011), T3: s2=1(100)
        // ============================================================
        $display("--- 测试1: ADD R1, R0  (IR = 0001_01_00) ---");

        ir = 8'b0001_01_00;   // opcode=0001, Rj=01(R1), Ri=00(R0)
        {t1,t2,t3} = 3'b000;
        #30;

        // 组合逻辑部分：rs/rd 应该始终有效
        if (rs === 2'b00 && rd === 2'b01) begin
            pass_cnt = pass_cnt + 1;
            $display("  [PASS] ADD R1,R0: rs=%b(R0) rd=%b(R1) ✓", rs, rd);
        end else begin
            fail_cnt = fail_cnt + 1;
            $display("  [FAIL] ADD R1,R0: rs=%b(期望 00) rd=%b(期望 01) ✗", rs, rd);
        end

        // T1 节拍：选择器 = 011 (s1=1, s0=1)，读寄存器
        {t1,t2,t3} = 3'b100;
        #30;
        if (ss === 4'b0011) begin  // s1=1, s0=1 → 011
            pass_cnt = pass_cnt + 1;
            $display("  [PASS] ADD T1: s[3:0]=%b (011=读寄存器) ✓", ss);
        end else begin
            fail_cnt = fail_cnt + 1;
            $display("  [FAIL] ADD T1: s[3:0]=%b (期望 0011) ✗", ss);
        end

        // T3 节拍：lr1=1（写 R1），s2=1（选择器=100=写操作）
        {t1,t2,t3} = 3'b001;
        #30;
        if (lr === 4'b0010 && ss[2] === 1'b1) begin
            pass_cnt = pass_cnt + 1;
            $display("  [PASS] ADD T3: lr=%b(R1) ss[2]=%b(s2=1=写) ✓", lr, ss[2]);
        end else begin
            fail_cnt = fail_cnt + 1;
            $display("  [FAIL] ADD T3: lr=%b(期望 0010) ss[2]=%b(期望 1) ✗", lr, ss[2]);
        end

        // ============================================================
        // 测试 2: SUB R3, R2（IR = 0010_11_10）
        //
        // 译码: opcode=0010(SUB), 目标=Rj=11(R3), 源=Ri=10(R2)
        //
        // 意义：验证不同的寄存器编号组合
        //       rs = Ri = R2 (10)
        //       rd = Rj = R3 (11)
        //       T3: lr[3]=1（写回 R3）
        // ============================================================
        $display("");
        $display("--- 测试2: SUB R3, R2  (IR = 0010_11_10) ---");

        ir = 8'b0010_11_10;   // opcode=0010, Rj=11(R3), Ri=10(R2)
        {t1,t2,t3} = 3'b000;
        #30;

        if (rs === 2'b10 && rd === 2'b11) begin
            pass_cnt = pass_cnt + 1;
            $display("  [PASS] SUB R3,R2: rs=%b(R2) rd=%b(R3) ✓", rs, rd);
        end else begin
            fail_cnt = fail_cnt + 1;
            $display("  [FAIL] SUB R3,R2: rs=%b(期望 10) rd=%b(期望 11) ✗", rs, rd);
        end

        // T3：lr[3]=1 写回 R3
        {t1,t2,t3} = 3'b001;
        #30;
        if (lr[3] === 1'b1) begin
            pass_cnt = pass_cnt + 1;
            $display("  [PASS] SUB T3: lr[3]=1 (写 R3) ✓");
        end else begin
            fail_cnt = fail_cnt + 1;
            $display("  [FAIL] SUB T3: lr[3]=%b (期望 1) ✗", lr[3]);
        end

        // ============================================================
        // 测试 3: INC R2（IR = 0100_xx_10）
        //
        // 译码: opcode=0100(INC), 单操作数 Ri=R2(10)
        //
        // 意义：单操作数指令的特殊之处在于 rd 也是 IR[1:0]，
        //       因为 INC 的源和目标都是同一个寄存器。
        //       rs = IR[1:0] = 10 (R2)
        //       rd = IR[1:0] = 10 (R2)
        //
        // 预期: rs=10, rd=10（读写同一个寄存器）
        //       T1: ABUS 读 R2
        //       T3: lr[2]=1 写回 R2
        // ============================================================
        $display("");
        $display("--- 测试3: INC R2  (IR = 0100_xx_10) ---");

        ir = 8'b0100_00_10;   // opcode=0100, Rj无关, Ri=10(R2)
        {t1,t2,t3} = 3'b000;
        #30;

        if (rs === 2'b10 && rd === 2'b10) begin
            pass_cnt = pass_cnt + 1;
            $display("  [PASS] INC R2: rs=%b rd=%b (单操作数: 读写同一寄存器) ✓", rs, rd);
        end else begin
            fail_cnt = fail_cnt + 1;
            $display("  [FAIL] INC R2: rs=%b(期望 10) rd=%b(期望 10) ✗", rs, rd);
        end

        // T3: lr[2]=1
        {t1,t2,t3} = 3'b001;
        #30;
        if (lr[2] === 1'b1) begin
            pass_cnt = pass_cnt + 1;
            $display("  [PASS] INC T3: lr[2]=1 (写 R2) ✓");
        end else begin
            fail_cnt = fail_cnt + 1;
            $display("  [FAIL] INC T3: lr[2]=%b (期望 1) ✗", lr[2]);
        end

        // ============================================================
        // 测试 4: LD R3, [addr]（IR = 0101_xx_11）
        //
        // 译码: opcode=0101(LD), 单操作数 Ri=R3(11)
        //
        // 意义：LD 也是单操作数，rd = IR[1:0]
        //       LD 不在 T1 读寄存器（地址计算由 control_unit 控制）
        //       T3: lr[3]=1，s2=1（从内存写数据到 R3）
        //
        // 预期: T3 时 lr[3]=1, s2=1
        // ============================================================
        $display("");
        $display("--- 测试4: LD R3, [addr]  (IR = 0101_xx_11) ---");

        ir = 8'b0101_00_11;   // opcode=0101, Ri=11(R3)
        {t1,t2,t3} = 3'b000;
        #30;

        if (rd === 2'b11) begin
            pass_cnt = pass_cnt + 1;
            $display("  [PASS] LD R3: rd=%b(R3) ✓", rd);
        end else begin
            fail_cnt = fail_cnt + 1;
            $display("  [FAIL] LD R3: rd=%b(期望 11) ✗", rd);
        end

        // T3: lr[3]=1, s2=1
        {t1,t2,t3} = 3'b001;
        #30;
        if (lr[3] === 1'b1 && ss[2] === 1'b1) begin
            pass_cnt = pass_cnt + 1;
            $display("  [PASS] LD T3: lr=%b(R3) ss[2]=1 ✓", lr);
        end else begin
            fail_cnt = fail_cnt + 1;
            $display("  [FAIL] LD T3: lr=%b(期望 1000) ss[2]=%b(期望 1) ✗", lr, ss[2]);
        end

        // ============================================================
        // 测试 5: ST R1, [addr]（IR = 0110_xx_01）
        //
        // 译码: opcode=0110(ST), 源 Ri=R1(01)
        //
        // 意义：ST 在 T2 节拍读源寄存器（S=011=读），输出到数据总线
        //       无写回操作（lr 全为 0）
        //
        // 预期: T2: s1=1 s0=1 (011=读), s2=0 (不是写)
        //       T3: lr 全 0
        // ============================================================
        $display("");
        $display("--- 测试5: ST R1, [addr]  (IR = 0110_xx_01) ---");

        ir = 8'b0110_00_01;   // opcode=0110, Ri=01(R1)
        {t1,t2,t3} = 3'b010;  // T2
        #30;

        if (ss[1:0] === 2'b11) begin  // s1=1, s0=1 → 读寄存器
            pass_cnt = pass_cnt + 1;
            $display("  [PASS] ST T2: s1=1 s0=1 (011=读寄存器) ✓");
        end else begin
            fail_cnt = fail_cnt + 1;
            $display("  [FAIL] ST T2: s[1:0]=%b(期望 11) ✗", ss[1:0]);
        end

        // T3: 无写回
        {t1,t2,t3} = 3'b001;
        #30;
        if (lr === 4'b0000) begin
            pass_cnt = pass_cnt + 1;
            $display("  [PASS] ST T3: lr=0000 (无写回) ✓");
        end else begin
            fail_cnt = fail_cnt + 1;
            $display("  [FAIL] ST T3: lr=%b(期望 0000) ✗", lr);
        end

        // ============================================================
        // 测试 6: 非运算类指令不产生写回（JMP）
        //
        // 意义：跳转指令不应写寄存器
        // 预期：T3 时 lr 全 0
        // ============================================================
        $display("");
        $display("--- 测试6: 跳转指令不写寄存器 (JMP) ---");

        ir = 8'b1001_00_00;   // opcode=1001(JMP)
        {t1,t2,t3} = 3'b001;  // T3
        #30;

        if (lr === 4'b0000) begin
            pass_cnt = pass_cnt + 1;
            $display("  [PASS] JMP T3: lr=0000 (跳转不写寄存器) ✓");
        end else begin
            fail_cnt = fail_cnt + 1;
            $display("  [FAIL] JMP T3: lr=%b(期望 0000) ✗", lr);
        end

        // ============================================================
        // 测试 7: 非有效节拍下 lr 全为 0
        //
        // 意义：lr 信号只在 T3 && reg_write 时有效
        //       reg_write = is_arith || is_ld，非这些时 lr 应全 0
        // 预期：ADD 指令但节拍是 T2 时，lr 全 0
        // ============================================================
        $display("");
        $display("--- 测试7: 非有效节拍下无写使能 ---");

        ir = 8'b0001_01_00;   // ADD R1, R0
        {t1,t2,t3} = 3'b010;  // T2——不是写回节拍
        #30;

        if (lr === 4'b0000) begin
            pass_cnt = pass_cnt + 1;
            $display("  [PASS] ADD T2: lr=0000（非写回节拍）✓");
        end else begin
            fail_cnt = fail_cnt + 1;
            $display("  [FAIL] ADD T2: lr=%b(期望 0000) ✗", lr);
        end

        // ============================================================
        // 测试 8: STP 停机指令无写回
        // ============================================================
        $display("");
        $display("--- 测试8: STP 停机指令不写寄存器 ---");

        ir = 8'b1110_00_00;   // opcode=1110(STP)
        {t1,t2,t3} = 3'b001;  // T3
        #30;

        if (lr === 4'b0000) begin
            pass_cnt = pass_cnt + 1;
            $display("  [PASS] STP T3: lr=0000 ✓");
        end else begin
            fail_cnt = fail_cnt + 1;
            $display("  [FAIL] STP T3: lr=%b(期望 0000) ✗", lr);
        end

        // ============================================================
        // 测试总结
        // ============================================================
        $display("");
        $display("============================================================");
        $display("  测试结果: 通过 %0d / 失败 %0d", pass_cnt, fail_cnt);
        if (fail_cnt == 0)
            $display("  结论: regfile_control 全部测试通过! ✓");
        else
            $display("  结论: 存在 %0d 个失败用例，请检查 regfile_control.v ✗", fail_cnt);
        $display("============================================================");

        $finish;
    end

endmodule
