// ============================================================
// 文件名: CPU.v  ——  TEC-8 模型机硬布线顺序控制器
// 所属项目: 题目A：基于 Altera EPM7128 的模型机系统控制器设计
// 平台: TEC-8 实验系统 + EPM7128SLC84-15
// 设计依据:
//   1. 第24页 — 指令集格式表
//   2. 第27页 — 输入输出接口定义
//   3. 第28-29页 — 基本时序波形
//   4. 第30页 — 硬布线控制器流程图
//   5. 引脚映射表（University Pin List）
//
// 设计说明:
//   - 纯组合逻辑控制器，CPLD 内部无时钟
//   - T3 仅用于 STO 内部寄存器的触发
//   - W1/W2/W3 由 TEC-8 平台时序发生器产生，直接输入
//   - 所有控制信号在组合逻辑中产生，使用完整赋值防 latch
// ============================================================

module CPU (

    // ============================
    // 输入信号（来自 TEC-8 平台）
    // ============================
    input  wire       CLR,        // 全局复位，低有效，pin 1
    input  wire       T3,         // 节拍脉冲 T3，pin 83
    input  wire       SWA,        // 模式选择开关 A，pin 4
    input  wire       SWB,        // 模式选择开关 B，pin 5
    input  wire       SWC,        // 模式选择开关 C，pin 6
    input  wire       IR4,        // 指令寄存器位 4，pin 8
    input  wire       IR5,        // 指令寄存器位 5，pin 9
    input  wire       IR6,        // 指令寄存器位 6，pin 10
    input  wire       IR7,        // 指令寄存器位 7，pin 11
    input  wire       W1,         // 写选通 1，pin 12
    input  wire       W2,         // 写选通 2，pin 15
    input  wire       W3,         // 写选通 3，pin 16
    input  wire       C,          // 进位标志，pin 2
    input  wire       Z,          // 零标志，pin 84

    // ============================
    // 输出信号（到 TEC-8 平台）
    // ============================
    // --- 控制信号 ---
    output reg        DRW,        // 数据寄存器写使能，pin 20
    output reg        PCINC,      // PC 加 1，pin 21
    output reg        LPC,        // PC 加载，pin 22
    output reg        LAR,        // AR 加载，pin 25
    output reg        PCADD,      // PC 加偏移量（跳转），pin 18
    output reg        ARINC,      // AR 地址寄存器加 1，pin 24
    output reg        MEMW,       // 存储器写使能，pin 27
    output reg        STOP,       // 停机信号，pin 28
    output reg        LIR,        // IR 加载，pin 29
    output reg        LDZ,        // Z 标志寄存器加载，pin 30
    output reg        LDC,        // C 标志寄存器加载，pin 31
    output reg        CIN,        // ALU 进位输入，pin 33

    // --- ALU 控制 ---
    output reg        S0,         // ALU 选择位 0，pin 34
    output reg        S1,         // ALU 选择位 1，pin 35
    output reg        S2,         // ALU 选择位 2，pin 36
    output reg        S3,         // ALU 选择位 3，pin 37
    output reg        M,          // ALU 算术/逻辑选择，pin 39

    // --- 总线控制 ---
    output reg        ABUS,       // A 总线使能，pin 40
    output reg        SBUS,       // S 总线使能，pin 41
    output reg        MBUS,       // M 总线使能，pin 44

    // --- 时序控制 ---
    output reg        SHORT,      // 短指令周期（跳过 W2），pin 45
    output reg        LONG,       // 长指令周期（插入 W3），pin 46

    // --- 寄存器选择器 ---
    output reg        SEL0,       // 选择器位 0，pin 48
    output reg        SEL1,       // 选择器位 1，pin 49
    output reg        SEL2,       // 选择器位 2，pin 50
    output reg        SEL3,       // 选择器位 3，pin 51

    // --- 选择器控制 ---
    output reg        SELCTL      // 选择器总控制，pin 52
);

    // ============================
    // 内部信号定义
    // ============================

    // 指令操作码（IR7-IR4）
    wire [3:0] opcode = {IR7, IR6, IR5, IR4};

    // 模式选择开关
    wire [2:0] SW = {SWC, SWB, SWA};

    // STO：内部状态寄存器
    // 功能：区分"首次进入"与"再次进入"同一 SW 模式
    //       CLR# 后 STO=0；SSTO=1 时 STO 变为 1
    reg  STO;
    reg  SSTO;  // 设置 STO=1 的内部信号（在组合逻辑中赋值）

    // STO 时序逻辑：在 T3 下降沿更新（与 W 信号切换同步）
    always @(negedge T3 or negedge CLR) begin
        if (!CLR)
            STO <= 1'b0;
        else if (SSTO)
            STO <= 1'b1;
    end

    // ============================
    // 控制信号组合逻辑（核心）
    //
    // 全部控制信号在 always @(*) 中产生，为纯组合逻辑
    // 每个信号在所有分支中都有赋值，防止生成锁存器
    // ============================

    always @(*) begin
        // ---- 第一步：所有输出清零 ----
        // 这是防止 latch 的关键写法
        MEMW  = 1'b0;
        STOP  = 1'b0;
        LIR   = 1'b0;
        LDZ   = 1'b0;
        LDC   = 1'b0;
        CIN   = 1'b0;
        S0    = 1'b0;
        S1    = 1'b0;
        S2    = 1'b0;
        S3    = 1'b0;
        M     = 1'b0;
        ABUS  = 1'b0;
        SBUS  = 1'b0;
        MBUS  = 1'b0;
        DRW   = 1'b0;
        PCINC = 1'b0;
        LPC   = 1'b0;
        LAR   = 1'b0;
        PCADD = 1'b0;
        ARINC = 1'b0;
        SELCTL= 1'b0;
        SHORT = 1'b0;
        LONG  = 1'b0;
        SEL0  = 1'b0;
        SEL1  = 1'b0;
        SEL2  = 1'b0;
        SEL3  = 1'b0;
        SSTO  = 1'b0;

        // ============================
        // 第 一 大 区 域：W1 阶 段
        // 根据 SWC/SWB/SWA 模式选择执行
        // ============================

        if (W1) begin
            case (SW)
                // ---- 000：取指模式 ----
                3'b000: begin
                    LIR   = 1'b1;   // 指令寄存器加载（取指令）
                    PCINC = 1'b1;   // PC 自增（指向下一条）
                end

                // ---- 100：写寄存器模式 ----
                3'b100: begin
                    // 通过 STO 选择两组寄存器组
                    if (!STO) begin
                        // ST0=0 组：写 R0
                        SEL3  = 1'b0;
                        SEL2  = 1'b0;
                        SEL1  = 1'b1;
                        SEL0  = 1'b1;   // SEL=0011
                        SBUS  = 1'b1;
                        SELCTL= 1'b1;
                        DRW   = 1'b1;
                        STOP  = 1'b1;
                    end else begin
                        // ST0=1 组：写 R2
                        SEL3  = 1'b1;
                        SEL2  = 1'b0;
                        SEL1  = 1'b0;
                        SEL0  = 1'b1;   // SEL=1001
                        SBUS  = 1'b1;
                        SELCTL= 1'b1;
                        DRW   = 1'b1;
                        STOP  = 1'b1;
                    end
                end

                // ---- 011：读寄存器模式 ----
                3'b011: begin
                    SEL3  = 1'b0;
                    SEL2  = 1'b0;
                    SEL1  = 1'b0;
                    SEL0  = 1'b1;   // SEL=0001
                    SELCTL= 1'b1;
                    STOP  = 1'b1;
                end

                // ---- 010：读存储器模式 ----
                3'b010: begin
                    if (!STO) begin
                        // ST0=0 组：设置地址
                        SBUS  = 1'b1;
                        LAR   = 1'b1;
                        STOP  = 1'b1;
                        SHORT = 1'b1;   // 跳过 W2
                        SELCTL= 1'b1;
                        SSTO  = 1'b1;   // 本周期结束后 STO 变为 1
                    end else begin
                        // ST0=1 组：读取数据到 MBUS，地址自增
                        MBUS  = 1'b1;
                        ARINC = 1'b1;
                        STOP  = 1'b1;
                        SHORT = 1'b1;   // 跳过 W2
                        SELCTL= 1'b1;
                    end
                end

                // ---- 001：写存储器模式 ----
                3'b001: begin
                    if (!STO) begin
                        // ST0=0 组：设置地址
                        SBUS  = 1'b1;
                        LAR   = 1'b1;
                        STOP  = 1'b1;
                        SHORT = 1'b1;   // 跳过 W2
                        SELCTL= 1'b1;
                        SSTO  = 1'b1;   // 本周期结束后 STO 变为 1
                    end else begin
                        // ST0=1 组：写入数据，地址自增
                        SBUS  = 1'b1;
                        MEMW  = 1'b1;
                        ARINC = 1'b1;
                        STOP  = 1'b1;
                        SHORT = 1'b1;   // 跳过 W2
                        SELCTL= 1'b1;
                    end
                end

                default: ;
            endcase
        end

        // ============================
        // 第 二 大 区 域：W2 阶 段
        // 根据 SWC/SWB/SWA 模式选择执行
        // 当 SW=000 时进入 IR7-IR4 译码区
        // ============================

        if (W2) begin
            case (SW)
                // ---- 000：指令译码执行 ----
                // 进入 IR7-IR4 译码区
                3'b000: begin
                    case (opcode)
                        // 0001 - ADD Rd, Rs：加法运算
                        4'b0001: begin
                            S3    = 1'b1;
                            S2    = 1'b0;
                            S1    = 1'b0;
                            S0    = 1'b1;   // S=1001 (A+B)
                            CIN   = 1'b0;   // 加法：进位输入为 0
                            ABUS  = 1'b1;
                            DRW   = 1'b1;
                            LDZ   = 1'b1;   // 更新零标志
                            LDC   = 1'b1;   // 更新进位标志
                        end

                        // 0010 - SUB Rd, Rs：减法运算
                        4'b0010: begin
                            S3    = 1'b0;
                            S2    = 1'b1;
                            S1    = 1'b1;
                            S0    = 1'b0;   // S=0110 (A-B)
                            ABUS  = 1'b1;
                            DRW   = 1'b1;
                            LDZ   = 1'b1;
                            LDC   = 1'b1;
                        end

                        // 0011 - AND Rd, Rs：逻辑与运算
                        4'b0011: begin
                            M     = 1'b1;   // 逻辑运算模式
                            S3    = 1'b1;
                            S2    = 1'b0;
                            S1    = 1'b1;
                            S0    = 1'b1;   // S=1011 (A AND B)
                            ABUS  = 1'b1;
                            DRW   = 1'b1;
                            LDZ   = 1'b1;
                            // 不更新 LDC（逻辑运算不影响进位）
                        end

                        // 0100 - INC Rd：自增 1
                        4'b0100: begin
                            S3    = 1'b0;
                            S2    = 1'b0;
                            S1    = 1'b0;
                            S0    = 1'b0;   // S=0000 (A 加 0 带进位)
                            ABUS  = 1'b1;
                            DRW   = 1'b1;
                            LDZ   = 1'b1;
                            LDC   = 1'b1;
                        end

                        // 0101 - LD Rd, [Rs]：从内存加载到寄存器
                        4'b0101: begin
                            M     = 1'b1;
                            S3    = 1'b1;
                            S2    = 1'b0;
                            S1    = 1'b1;
                            S0    = 1'b0;   // S=1010
                            ABUS  = 1'b1;
                            LAR   = 1'b1;   // 加载地址寄存器
                            LONG  = 1'b1;   // 需要 W3 写回周期
                        end

                        // 0110 - ST Rs, [Rd]：从寄存器存入内存
                        4'b0110: begin
                            M     = 1'b1;
                            S3    = 1'b1;
                            S2    = 1'b1;
                            S1    = 1'b1;
                            S0    = 1'b1;   // S=1111
                            ABUS  = 1'b1;
                            LAR   = 1'b1;   // 加载地址寄存器
                            LONG  = 1'b1;   // 需要 W3 写回周期
                        end

                        // 0111 - JC addr：有进位时跳转
                        4'b0111: begin
                            if (C)
                                PCADD = 1'b1;  // C=1：PC 加偏移量（跳转）
                            // C=0：空操作，继续下一条
                        end

                        // 1000 - JZ addr：为零时跳转
                        4'b1000: begin
                            if (Z)
                                PCADD = 1'b1;  // Z=1：PC 加偏移量（跳转）
                            // Z=0：空操作，继续下一条
                        end

                        // 1001 - JMP [Rd]：无条件跳转
                        4'b1001: begin
                            M     = 1'b1;
                            S3    = 1'b1;
                            S2    = 1'b1;
                            S1    = 1'b1;
                            S0    = 1'b1;   // S=1111（传递 Rd 到总线）
                            ABUS  = 1'b1;
                            LPC   = 1'b1;   // 加载 PC 为新地址
                        end

                        // 1010 - OUT Rs：输出到显示
                        // 注：使用 ST 指令的 S 控制信号模板
                        // TODO: 后续根据实际显示需求调整精确信号组合
                        4'b1010: begin
                            M     = 1'b1;
                            S3    = 1'b1;
                            S2    = 1'b1;
                            S1    = 1'b1;
                            S0    = 1'b1;   // S=1111（传递 Rs 到总线）
                            ABUS  = 1'b1;
                            SBUS  = 1'b1;   // 将数据放到总线上供显示
                            // 与 ST 的区别：无 LAR、无 LONG、无 MEMW
                            // 后续修改参考：若显示异常，尝试调整 S 编码或增加总线使能
                        end

                        // 1110 - STP：停机
                        4'b1110: begin
                            STOP  = 1'b1;
                        end

                        default: ;
                    endcase
                end

                // ---- 100：写寄存器模式（W2 层）----
                3'b100: begin
                    if (!STO) begin
                        // ST0=0 组：写 R1
                        SEL3  = 1'b0;
                        SEL2  = 1'b1;
                        SEL1  = 1'b0;
                        SEL0  = 1'b0;   // SEL=0100
                        SBUS  = 1'b1;
                        SELCTL= 1'b1;
                        DRW   = 1'b1;
                        STOP  = 1'b1;
                        SSTO  = 1'b1;   // 本周期结束后 STO 变为 1
                    end else begin
                        // ST0=1 组：写 R3
                        SEL3  = 1'b1;
                        SEL2  = 1'b1;
                        SEL1  = 1'b1;
                        SEL0  = 1'b0;   // SEL=1110
                        SBUS  = 1'b1;
                        SELCTL= 1'b1;
                        DRW   = 1'b1;
                        STOP  = 1'b1;
                    end
                end

                // ---- 011：读寄存器模式（W2 层）----
                3'b011: begin
                    SEL3  = 1'b1;
                    SEL2  = 1'b0;
                    SEL1  = 1'b1;
                    SEL0  = 1'b1;   // SEL=1011
                    SELCTL= 1'b1;
                    STOP  = 1'b1;
                end

                // ---- 010：读存储器（W2 无操作）----
                // 已在 W1 中通过 SHORT 跳过 W2

                // ---- 001：写存储器（W2 无操作）----
                // 已在 W1 中通过 SHORT 跳过 W2

                default: ;
            endcase
        end

        // ============================
        // 第 三 大 区 域：W3 阶 段
        // LD 和 ST 指令的写回操作
        // 仅在 LONG 信号触发后才会有 W3 周期
        // ============================

        if (W3) begin
            case (opcode)
                // 0101 - LD：将内存读出的数据写入寄存器
                4'b0101: begin
                    DRW  = 1'b1;    // 数据寄存器写使能
                    MBUS = 1'b1;    // 内存数据总线使能
                end

                // 0110 - ST：将数据写入内存
                4'b0110: begin
                    M     = 1'b1;
                    S3    = 1'b1;
                    S2    = 1'b0;
                    S1    = 1'b1;
                    S0    = 1'b0;   // S=1010
                    ABUS  = 1'b1;
                    MEMW  = 1'b1;   // 存储器写使能
                end

                default: ;
            endcase
        end
    end

endmodule
