// Task:
// input - file containing compiled binary instructions
// output - valid assembly that compiles to matching binary instructions

const std = @import("std");

pub fn main() !void {
    const input_file = try std.fs.openFileAbsolute("/home/matt/code/perf-aware/part1/section3/add_sub_cmp_jnz", .{});
    defer input_file.close();
    const file_reader = input_file.reader();

    const output_file = try std.fs.createFileAbsolute("/home/matt/code/perf-aware/part1/section3/add_sub_cmp_jnz_out.asm", .{});
    defer output_file.close();

    _ = try output_file.write("bits 16\n\n");

    while (true) {
        const first_byte = file_reader.readByte() catch break;

        if ((first_byte & imm_to_reg_opcode_mask) >> 4 == imm_to_reg_opcode) {
            const w = (first_byte & imm_to_reg_w_mask) >> 3;
            const reg = (first_byte & imm_to_reg_reg_mask);
            var buf: [64]u8 = undefined;
            switch (w) {
                0 => {
                    const data: i8 = @bitCast(try file_reader.readByte());
                    _ = try output_file.write("mov ");
                    _ = try output_file.write((try reg_lookup(reg, w)).toString());
                    _ = try output_file.write(", ");
                    _ = try output_file.write(try std.fmt.bufPrint(&buf, "{}", .{data}));
                    _ = try output_file.write("\n");
                },
                1 => {
                    const data_lo = try file_reader.readByte();
                    const data_hi = try file_reader.readByte();
                    const data_combined: u16 = (@as(u16, @intCast(data_hi)) << 8) + (@as(u16, @intCast(data_lo)));
                    const data: i16 = @bitCast(data_combined);
                    _ = try output_file.write("mov ");
                    _ = try output_file.write((try reg_lookup(reg, w)).toString());
                    _ = try output_file.write(", ");
                    _ = try output_file.write(try std.fmt.bufPrint(&buf, "{}", .{data}));
                    _ = try output_file.write("\n");
                },
                else => unreachable,
            }
        } else if ((first_byte & mov_opcode_mask) >> 2 == mov_opcode) {
            const d = (first_byte & mov_d_mask) >> 1;
            const w = (first_byte & mov_w_mask);
            const second_byte = try file_reader.readByte();
            const mod = (second_byte & mov_mod_mask) >> 6;
            const reg = (second_byte & mov_reg_mask) >> 3;
            const r_m = (second_byte & mov_r_m_mask);

            switch (mod) {
                0b00 => {
                    const addr_byte1 = if (r_m == 0b110) try file_reader.readByte() else null;
                    const addr_byte2 = if (r_m == 0b110) try file_reader.readByte() else null;
                    const direct_address: u16 = if (addr_byte1 != null and addr_byte2 != null) (@as(u16, @intCast(addr_byte2.?)) << 8) & (@as(u16, @intCast(addr_byte1.?))) else undefined;
                    _ = try output_file.write("mov ");
                    if (d == 0) {
                        _ = try output_file.write(try r_m_mod0_lookup(r_m, direct_address));
                        _ = try output_file.write(", ");
                        _ = try output_file.write((try reg_lookup(reg, w)).toString());
                    } else {
                        _ = try output_file.write((try reg_lookup(reg, w)).toString());
                        _ = try output_file.write(", ");
                        _ = try output_file.write(try r_m_mod0_lookup(r_m, direct_address));
                    }
                    _ = try output_file.write("\n");
                },
                0b01 => {
                    const displacement = try file_reader.readByte();
                    _ = try output_file.write("mov ");
                    if (d == 0) {
                        _ = try output_file.write(try r_m_mod1_lookup(r_m, displacement));
                        _ = try output_file.write(", ");
                        _ = try output_file.write((try reg_lookup(reg, w)).toString());
                    } else {
                        _ = try output_file.write((try reg_lookup(reg, w)).toString());
                        _ = try output_file.write(", ");
                        _ = try output_file.write(try r_m_mod1_lookup(r_m, displacement));
                    }
                    _ = try output_file.write("\n");
                },
                0b10 => {
                    const disp_lo = try file_reader.readByte();
                    const disp_hi = try file_reader.readByte();
                    const displacement: u16 = (@as(u16, @intCast(disp_hi)) << 8) | @as(u16, @intCast(disp_lo));
                    _ = try output_file.write("mov ");
                    if (d == 0) {
                        _ = try output_file.write(try r_m_mod2_lookup(r_m, displacement));
                        _ = try output_file.write(", ");
                        _ = try output_file.write((try reg_lookup(reg, w)).toString());
                    } else {
                        _ = try output_file.write((try reg_lookup(reg, w)).toString());
                        _ = try output_file.write(", ");
                        _ = try output_file.write(try r_m_mod2_lookup(r_m, displacement));
                    }
                    _ = try output_file.write("\n");
                },
                0b11 => {
                    const reg_register = try reg_lookup(reg, w);
                    const r_m_register = try reg_lookup(r_m, w);
                    const source_register = if (d == 0) reg_register else r_m_register;
                    const dest_register = if (d == 0) r_m_register else reg_register;

                    _ = try output_file.write("mov ");
                    _ = try output_file.write(dest_register.toString());
                    _ = try output_file.write(", ");
                    _ = try output_file.write(source_register.toString());
                    _ = try output_file.write("\n");
                },
                else => unreachable,
            }
        }
    }
}

const mov_opcode = 0b100010;
const mov_opcode_mask = 0b11111100;
const mov_d_mask = 0b00000010;
const mov_w_mask = 0b00000001;
const mov_mod_mask = 0b11000000;
const mov_reg_mask = 0b00111000;
const mov_r_m_mask = 0b00000111;

