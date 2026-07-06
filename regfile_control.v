// ============================================================
// 文件名: regfile_control.v  ——  寄存器组控制
// 所属项目: TEC-8 模型机控制器（题目A）
// 设计者: 角色B
// 功能描述:
//   根据完整指令 IR 和时序节拍，产生寄存器堆读写选择信号。
//   端口命名与 docs/接口定义/模块接口定义.md 保持一致。
//
// TEC-8 指令字段约定:
//   IR7-IR4 : 操作码
//   IR3-IR2 : Rj / 目的寄存器（双操作数指令）
//   IR1-IR0 : Ri / 源寄存器或单操作数寄存器
// ============================================================

module regfile_control (
    input  wire [7:0] ir,
    input  wire       t1,
    input  wire       t2,
    input  wire       t3,

    output reg        lr0,
    output reg        lr1,
    output reg        lr2,
    output reg        lr3,
    output reg        rs0,
    output reg        rs1,
    output reg        rd0,
    output reg        rd1,
    output reg        s0,
    output reg        s1,
    output reg        s2,
    output reg        s3
);

    wire [3:0] opcode = ir[7:4];

    // 双操作数指令: IR[3:2]=Rj, IR[1:0]=Ri
    // 单操作数指令: IR[1:0]=Ri
    wire [1:0] rs_addr = ir[1:0];
    wire [1:0] rd_addr = (opcode == 4'b0100 || opcode == 4'b0101) ?
                         ir[1:0] : ir[3:2];

    wire is_arith = (opcode == 4'b0001) || (opcode == 4'b0010) ||
                    (opcode == 4'b0011) || (opcode == 4'b0100);
    wire is_ld    = (opcode == 4'b0101);
    wire is_st    = (opcode == 4'b0110);
    wire reg_write = is_arith || is_ld;

    always @(*) begin
        lr0 = 1'b0;
        lr1 = 1'b0;
        lr2 = 1'b0;
        lr3 = 1'b0;
        rs0 = 1'b0;
        rs1 = 1'b0;
        rd0 = 1'b0;
        rd1 = 1'b0;
        s0  = 1'b0;
        s1  = 1'b0;
        s2  = 1'b0;
        s3  = 1'b0;

        rs0 = rs_addr[0];
        rs1 = rs_addr[1];
        rd0 = rd_addr[0];
        rd1 = rd_addr[1];

        // T3 节拍写回目标寄存器（LR0-LR3 二-四译码输出）
        if (t3 && reg_write) begin
            case (rd_addr)
                2'b00: lr0 = 1'b1;
                2'b01: lr1 = 1'b1;
                2'b10: lr2 = 1'b1;
                2'b11: lr3 = 1'b1;
                default: ;
            endcase
        end

        // 寄存器选择器控制（TEC-8: 011=读寄存器, 100=写寄存器）
        case (opcode)
            4'b0001, 4'b0010, 4'b0011, 4'b0100: begin
                if (t1) begin
                    s0 = 1'b1;
                    s1 = 1'b1;
                end
                if (t3) begin
                    s2 = 1'b1;
                end
            end

            4'b0101: begin
                if (t3) begin
                    s2 = 1'b1;
                end
            end

            4'b0110: begin
                if (t2) begin
                    s0 = 1'b1;
                    s1 = 1'b1;
                end
            end

            default: ;
        endcase
    end

endmodule
