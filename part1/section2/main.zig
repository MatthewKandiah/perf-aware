// Task:
// input - file containing compiled binary instructions
// output - valid assembly that compiles to matching binary instructions

const std = @import("std");

pub fn main() !void {
    const input_file = try std.fs.openFileAbsolute("/home/matt/code/perf-aware/part1/section2/more_movs", .{});
    defer input_file.close();
    const file_reader = input_file.reader();

    const output_file = try std.fs.createFileAbsolute("/home/matt/code/perf-aware/part1/section2/more_movs_out.asm", .{});
    defer output_file.close();

    const op_code_mask = 0b11111100;
    const d_mask = 0b00000010;
    const w_mask = 0b00000001;
    const mod_mask = 0b11000000;
    const reg_mask = 0b00111000;
    const rm_mask = 0b00000111;

    _ = try output_file.write("bits 16\n\n");

    while (true) {
        const byte1 = file_reader.readByte() catch break;
        const op_code = (byte1 & op_code_mask) >> 2;
        const d = (byte1 & d_mask) >> 1;
        const w = byte1 & w_mask;

        if (op_code != 0b100010) std.debug.panic("Unsupported op_code {b}", .{op_code});

        const byte2 = try file_reader.readByte();
        const mod = (byte2 & mod_mask) >> 6;
        const reg = (byte2 & reg_mask) >> 3;
        const rm = byte2 & rm_mask;

        if (mod != 0b11) std.debug.panic("Unsupported mod {b}", .{mod});

        const reg1 = try reg_lookup(reg, w);
        const reg2 = try reg_lookup(rm, w);

        const source = if (d == 0) reg1 else reg2;
        const dest = if (d == 0) reg2 else reg1;

        _ = try output_file.write("mov ");
        _ = try output_file.write(dest.toString());
        _ = try output_file.write(", ");
        _ = try output_file.write(source.toString());
        _ = try output_file.write("\n");
    }
}

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

    fn toString(self: Self) []const u8 {
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
