// ============================================================
// 文件名: tb_cpu.v  ——  TEC-8 硬布线控制器 Testbench
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
        all_pass = 1; tc = 0;
        CLR = 0; {W1,W2,W3} = 0; T3 = 0;
        {SWC,SWB,SWA} = 0; {IR7,IR6,IR5,IR4} = 0;
        C = 0; Z = 0;
        #20 CLR = 1; #10;
        $display("=== TEC-8 CPU Testbench ===");

        // Test 1: 取指 W1+SW=000 → LIR, PCINC
        {SWC,SWB,SWA}=3'b000; W1=1; W2=0; W3=0;
        check(1, 0,1,0,0, 0,0,0,0, 1,0,0,0, 0,0,0,0,0, 0,0,0, 0,0, 0,0,0,0,0);
        W1=0;

        // Test 2: ADD W2+IR=0001 → S=1001,CIN,ABUS,DRW,LDZ,LDC
        {SWC,SWB,SWA}=3'b000; {IR7,IR6,IR5,IR4}=4'b0001; W2=1;
        check(2, 1,0,0,0, 0,0,0,0, 0,1,1,1, 1,0,0,1,0, 1,0,0, 0,0, 0,0,0,0,0);
        W2=0;

        // Test 3: SUB W2+IR=0010 → S=0110,ABUS,DRW,LDZ,LDC
        {IR7,IR6,IR5,IR4}=4'b0010; W2=1;
        check(3, 1,0,0,0, 0,0,0,0, 0,1,1,0, 0,1,1,0,0, 1,0,0, 0,0, 0,0,0,0,0);
        W2=0;

        // Test 4: JC+C=1 W2+IR=0111 → PCADD
        {IR7,IR6,IR5,IR4}=4'b0111; C=1; W2=1;
        check(4, 0,0,0,0, 1,0,0,0, 0,0,0,0, 0,0,0,0,0, 0,0,0, 0,0, 0,0,0,0,0);
        W2=0;

        // Test 5: JC+C=0 → 全零
        C=0; W2=1;
        check(5, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0,0, 0,0,0, 0,0, 0,0,0,0,0);
        W2=0;

        // Test 6: STP W2+IR=1110 → STOP
        {IR7,IR6,IR5,IR4}=4'b1110; W2=1;
        check(6, 0,0,0,0, 0,0,0,1, 0,0,0,0, 0,0,0,0,0, 0,0,0, 0,0, 0,0,0,0,0);
        W2=0;

        // Test 7: LD W2+IR=0101 → S=1010(S0=0,S1=1,S2=0,S3=1),ABUS,LAR,LONG
        {IR7,IR6,IR5,IR4}=4'b0101; W2=1;
        check(7, 0,0,0,1, 0,0,0,0, 0,0,0,0, 0,1,0,1,1, 1,0,0, 0,1, 0,0,0,0,0);
        W2=0;

        // Test 8: LD W3 → DRW,MBUS
        W3=1;
        check(8, 1,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0,0, 0,0,1, 0,0, 0,0,0,0,0);
        W3=0;

        // Test 9: OUT W2+IR=1010 → S=1111,ABUS,SBUS
        {IR7,IR6,IR5,IR4}=4'b1010; W2=1;
        check(9, 0,0,0,0, 0,0,0,0, 0,0,0,0, 1,1,1,1,1, 1,1,0, 0,0, 0,0,0,0,0);
        W2=0;

        // Test 10: 写寄存器 W1+SW=100 → SEL=0011(SEL0=1,SEL1=1,SEL2=0,SEL3=0),SBUS,SELCTL,DRW,STOP
        {SWC,SWB,SWA}=3'b100; W1=1;
        check(10, 1,0,0,0, 0,0,0,1, 0,0,0,0, 0,0,0,0,0, 0,1,0, 0,0, 1,1,0,0,1);
        W1=0;

        // Test 11: 读存储器 W1+SW=010 → SBUS,LAR,STOP,SHORT,SELCTL
        {SWC,SWB,SWA}=3'b010; W1=1;
        check(11, 0,0,0,1, 0,0,0,1, 0,0,0,0, 0,0,0,0,0, 0,1,0, 1,0, 0,0,0,0,1);
        W1=0;

        $display("");
        $display("Tests: %0d", tc);
        if (all_pass) $display("ALL PASS");
        else          $display("SOME FAILED");
        $finish;
    end

endmodule