const imm_to_reg_opcode = 0b1011;
const imm_to_reg_opcode_mask = 0b11110000;
const imm_to_reg_w_mask = 0b00001000;
const imm_to_reg_reg_mask = 0b00000111;

const Register = enum {
    AX,
    AL,
    AH,
    BX,
    BL,
    BH,
    CX,
    CL,
    CH,
    DX,
    DL,
    DH,
    SP,
    SI,
    BP,
    DI,

    const Self = @This();

    inline fn toString(self: Self) []const u8 {
        return switch (self) {
            .AX => "ax",
            .AL => "al",
            .AH => "ah",
            .BX => "bx",
            .BL => "bl",
            .BH => "bh",
            .CX => "cx",
            .CL => "cl",
            .CH => "ch",
            .DX => "dx",
            .DL => "dl",
            .DH => "dh",
            .SP => "sp",
            .SI => "si",
            .BP => "bp",
            .DI => "di",
        };
    }
};

fn r_m_mod0_lookup(r_m: u8, direct_address: ?u16) ![]const u8 {
    return switch (r_m) {
        0b000 => "[" ++ Register.BX.toString() ++ " + " ++ Register.SI.toString() ++ "]",
        0b001 => "[" ++ Register.BX.toString() ++ " + " ++ Register.DI.toString() ++ "]",
        0b010 => "[" ++ Register.BP.toString() ++ " + " ++ Register.SI.toString() ++ "]",
        0b011 => "[" ++ Register.BP.toString() ++ " + " ++ Register.DI.toString() ++ "]",
        0b100 => "[" ++ Register.SI.toString() ++ "]",
        0b101 => "[" ++ Register.DI.toString() ++ "]",
        0b110 => {
            var buf: [64]u8 = undefined;
            return std.fmt.bufPrint(&buf, "[{}]", .{direct_address.?});
        },
        0b111 => "[" ++ Register.BX.toString() ++ "]",
        else => unreachable,
    };
}

fn r_m_mod1_lookup(r_m: u8, displacement: u8) ![]const u8 {
    var buf: [64]u8 = undefined;
    return switch (r_m) {
        0b000 => std.fmt.bufPrint(&buf, "[{s} + {s} + {}]", .{ Register.BX.toString(), Register.SI.toString(), displacement }),
        0b001 => std.fmt.bufPrint(&buf, "[{s} + {s} + {}]", .{ Register.BX.toString(), Register.DI.toString(), displacement }),
        0b010 => std.fmt.bufPrint(&buf, "[{s} + {s} + {}]", .{ Register.BP.toString(), Register.SI.toString(), displacement }),
        0b011 => std.fmt.bufPrint(&buf, "[{s} + {s} + {}]", .{ Register.BP.toString(), Register.DI.toString(), displacement }),
        0b100 => std.fmt.bufPrint(&buf, "[{s} + {}]", .{ Register.SI.toString(), displacement }),
        0b101 => std.fmt.bufPrint(&buf, "[{s} + {}]", .{ Register.DI.toString(), displacement }),
        0b110 => std.fmt.bufPrint(&buf, "[{s} + {}]", .{ Register.BP.toString(), displacement }),
        0b111 => std.fmt.bufPrint(&buf, "[{s} + {}]", .{ Register.BX.toString(), displacement }),
        else => unreachable,
    };
}

fn r_m_mod2_lookup(r_m: u8, displacement: u16) ![]const u8 {
    var buf: [64]u8 = undefined;
    return switch (r_m) {
        0b000 => std.fmt.bufPrint(&buf, "[{s} + {s} + {}]", .{ Register.BX.toString(), Register.SI.toString(), displacement }),
        0b001 => std.fmt.bufPrint(&buf, "[{s} + {s} + {}]", .{ Register.BX.toString(), Register.DI.toString(), displacement }),
        0b010 => std.fmt.bufPrint(&buf, "[{s} + {s} + {}]", .{ Register.BP.toString(), Register.SI.toString(), displacement }),
        0b011 => std.fmt.bufPrint(&buf, "[{s} + {s} + {}]", .{ Register.BP.toString(), Register.DI.toString(), displacement }),
        0b100 => std.fmt.bufPrint(&buf, "[{s} + {}]", .{ Register.SI.toString(), displacement }),
        0b101 => std.fmt.bufPrint(&buf, "[{s} + {}]", .{ Register.DI.toString(), displacement }),
        0b110 => std.fmt.bufPrint(&buf, "[{s} + {}]", .{ Register.BP.toString(), displacement }),
        0b111 => std.fmt.bufPrint(&buf, "[{s} + {}]", .{ Register.BX.toString(), displacement }),
        else => unreachable,
    };
}

fn reg_lookup(reg: u8, w: u8) !Register {
    return switch (w) {
        0 => reg_w0_lookup(reg),
        1 => reg_w1_lookup(reg),
        else => error.InvalidW,
    };
}

fn reg_w0_lookup(reg: u8) !Register {
    return switch (reg) {
        0b000 => .AL,
        0b001 => .CL,
        0b010 => .DL,
        0b011 => .BL,
        0b100 => .AH,
        0b101 => .CH,
        0b110 => .DH,
        0b111 => .BH,
        else => error.InvalidReg,
    };
}

fn reg_w1_lookup(reg: u8) !Register {
    return switch (reg) {
        0b000 => .AX,
        0b001 => .CX,
        0b010 => .DX,
        0b011 => .BX,
        0b100 => .SP,
        0b101 => .BP,
        0b110 => .SI,
        0b111 => .DI,
        else => error.InvalidReg,
    };
}
