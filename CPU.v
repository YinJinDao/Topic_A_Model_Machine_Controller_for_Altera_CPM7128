// ============================================================
// 文件名: CPU.v  ——  顶层实体（临时，用于仿真通过）
// 说明: 当前仅包含 timing_gen，后续由成员 D 扩展
// ============================================================
module CPU (
    input  wire clk,
    input  wire reset_n,
    output wire t1, t2, t3,
    output wire w1, w2, w3
);

    timing_gen u_timing_gen (
        .clk    (clk),
        .reset_n(reset_n),
        .t1     (t1),
        .t2     (t2),
        .t3     (t3),
        .w1     (w1),
        .w2     (w2),
        .w3     (w3)
    );

endmodule
