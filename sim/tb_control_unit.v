// ============================================================
// 文件名: tb_control_unit.v  ——  控制单元 Testbench
// 所属项目: TEC-8 模型机控制器（题目A）
//
// 测试目标:
//   验证 control_unit 是否能为每一条 TEC-8 指令，在正确的节拍下
//   产生正确的全部控制信号（ARINC, DRW, LPC, LAR, LIR, LDZ,
//   LDC, PCINC, PCADD, SELCTL, MEMW, STOP, SHORT, LONG,
//   ABUS, SBUS, MBUS, SST0, S, SEL）。
//
// 测试策略:
//   对每条指令，逐节拍（T1/T2/T3）检查所有相关控制信号的输出值。
//   同时检查"取指周期"（所有指令共享的前两步）。
//   利用 `define 宏让检查代码简洁。
// ============================================================

`timescale 1ns / 100ps

module tb_control_unit;

    // ---- 被测模块的输入 ----
    reg        t1, t2, t3;
    reg        w1, w2, w3;
    reg        is_add, is_sub, is_and, is_inc;
    reg        is_ld, is_st, is_jc, is_jz, is_jmp, is_stp;
    reg        c_flag, z_flag;
    reg  [2:0] sw;

    // ---- 被测模块的输出 ----
    wire       ARINC, CIN, DRW, LPC, LAR, LIR, LDZ, LDC;
    wire       PCINC, PCADD, SELCTL, M, MEMW, STOP;
    wire       SHORT, LONG_, ABUS, SBUS, MBUS, SST0;
    wire [1:0] S, SEL;

    integer pass_cnt, fail_cnt;
    integer total_checks;

    // ---- 例化被测模块 ----
    control_unit uut (
        .t1(t1), .t2(t2), .t3(t3),
        .w1(w1), .w2(w2), .w3(w3),
        .is_add(is_add), .is_sub(is_sub), .is_and(is_and),
        .is_inc(is_inc), .is_ld(is_ld), .is_st(is_st),
        .is_jc(is_jc), .is_jz(is_jz), .is_jmp(is_jmp),
        .is_stp(is_stp),
        .c_flag(c_flag), .z_flag(z_flag), .sw(sw),
        .ARINC(ARINC), .CIN(CIN), .DRW(DRW),
        .LPC(LPC), .LAR(LAR), .LIR(LIR), .LDZ(LDZ), .LDC(LDC),
        .PCINC(PCINC), .PCADD(PCADD), .SELCTL(SELCTL),
        .M(M), .MEMW(MEMW), .STOP(STOP),
        .SHORT(SHORT), .LONG(LONG_),
        .ABUS(ABUS), .SBUS(SBUS), .MBUS(MBUS),
        .SST0(SST0), .S(S), .SEL(SEL)
    );

    // ================================================================
    // 快捷宏：逐位检查一组信号的期望值
    // 用法：`CHECK(desc, {sig1,sig2,...}, expected_bitmask, mask_width)
    // ================================================================
    `define CHECK_MASK(desc, signals, expected, width) \
        begin \
            if (signals === (width)'(expected)) begin \
                pass_cnt = pass_cnt + 1; \
            end else begin \
                fail_cnt = fail_cnt + 1; \
                $display("  [FAIL] %0s: 期望=%0b 实际=%0b", desc, (width)'(expected), signals); \
            end \
            total_checks = total_checks + 1; \
        end

    // ================================================================
    // 辅助任务：设置指令
    // ================================================================
    task set_inst;
        input [31:0] name;  // 仅用于可读性
        input [9:0]  sigs;  // {is_stp,is_jmp,is_jz,is_jc,is_st,is_ld,is_inc,is_and,is_sub,is_add}
        begin
            {is_stp, is_jmp, is_jz, is_jc, is_st, is_ld, is_inc, is_and, is_sub, is_add} = sigs;
        end
    endtask

    // 快捷：取指周期（无有效指令）
    task set_fetch;
        begin
            {is_stp, is_jmp, is_jz, is_jc, is_st, is_ld, is_inc, is_and, is_sub, is_add} = 10'b0;
        end
    endtask

    // ================================================================
    // 主测试
    // ================================================================
    initial begin
        pass_cnt = 0;
        fail_cnt = 0;
        total_checks = 0;

        {t1, t2, t3} = 3'b000;
        {w1, w2, w3} = 3'b000;
        c_flag = 0; z_flag = 0;
        sw = 3'b000;
        set_fetch();

        $display("");
        $display("============================================================");
        $display("  control_unit 控制单元仿真测试");
        $display("============================================================");
        $display("测试内容:");
        $display("  - 取指周期：LIR, PCINC, LAR, SBUS 时序");
        $display("  - 全部 10 条指令的执行周期控制信号");
        $display("  - 条件跳转（JC/JZ）的标志位依赖");
        $display("  - STP 停机信号");
        $display("");

        // ============================================================
        // 测试组 0: 初始空闲状态
        // 意义：无指令、无节拍时，所有信号必须为 0。这是安全基础状态。
        // 预期：全部控制信号为 0。
        // ============================================================
        $display("--- 测试0: 初始空闲状态 ---");
        set_fetch();
        {t1,t2,t3} = 3'b000; {w1,w2,w3} = 3'b000;
        #50;
        `CHECK_MASK("idle: LIR=PCINC=LAR=SBUS=0",
                     {LIR, PCINC, LAR, SBUS}, 4'b0000, 4);
        `CHECK_MASK("idle: STOP=SHORT=LONG=0",
                     {STOP, SHORT, LONG_}, 3'b000, 3);

        // ============================================================
        // 测试 1: 取指周期
        // 意义：所有指令执行前的第一步都是从内存取指令。
        //       T1: 将当前 PC 地址的指令读入 IR（LIR=1），PC 自增（PCINC=1）
        //       T2: 将下一条指令地址加载到 AR（LAR=1, SBUS=1）
        //       T3: 空闲
        //
        // 预期波形:
        //   t1:      ▁▁▁▁████▁▁▁▁▁▁▁▁███    T1 脉冲
        //   t2:      ▁▁▁▁▁▁▁▁████▁▁▁▁▁▁▁    T2 脉冲
        //   LIR:     ▁▁▁▁████▁▁▁▁▁▁▁▁▁▁▁    T1 期间 LIR=1
        //   PCINC:   ▁▁▁▁████▁▁▁▁▁▁▁▁▁▁▁    T1 期间 PCINC=1
        //   LAR:     ▁▁▁▁▁▁▁▁████▁▁▁▁▁▁▁    T2 期间 LAR=1
        //   SBUS:    ▁▁▁▁▁▁▁▁████▁▁▁▁▁▁▁    T2 期间 SBUS=1
        // ============================================================
        $display("--- 测试1: 取指周期 ---");

        set_fetch();
        {t1,t2,t3} = 3'b100;  // T1
        #50;
        `CHECK_MASK("取指 T1: LIR=1 PCINC=1", {LIR, PCINC}, 2'b11, 2);
        `CHECK_MASK("取指 T1: LAR=SBUS=0",    {LAR, SBUS}, 2'b00, 2);

        {t1,t2,t3} = 3'b010;  // T2
        #50;
        `CHECK_MASK("取指 T2: LAR=1 SBUS=1", {LAR, SBUS}, 2'b11, 2);
        `CHECK_MASK("取指 T2: LIR=PCINC=0",  {LIR, PCINC}, 2'b00, 2);

        {t1,t2,t3} = 3'b001;  // T3
        #50;
        `CHECK_MASK("取指 T3: LIR/PCINC/LAR/SBUS=0",
                     {LIR, PCINC, LAR, SBUS}, 4'b0000, 4);

        // ============================================================
        // 测试 2: ADD 指令执行周期
        // 意义：ADD 是典型双操作数算术指令。
        //       T1: SBUS+ABUS 使能，CIN=0（加法不进位），LDZ/LDC 更新标志
        //       w1: DRW 使能（写结果回寄存器）
        //       SHORT=1（短指令周期）
        // 预期：T1: SBUS=ABUS=1, CIN=0, LDZ=LDC=1, SHORT=1
        //       w1: DRW=1
        // ============================================================
        $display("--- 测试2: ADD 指令 ---");
        set_inst("ADD", 10'b00_0000_0001);  // is_add=1

        {t1,t2,t3} = 3'b100; {w1,w2,w3} = 3'b000;
        #50;
        `CHECK_MASK("ADD T1: SBUS=ABUS=1", {SBUS, ABUS}, 2'b11, 2);
        `CHECK_MASK("ADD T1: SHORT=1",     {SHORT},       1'b1,  1);
        `CHECK_MASK("ADD T1: CIN=0",       {CIN},         1'b0,  1);
        `CHECK_MASK("ADD T1: LDZ=LDC=1",   {LDZ, LDC},    2'b11, 2);

        {w1,w2,w3} = 3'b100;  // w1 有效
        #50;
        `CHECK_MASK("ADD w1: DRW=1", {DRW}, 1'b1, 1);

        // ============================================================
        // 测试 3: SUB 指令（与 ADD 的唯一区别是 CIN=1）
        // 意义：减法需要借位初始值 cin=1，其余与 ADD 相同
        // ============================================================
        $display("--- 测试3: SUB 指令 ---");
        set_inst("SUB", 10'b00_0000_0010);  // is_sub=1

        {t1,t2,t3} = 3'b100; {w1,w2,w3} = 3'b000;
        #50;
        `CHECK_MASK("SUB T1: CIN=1", {CIN}, 1'b1, 1);
        `CHECK_MASK("SUB T1: LDZ=LDC=1", {LDZ, LDC}, 2'b11, 2);

        // ============================================================
        // 测试 4: AND 指令（CIN=0, M=1, LDC=0）
        // 意义：逻辑运算 M=1（ALU 选择逻辑运算模式），不更新进位
        // ============================================================
        $display("--- 测试4: AND 指令 ---");
        set_inst("AND", 10'b00_0000_0100);  // is_and=1

        {t1,t2,t3} = 3'b100; {w1,w2,w3} = 3'b000;
        #50;
        `CHECK_MASK("AND T1: M=1",    {M},    1'b1, 1);
        `CHECK_MASK("AND T1: LDC=0",  {LDC},  1'b0, 1);
        `CHECK_MASK("AND T1: LDZ=1",  {LDZ},  1'b1, 1);

        // ============================================================
        // 测试 5: INC 指令（单操作数，ABUS=1, SEL=01）
        // 意义：INC 只需要一个源操作数（Ri），ABUS 使能，SEL=01
        // ============================================================
        $display("--- 测试5: INC 指令 ---");
        set_inst("INC", 10'b00_0000_1000);  // is_inc=1

        {t1,t2,t3} = 3'b100; {w1,w2,w3} = 3'b000;
        #50;
        `CHECK_MASK("INC T1: ABUS=1 CIN=1", {ABUS, CIN}, 2'b11, 2);
        `CHECK_MASK("INC T1: SEL=01",       {SEL},       2'b01,  2);
        `CHECK_MASK("INC: SHORT=1",          {SHORT},     1'b1,   1);

        // ============================================================
        // 测试 6: LD 指令（长指令周期，LONG=1）
        // 意义：LD 是访存指令，需要 3 个节拍
        //       T1: SBUS+LAR+ABUS（计算地址）
        //       T2: MBUS（从存储器读数据）
        //       w2: DRW（写数据到寄存器）
        // ============================================================
        $display("--- 测试6: LD 指令 ---");
        set_inst("LD", 10'b00_0001_0000);  // is_ld=1

        {t1,t2,t3} = 3'b100; {w1,w2,w3} = 3'b000;
        #50;
        `CHECK_MASK("LD T1: SBUS=LAR=ABUS=1", {SBUS, LAR, ABUS}, 3'b111, 3);
        `CHECK_MASK("LD: LONG=1",              {LONG_},            1'b1,   1);

        {t1,t2,t3} = 3'b010;
        #50;
        `CHECK_MASK("LD T2: MBUS=1", {MBUS}, 1'b1, 1);

        {w1,w2,w3} = 3'b010;  // w2
        #50;
        `CHECK_MASK("LD w2: DRW=1", {DRW}, 1'b1, 1);

        // ============================================================
        // 测试 7: ST 指令（LONG=1, T2: SBUS, w2: MEMW）
        // 意义：ST 把寄存器数据写入内存，需要 MEMW 信号
        // ============================================================
        $display("--- 测试7: ST 指令 ---");
        set_inst("ST", 10'b00_0010_0000);  // is_st=1

        {t1,t2,t3} = 3'b100; {w1,w2,w3} = 3'b000;
        #50;
        `CHECK_MASK("ST T1: SBUS=LAR=ABUS=1", {SBUS, LAR, ABUS}, 3'b111, 3);
        `CHECK_MASK("ST: LONG=1",              {LONG_},            1'b1,   1);

        {t1,t2,t3} = 3'b010;
        #50;
        `CHECK_MASK("ST T2: SBUS=1", {SBUS}, 1'b1, 1);

        {w1,w2,w3} = 3'b010;  // w2
        #50;
        `CHECK_MASK("ST w2: MEMW=1", {MEMW}, 1'b1, 1);

        // ============================================================
        // 测试 8-9: JC 指令（条件跳转——只有 c_flag=1 时才跳）
        // 意义：JC 检查进位标志，c_flag=1 时 PCADD+SELCTL=1 实现跳转
        //       c_flag=0 时不跳转
        // ============================================================
        $display("--- 测试8: JC 指令（c_flag=1，应跳转）---");
        set_inst("JC", 10'b00_0100_0000);
        c_flag = 1; z_flag = 0;

        {t1,t2,t3} = 3'b100; {w1,w2,w3} = 3'b000;
        #50;
        `CHECK_MASK("JC(CF=1) T1: PCADD=1 SELCTL=1", {PCADD, SELCTL}, 2'b11, 2);
        `CHECK_MASK("JC: LONG=1", {LONG_}, 1'b1, 1);

        $display("--- 测试9: JC 指令（c_flag=0，不应跳转）---");
        c_flag = 0;
        #50;
        `CHECK_MASK("JC(CF=0) T1: PCADD=0 SELCTL=0", {PCADD, SELCTL}, 2'b00, 2);

        // ============================================================
        // 测试 10-11: JZ 指令（条件跳转——只有 z_flag=1 时才跳）
        // 意义：JZ 检查零标志，z_flag=1 时跳转
        // ============================================================
        $display("--- 测试10: JZ 指令（z_flag=1，应跳转）---");
        set_inst("JZ", 10'b00_1000_0000);
        c_flag = 0; z_flag = 1;

        {t1,t2,t3} = 3'b100;
        #50;
        `CHECK_MASK("JZ(ZF=1) T1: PCADD=1 SELCTL=1", {PCADD, SELCTL}, 2'b11, 2);

        $display("--- 测试11: JZ 指令（z_flag=0，不应跳转）---");
        z_flag = 0;
        #50;
        `CHECK_MASK("JZ(ZF=0) T1: PCADD=0 SELCTL=0", {PCADD, SELCTL}, 2'b00, 2);

        // ============================================================
        // 测试 12: JMP 指令（无条件跳转 LPC+SBUS+SELCTL=1, SHORT=1）
        // 意义：JMP 无条件跳转，不依赖标志位
        // ============================================================
        $display("--- 测试12: JMP 指令 ---");
        set_inst("JMP", 10'b01_0000_0000);

        {t1,t2,t3} = 3'b100; {w1,w2,w3} = 3'b000;
        #50;
        `CHECK_MASK("JMP T1: LPC=1 SELCTL=1 SBUS=1", {LPC, SELCTL, SBUS}, 3'b111, 3);
        `CHECK_MASK("JMP: SHORT=1", {SHORT}, 1'b1, 1);

        // ============================================================
        // 测试 13: STP 指令（T1 时 STOP=1）
        // 意义：停机指令让 CPU 停止执行
        // ============================================================
        $display("--- 测试13: STP 指令 ---");
        set_inst("STP", 10'b10_0000_0000);

        {t1,t2,t3} = 3'b100;
        #50;
        `CHECK_MASK("STP T1: STOP=1", {STOP}, 1'b1, 1);

        {t1,t2,t3} = 3'b010;
        #50;
        `CHECK_MASK("STP T2: STOP=0", {STOP}, 1'b0, 1);

        // ============================================================
        // 测试 14: SHORT vs LONG 信号互斥
        // 意义：每条指令只能是短指令周期（算术/跳转）或长指令周期
        //       （访存），不能同时为 1。
        // ============================================================
        $display("--- 测试14: SHORT/LONG 互斥检查 ---");

        // ADD（短指令）
        set_inst("ADD", 10'b00_0000_0001);
        {t1,t2,t3} = 3'b100;
        #50;
        if (SHORT === 1'b1 && LONG_ === 1'b0) begin
            pass_cnt = pass_cnt + 1;
        end else begin
            fail_cnt = fail_cnt + 1;
            $display("  [FAIL] ADD: SHORT=%b LONG=%b (期望 1,0)", SHORT, LONG_);
        end
        total_checks = total_checks + 1;

        // LD（长指令）
        set_inst("LD", 10'b00_0001_0000);
        #50;
        if (LONG_ === 1'b1 && SHORT === 1'b0) begin
            pass_cnt = pass_cnt + 1;
        end else begin
            fail_cnt = fail_cnt + 1;
            $display("  [FAIL] LD: SHORT=%b LONG=%b (期望 0,1)", SHORT, LONG_);
        end
        total_checks = total_checks + 1;

        // ============================================================
        // 测试总结
        // ============================================================
        $display("");
        $display("============================================================");
        $display("  测试结果: 通过 %0d / 失败 %0d  (共 %0d 项检查)",
                 pass_cnt, fail_cnt, total_checks);
        if (fail_cnt == 0)
            $display("  结论: control_unit 全部测试通过! ✓");
        else
            $display("  结论: 存在 %0d 个失败用例，请检查控制逻辑 ✗", fail_cnt);
        $display("============================================================");

        $finish;
    end

endmodule
