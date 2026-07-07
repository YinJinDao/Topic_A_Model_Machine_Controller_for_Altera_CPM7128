// ============================================================
// 文件名: CPU.v  ——  TEC-8 模型机控制器顶层模块
// 所属项目: TEC-8 模型机控制器（题目A）
// 芯片: Altera EPM7128SLC84-15
//
// 功能描述:
//   顶层模块，例化所有子模块并完成连线：
//     - timing_gen (角色A): 时序发生器
//     - instruction_decoder (角色A): 指令译码器
//     - alu_control (角色A): ALU控制接口
//     - control_unit (角色B): 核心控制信号生成
//     - regfile_control (角色B): 寄存器组控制
//
// 模块层级关系:
//   CPU (顶层)
//   ├── timing_gen         → 产生 t1/t2/t3/w1/w2/w3
//   ├── instruction_decoder → 将 IR[7:4] 译码为指令标识
//   ├── alu_control         → 产生 ALU 级控制信号
//   ├── control_unit        → 产生全部 TEC-8 控制信号
//   └── regfile_control     → 产生寄存器读写选择信号
// ============================================================

module CPU (
    // ================================================================
    // 时钟与复位
    // ================================================================
    input  wire       clk,          // MF 主时钟 (1μs 周期方波)
    input  wire       clr_n,        // 全局复位，低有效

    // ================================================================
    // 外部输入信号（来自 TEC-8 实验箱 / 外部电路）
    // ================================================================
    input  wire       t3_in,        // T3 输入
    input  wire       swa,          // 拨码开关 SWA
    input  wire       swb,          // 拨码开关 SWB
    input  wire       swc,          // 拨码开关 SWC

    input  wire       ir4,          // 指令寄存器 IR7-IR4
    input  wire       ir5,
    input  wire       ir6,
    input  wire       ir7,

    input  wire       ir0,          // 指令寄存器 IR3-IR0（供 regfile_control 使用）
    input  wire       ir1,
    input  wire       ir2,
    input  wire       ir3,

    input  wire       w1_in,        // 写选通输入
    input  wire       w2_in,
    input  wire       w3_in,

    input  wire       s0_in,        // 状态输入
    input  wire       s1_in,
    input  wire       s2_in,
    input  wire       s3_in,

    input  wire       m_in,         // M 输入
    input  wire       c_in,         // 进位标志输入
    input  wire       z_in,         // 零标志输入

    // ================================================================
    // TEC-8 控制信号输出（来自 control_unit，角色B）
    // ================================================================
    output wire       ARINC,        // AR 地址寄存器加 1
    output wire       CIN,          // ALU 进位输入控制
    output wire       DRW,          // 数据寄存器写使能
    output wire       LPC,          // PC 加载
    output wire       LAR,          // AR 加载
    output wire       LIR,          // IR 加载
    output wire       LDZ,          // Z 标志加载
    output wire       LDC,          // C 标志加载
    output wire       PCINC,        // PC 加 1
    output wire       PCADD,        // PC 加偏移量
    output wire       SELCTL,       // 选择器控制
    output wire       M,            // 存储器模式
    output wire       MEMW,         // 存储器写使能
    output wire       STOP,         // 停机信号
    output wire       SHORT,        // 短指令周期
    output wire       LONG_,        // 长指令周期（_ 后缀避免与 Verilog 关键字冲突）
    output wire       ABUS,         // A 总线使能
    output wire       SBUS,         // S 总线使能
    output wire       MBUS,         // M 总线使能
    output wire       SST0,         // SST0 状态位
    output wire [1:0] S,            // 状态位 [S1, S0]
    output wire [1:0] SEL,          // 选择器 [SEL1, SEL0]

    // ================================================================
    // 寄存器组控制输出（来自 regfile_control，角色B）
    // ================================================================
    output wire       lr0,          // R0 寄存器加载使能
    output wire       lr1,          // R1 寄存器加载使能
    output wire       lr2,          // R2 寄存器加载使能
    output wire       lr3,          // R3 寄存器加载使能
    output wire       rs0,          // 源寄存器选择低位
    output wire       rs1,          // 源寄存器选择高位
    output wire       rd0,          // 目标寄存器选择低位
    output wire       rd1,          // 目标寄存器选择高位
    output wire       s0,           // 寄存器选择器控制 S0
    output wire       s1,           // 寄存器选择器控制 S1
    output wire       s2,           // 寄存器选择器控制 S2
    output wire       s3,           // 寄存器选择器控制 S3

    // ================================================================
    // ALU 控制输出（来自 alu_control，角色A）
    // 注意：这些信号由 alu_control 产生，与 control_unit 的 CIN/LDZ/LDC
    //       是独立的信号路径。实际使用时选择其中一组即可。
    // ================================================================
    output wire       alu_cin,      // ALU 进位输入（来自 alu_control）
    output wire       alu_ldz,      // Z 标志加载（来自 alu_control）
    output wire       alu_ldc       // C 标志加载（来自 alu_control）
);

    // ================================================================
    // 内部连线
    // ================================================================

    // --- 时序信号（timing_gen → 各模块）---
    wire        t1, t2, t3;
    wire        w1, w2, w3;

    // --- 指令译码信号（instruction_decoder → control_unit / alu_control）---
    wire        is_add, is_sub, is_and, is_inc;
    wire        is_ld, is_st, is_jc, is_jz, is_jmp, is_stp;

    // --- 组合 IR 总线 ---
    wire [3:0]  ir_high;   // IR[7:4] 操作码
    wire [7:0]  ir_full;   // IR[7:0] 完整指令

    assign ir_high = {ir7, ir6, ir5, ir4};
    assign ir_full = {ir7, ir6, ir5, ir4, ir3, ir2, ir1, ir0};

    // --- 拨码开关总线 ---
    wire [2:0]  sw;
    assign sw = {swc, swb, swa};


    // ================================================================
    // 模块一：timing_gen — 时序发生器（角色A）
    // ================================================================
    timing_gen u_timing_gen (
        .clk     (clk),
        .reset_n (clr_n),
        .t1      (t1),
        .t2      (t2),
        .t3      (t3),
        .w1      (w1),
        .w2      (w2),
        .w3      (w3)
    );


    // ================================================================
    // 模块二：instruction_decoder — 指令译码器（角色A）
    // ================================================================
    instruction_decoder u_instruction_decoder (
        .ir      (ir_high),       // IR[7:4] 操作码
        .is_add  (is_add),
        .is_sub  (is_sub),
        .is_and  (is_and),
        .is_inc  (is_inc),
        .is_ld   (is_ld),
        .is_st   (is_st),
        .is_jc   (is_jc),
        .is_jz   (is_jz),
        .is_jmp  (is_jmp),
        .is_stp  (is_stp)
    );


    // ================================================================
    // 模块三：alu_control — ALU 控制接口（角色A）
    // ================================================================
    alu_control u_alu_control (
        .is_add  (is_add),
        .is_sub  (is_sub),
        .is_and  (is_and),
        .is_inc  (is_inc),
        .is_ld   (is_ld),
        .t1      (t1),
        .t2      (t2),
        .t3      (t3),
        .cin     (alu_cin),
        .ldz     (alu_ldz),
        .ldc     (alu_ldc)
    );


    // ================================================================
    // 模块四：control_unit — TEC-8 核心控制单元（角色B）
    // ================================================================
    control_unit u_control_unit (
        .t1      (t1),
        .t2      (t2),
        .t3      (t3),
        .w1      (w1),
        .w2      (w2),
        .w3      (w3),
        .is_add  (is_add),
        .is_sub  (is_sub),
        .is_and  (is_and),
        .is_inc  (is_inc),
        .is_ld   (is_ld),
        .is_st   (is_st),
        .is_jc   (is_jc),
        .is_jz   (is_jz),
        .is_jmp  (is_jmp),
        .is_stp  (is_stp),
        .c_flag  (c_in),
        .z_flag  (z_in),
        .sw      (sw),
        .ARINC   (ARINC),
        .CIN     (CIN),
        .DRW     (DRW),
        .LPC     (LPC),
        .LAR     (LAR),
        .LIR     (LIR),
        .LDZ     (LDZ),
        .LDC     (LDC),
        .PCINC   (PCINC),
        .PCADD   (PCADD),
        .SELCTL  (SELCTL),
        .M       (M),
        .MEMW    (MEMW),
        .STOP    (STOP),
        .SHORT   (SHORT),
        .LONG    (LONG_),
        .ABUS    (ABUS),
        .SBUS    (SBUS),
        .MBUS    (MBUS),
        .SST0    (SST0),
        .S       (S),
        .SEL     (SEL)
    );


    // ================================================================
    // 模块五：regfile_control — 寄存器组控制（角色B）
    // ================================================================
    regfile_control u_regfile_control (
        .ir      (ir_full),        // 完整 IR[7:0]
        .t1      (t1),
        .t2      (t2),
        .t3      (t3),
        .lr0     (lr0),
        .lr1     (lr1),
        .lr2     (lr2),
        .lr3     (lr3),
        .rs0     (rs0),
        .rs1     (rs1),
        .rd0     (rd0),
        .rd1     (rd1),
        .s0      (s0),
        .s1      (s1),
        .s2      (s2),
        .s3      (s3)
    );

endmodule
