// ============================================================
// 文件名: tb_cpu.v  ——  TEC-8 硬布线控制器 Testbench
// 被测模块: phase1/CPU.v
// ============================================================
`timescale 1ns / 100ps

module tb_cpu;

    reg  CLR, T3, SWA, SWB, SWC;
    reg  IR4, IR5, IR6, IR7;
    reg  W1, W2, W3, C, Z;

    wire DRW, PCINC, LPC, LAR, PCADD, ARINC;
    wire MEMW, STOP, LIR, LDZ, LDC, CIN;
    wire S0, S1, S2, S3, M;
    wire ABUS, SBUS, MBUS;
    wire SHORT, LONG;
    wire SEL0, SEL1, SEL2, SEL3, SELCTL;

    CPU uut (
        .CLR(CLR), .T3(T3),
        .SWA(SWA), .SWB(SWB), .SWC(SWC),
        .IR4(IR4), .IR5(IR5), .IR6(IR6), .IR7(IR7),
        .W1(W1), .W2(W2), .W3(W3), .C(C), .Z(Z),
        .DRW(DRW), .PCINC(PCINC), .LPC(LPC), .LAR(LAR),
        .PCADD(PCADD), .ARINC(ARINC),
        .MEMW(MEMW), .STOP(STOP), .LIR(LIR),
        .LDZ(LDZ), .LDC(LDC), .CIN(CIN),
        .S0(S0), .S1(S1), .S2(S2), .S3(S3), .M(M),
        .ABUS(ABUS), .SBUS(SBUS), .MBUS(MBUS),
        .SHORT(SHORT), .LONG(LONG),
        .SEL0(SEL0), .SEL1(SEL1), .SEL2(SEL2), .SEL3(SEL3),
        .SELCTL(SELCTL)
    );

    reg all_pass;
    integer tc;

    task idle_inputs;
        begin
            {W1, W2, W3} = 3'b000;
            {SWC, SWB, SWA} = 3'b000;
            {IR7, IR6, IR5, IR4} = 4'b0000;
            C = 0;
            Z = 0;
        end
    endtask

    task cpu_reset;
        begin
            idle_inputs();
            CLR = 0;
            T3  = 0;
            #20;
            CLR = 1;
            #10;
        end
    endtask

    // STO 在 T3 下降沿更新
    task pulse_t3;
        begin
            T3 = 1;
            #10;
            T3 = 0;
            #10;
        end
    endtask

    task check;
        input [7:0] tcn;
        input eDRW, ePCINC, eLPC, eLAR;
        input ePCADD, eARINC, eMEMW, eSTOP;
        input eLIR, eLDZ, eLDC, eCIN;
        input eS0, eS1, eS2, eS3, eM;
        input eABUS, eSBUS, eMBUS;
        input eSHORT, eLONG;
        input eSEL0, eSEL1, eSEL2, eSEL3, eSELCTL;
        begin
            tc = tc + 1;
            #10;
            if (DRW!==eDRW || PCINC!==ePCINC || LPC!==eLPC || LAR!==eLAR ||
                PCADD!==ePCADD || ARINC!==eARINC || MEMW!==eMEMW || STOP!==eSTOP ||
                LIR!==eLIR || LDZ!==eLDZ || LDC!==eLDC || CIN!==eCIN ||
                S0!==eS0 || S1!==eS1 || S2!==eS2 || S3!==eS3 || M!==eM ||
                ABUS!==eABUS || SBUS!==eSBUS || MBUS!==eMBUS ||
                SHORT!==eSHORT || LONG!==eLONG ||
                SEL0!==eSEL0 || SEL1!==eSEL1 || SEL2!==eSEL2 ||
                SEL3!==eSEL3 || SELCTL!==eSELCTL) begin
                $display("FAIL: Test %0d", tcn);
                all_pass = 0;
            end else begin
                $display("PASS: Test %0d", tcn);
            end
        end
    endtask

    initial begin
        all_pass = 1;
        tc = 0;
        cpu_reset();
        $display("=== TEC-8 CPU Testbench (phase1/CPU.v) ===");
        $display("");

        // ============================================================
        // 组 A: 基础状态
        // ============================================================
        $display("--- Group A: 基础状态 ---");

        // Test 1: 空闲态，所有输出为 0
        idle_inputs();
        check(1, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0,0, 0,0,0, 0,0, 0,0,0,0,0);

        // Test 2: 取指 W1 + SW=000 → LIR, PCINC
        {SWC, SWB, SWA} = 3'b000;
        W1 = 1;
        check(2, 0,1,0,0, 0,0,0,0, 1,0,0,0, 0,0,0,0,0, 0,0,0, 0,0, 0,0,0,0,0);
        W1 = 0;

        // Test 3: 非法操作码 0000，W2 无输出
        {SWC, SWB, SWA} = 3'b000;
        {IR7, IR6, IR5, IR4} = 4'b0000;
        W2 = 1;
        check(3, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0,0, 0,0,0, 0,0, 0,0,0,0,0);
        W2 = 0;

        // ============================================================
        // 组 B: 算术 / 逻辑指令 (W2, SW=000)
        // ============================================================
        $display("");
        $display("--- Group B: 算术/逻辑指令 ---");

        // Test 4: ADD 0001 → S=1001, CIN, ABUS, DRW, LDZ, LDC
        {SWC, SWB, SWA} = 3'b000;
        {IR7, IR6, IR5, IR4} = 4'b0001;
        W2 = 1;
        check(4, 1,0,0,0, 0,0,0,0, 0,1,1,1, 1,0,0,1,0, 1,0,0, 0,0, 0,0,0,0,0);
        W2 = 0;

        // Test 5: SUB 0010 → S=0110, ABUS, DRW, LDZ, LDC
        {IR7, IR6, IR5, IR4} = 4'b0010;
        W2 = 1;
        check(5, 1,0,0,0, 0,0,0,0, 0,1,1,0, 0,1,1,0,0, 1,0,0, 0,0, 0,0,0,0,0);
        W2 = 0;

        // Test 6: AND 0011 → M=1, S=1011, ABUS, DRW, LDZ (无 LDC/CIN)
        {IR7, IR6, IR5, IR4} = 4'b0011;
        W2 = 1;
        check(6, 1,0,0,0, 0,0,0,0, 0,1,0,0, 1,1,0,1,1, 1,0,0, 0,0, 0,0,0,0,0);
        W2 = 0;

        // Test 7: INC 0100 → S=0000, ABUS, DRW, LDZ, LDC
        {IR7, IR6, IR5, IR4} = 4'b0100;
        W2 = 1;
        check(7, 1,0,0,0, 0,0,0,0, 0,1,1,0, 0,0,0,0,0, 1,0,0, 0,0, 0,0,0,0,0);
        W2 = 0;

        // ============================================================
        // 组 C: 访存指令 LD / ST (W2 + W3)
        // ============================================================
        $display("");
        $display("--- Group C: 访存指令 ---");

        // Test 8: LD W2 0101 → S=1010, ABUS, LAR, LONG
        {IR7, IR6, IR5, IR4} = 4'b0101;
        W2 = 1;
        check(8, 0,0,0,1, 0,0,0,0, 0,0,0,0, 0,1,0,1,1, 1,0,0, 0,1, 0,0,0,0,0);
        W2 = 0;

        // Test 9: LD W3 0101 → DRW, MBUS
        W3 = 1;
        check(9, 1,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0,0, 0,0,1, 0,0, 0,0,0,0,0);
        W3 = 0;

        // Test 10: ST W2 0110 → S=1111, ABUS, LAR, LONG
        {IR7, IR6, IR5, IR4} = 4'b0110;
        W2 = 1;
        check(10, 0,0,0,1, 0,0,0,0, 0,0,0,0, 1,1,1,1,1, 1,0,0, 0,1, 0,0,0,0,0);
        W2 = 0;

        // Test 11: ST W3 0110 → S=1010, ABUS, MEMW
        W3 = 1;
        check(11, 0,0,0,0, 0,0,1,0, 0,0,0,0, 0,1,0,1,1, 1,0,0, 0,0, 0,0,0,0,0);
        W3 = 0;

        // ============================================================
        // 组 D: 跳转 / 停机 / 输出指令
        // ============================================================
        $display("");
        $display("--- Group D: 跳转/停机/输出 ---");

        // Test 12: JC 0111, C=1 → PCADD
        {IR7, IR6, IR5, IR4} = 4'b0111;
        C = 1;
        W2 = 1;
        check(12, 0,0,0,0, 1,0,0,0, 0,0,0,0, 0,0,0,0,0, 0,0,0, 0,0, 0,0,0,0,0);
        W2 = 0;

        // Test 13: JC 0111, C=0 → 空操作
        C = 0;
        W2 = 1;
        check(13, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0,0, 0,0,0, 0,0, 0,0,0,0,0);
        W2 = 0;

        // Test 14: JZ 1000, Z=1 → PCADD
        {IR7, IR6, IR5, IR4} = 4'b1000;
        Z = 1;
        W2 = 1;
        check(14, 0,0,0,0, 1,0,0,0, 0,0,0,0, 0,0,0,0,0, 0,0,0, 0,0, 0,0,0,0,0);
        W2 = 0;

        // Test 15: JZ 1000, Z=0 → 空操作
        Z = 0;
        W2 = 1;
        check(15, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0,0, 0,0,0, 0,0, 0,0,0,0,0);
        W2 = 0;

        // Test 16: JMP 1001 → S=1111, ABUS, LPC
        {IR7, IR6, IR5, IR4} = 4'b1001;
        W2 = 1;
        check(16, 0,0,1,0, 0,0,0,0, 0,0,0,0, 1,1,1,1,1, 1,0,0, 0,0, 0,0,0,0,0);
        W2 = 0;

        // Test 17: OUT 1010 → S=1111, ABUS, SBUS
        {IR7, IR6, IR5, IR4} = 4'b1010;
        W2 = 1;
        check(17, 0,0,0,0, 0,0,0,0, 0,0,0,0, 1,1,1,1,1, 1,1,0, 0,0, 0,0,0,0,0);
        W2 = 0;

        // Test 18: STP 1110 → STOP
        {IR7, IR6, IR5, IR4} = 4'b1110;
        W2 = 1;
        check(18, 0,0,0,0, 0,0,0,1, 0,0,0,0, 0,0,0,0,0, 0,0,0, 0,0, 0,0,0,0,0);
        W2 = 0;

        // ============================================================
        // 组 E: 手动写寄存器 (SW=100, STO 状态机)
        // ============================================================
        $display("");
        $display("--- Group E: 手动写寄存器 SW=100 ---");
        cpu_reset();

        // Test 19: W1, STO=0 → 写 R0, SEL=0011
        {SWC, SWB, SWA} = 3'b100;
        W1 = 1;
        check(19, 1,0,0,0, 0,0,0,1, 0,0,0,0, 0,0,0,0,0, 0,1,0, 0,0, 1,1,0,0,1);
        W1 = 0;

        // Test 20: W2, STO=0 → 写 R1, SEL=0100, SSTO 置位
        W2 = 1;
        check(20, 1,0,0,0, 0,0,0,1, 0,0,0,0, 0,0,0,0,0, 0,1,0, 0,0, 0,1,0,0,1);
        W2 = 0;
        pulse_t3();

        // Test 21: W1, STO=1 → 写 R2, SEL=1001
        W1 = 1;
        check(21, 1,0,0,0, 0,0,0,1, 0,0,0,0, 0,0,0,0,0, 0,1,0, 0,0, 1,0,0,1,1);
        W1 = 0;

        // Test 22: W2, STO=1 → 写 R3, SEL=1110
        W2 = 1;
        check(22, 1,0,0,0, 0,0,0,1, 0,0,0,0, 0,0,0,0,0, 0,1,0, 0,0, 0,1,1,1,1);
        W2 = 0;

        // ============================================================
        // 组 F: 手动读寄存器 (SW=011)
        // ============================================================
        $display("");
        $display("--- Group F: 手动读寄存器 SW=011 ---");
        cpu_reset();

        // Test 23: W1 → SEL=0001
        {SWC, SWB, SWA} = 3'b011;
        W1 = 1;
        check(23, 0,0,0,0, 0,0,0,1, 0,0,0,0, 0,0,0,0,0, 0,0,0, 0,0, 1,0,0,0,1);
        W1 = 0;

        // Test 24: W2 → SEL=1011
        W2 = 1;
        check(24, 0,0,0,0, 0,0,0,1, 0,0,0,0, 0,0,0,0,0, 0,0,0, 0,0, 1,1,0,1,1);
        W2 = 0;

        // ============================================================
        // 组 G: 手动读存储器 (SW=010, STO 两阶段)
        // ============================================================
        $display("");
        $display("--- Group G: 手动读存储器 SW=010 ---");
        cpu_reset();

        // Test 25: W1, STO=0 → 设地址
        {SWC, SWB, SWA} = 3'b010;
        W1 = 1;
        check(25, 0,0,0,1, 0,0,0,1, 0,0,0,0, 0,0,0,0,0, 0,1,0, 1,0, 0,0,0,0,1);
        W1 = 0;
        pulse_t3();

        // Test 26: W1, STO=1 → 读数据, ARINC
        W1 = 1;
        check(26, 0,0,0,0, 0,1,0,1, 0,0,0,0, 0,0,0,0,0, 0,0,1, 1,0, 0,0,0,0,1);
        W1 = 0;

        // ============================================================
        // 组 H: 手动写存储器 (SW=001, STO 两阶段)
        // ============================================================
        $display("");
        $display("--- Group H: 手动写存储器 SW=001 ---");
        cpu_reset();

        // Test 27: W1, STO=0 → 设地址
        {SWC, SWB, SWA} = 3'b001;
        W1 = 1;
        check(27, 0,0,0,1, 0,0,0,1, 0,0,0,0, 0,0,0,0,0, 0,1,0, 1,0, 0,0,0,0,1);
        W1 = 0;
        pulse_t3();

        // Test 28: W1, STO=1 → 写数据, MEMW, ARINC
        W1 = 1;
        check(28, 0,0,0,0, 0,1,1,1, 0,0,0,0, 0,0,0,0,0, 0,0,0, 1,0, 0,0,0,0,1);
        W1 = 0;

        // ============================================================
        // 汇总
        // ============================================================
        $display("");
        $display("Tests: %0d", tc);
        if (all_pass) $display("ALL PASS");
        else          $display("SOME FAILED");
        $finish;
    end

endmodule
