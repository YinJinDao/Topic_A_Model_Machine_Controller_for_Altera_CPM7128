// ============================================================
// 文件名: control_unit.v  ——  控制单元
// 所属项目: TEC-8 模型机控制器（题目A）
// 设计者: 角色B
// 功能描述:
//   根据时序节拍、指令译码结果和标志位，产生 TEC-8 全部控制信号。
//   端口命名与 docs/接口定义/模块接口定义.md 保持一致。
// ============================================================

module control_unit (
    // --- 时序输入（来自 timing_gen）---
    input  wire       t1,
    input  wire       t2,
    input  wire       t3,
    input  wire       w1,
    input  wire       w2,
    input  wire       w3,

    // --- 指令标识（来自 instruction_decoder）---
    input  wire       is_add,
    input  wire       is_sub,
    input  wire       is_and,
    input  wire       is_inc,
    input  wire       is_ld,
    input  wire       is_st,
    input  wire       is_jc,
    input  wire       is_jz,
    input  wire       is_jmp,
    input  wire       is_stp,

    // --- 状态与开关 ---
    input  wire       c_flag,
    input  wire       z_flag,
    input  wire [2:0] sw,

    // --- TEC-8 控制信号输出 ---
    output reg        ARINC,
    output reg        CIN,
    output reg        DRW,
    output reg        LPC,
    output reg        LAR,
    output reg        LIR,
    output reg        LDZ,
    output reg        LDC,
    output reg        PCINC,
    output reg        PCADD,
    output reg        SELCTL,
    output reg        M,
    output reg        MEMW,
    output reg        STOP,
    output reg        SHORT,
    output reg        LONG,
    output reg        ABUS,
    output reg        SBUS,
    output reg        MBUS,
    output reg        SST0,
    output reg  [1:0] S,
    output reg  [1:0] SEL
);

    wire [3:0] inst_sel = is_add ? 4'd1 :
                          is_sub ? 4'd2 :
                          is_and ? 4'd3 :
                          is_inc ? 4'd4 :
                          is_ld  ? 4'd5 :
                          is_st  ? 4'd6 :
                          is_jc  ? 4'd7 :
                          is_jz  ? 4'd8 :
                          is_jmp ? 4'd9 :
                          is_stp ? 4'd10 : 4'd0;

    // 无有效指令时为取指周期；有指令标识时为执行周期
    wire no_inst = ~is_add & ~is_sub & ~is_and & ~is_inc & ~is_ld &
                   ~is_st & ~is_jc & ~is_jz & ~is_jmp & ~is_stp;

    always @(*) begin
        ARINC  = 1'b0;
        CIN    = 1'b0;
        DRW    = 1'b0;
        LPC    = 1'b0;
        LAR    = 1'b0;
        LIR    = 1'b0;
        LDZ    = 1'b0;
        LDC    = 1'b0;
        PCINC  = 1'b0;
        PCADD  = 1'b0;
        SELCTL = 1'b0;
        M      = 1'b0;
        MEMW   = 1'b0;
        STOP   = 1'b0;
        SHORT  = 1'b0;
        LONG   = 1'b0;
        ABUS   = 1'b0;
        SBUS   = 1'b0;
        MBUS   = 1'b0;
        SST0   = 1'b0;
        S      = 2'b00;
        SEL    = 2'b00;

        if (no_inst) begin
            // 取指周期（接口真值表：T1→LIR+PCINC；T2→LAR+SBUS）
            if (t1) begin
                LIR   = 1'b1;
                PCINC = 1'b1;
            end
            if (t2) begin
                LAR  = 1'b1;
                SBUS = 1'b1;
            end
        end else begin
            case (inst_sel)
                // ADD: T1→SBUS+ABUS+CIN+LDZ+LDC；写回用 w1
                4'd1: begin
                    SHORT = 1'b1;
                    SEL   = 2'b11;
                    if (t1) begin
                        SBUS = 1'b1;
                        ABUS = 1'b1;
                        CIN  = 1'b0;
                        LDZ  = 1'b1;
                        LDC  = 1'b1;
                    end
                    if (w1)
                        DRW = 1'b1;
                end

                4'd2: begin
                    SHORT = 1'b1;
                    SEL   = 2'b11;
                    if (t1) begin
                        SBUS = 1'b1;
                        ABUS = 1'b1;
                        CIN  = 1'b1;
                        LDZ  = 1'b1;
                        LDC  = 1'b1;
                    end
                    if (w1)
                        DRW = 1'b1;
                end

                4'd3: begin
                    SHORT = 1'b1;
                    SEL   = 2'b11;
                    if (t1) begin
                        SBUS = 1'b1;
                        ABUS = 1'b1;
                        M    = 1'b1;
                        LDZ  = 1'b1;
                    end
                    if (w1)
                        DRW = 1'b1;
                end

                4'd4: begin
                    SHORT = 1'b1;
                    SEL   = 2'b01;
                    if (t1) begin
                        ABUS = 1'b1;
                        CIN  = 1'b1;
                        LDZ  = 1'b1;
                        LDC  = 1'b1;
                    end
                    if (w1)
                        DRW = 1'b1;
                end

                4'd5: begin
                    LONG = 1'b1;
                    if (t1) begin
                        SBUS = 1'b1;
                        LAR  = 1'b1;
                        ABUS = 1'b1;
                    end
                    if (t2)
                        MBUS = 1'b1;
                    if (w2)
                        DRW = 1'b1;
                end

                4'd6: begin
                    LONG = 1'b1;
                    if (t1) begin
                        SBUS = 1'b1;
                        LAR  = 1'b1;
                        ABUS = 1'b1;
                    end
                    if (t2)
                        SBUS = 1'b1;
                    if (w2)
                        MEMW = 1'b1;
                end

                4'd7: begin
                    LONG = 1'b1;
                    if (t1 && c_flag) begin
                        PCADD  = 1'b1;
                        SELCTL = 1'b1;
                    end
                end

                4'd8: begin
                    LONG = 1'b1;
                    if (t1 && z_flag) begin
                        PCADD  = 1'b1;
                        SELCTL = 1'b1;
                    end
                end

                4'd9: begin
                    SHORT = 1'b1;
                    if (t1) begin
                        LPC    = 1'b1;
                        SELCTL = 1'b1;
                        SBUS   = 1'b1;
                    end
                end

                4'd10: begin
                    if (t1)
                        STOP = 1'b1;
                end

                default: ;
            endcase
        end
    end

endmodule
