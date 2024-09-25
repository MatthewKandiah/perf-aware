// Task:
// input - file containing compiled binary instructions
// output - valid assembly that compiles to matching binary instructions

const std = @import("std");

const regression_test = true;
const input_file_path =
    if (regression_test) "/home/matt/code/perf-aware/part1/section3/more_movs" else "/home/matt/code/perf-aware/part1/section3/add_sub_cmp_jnz";

const output_file_path =
    if (regression_test) "/home/matt/code/perf-aware/part1/section3/more_movs_out.asm" else "/home/matt/code/perf-aware/part1/section3/add_sub_cmp_jnz_out.asm";

pub fn main() !void {
    const input_file = try std.fs.openFileAbsolute(input_file_path, .{});
    defer input_file.close();
    const file_reader = input_file.reader();

    const output_file = try std.fs.createFileAbsolute(output_file_path, .{});
    defer output_file.close();

    _ = try output_file.write("bits 16\n\n");

    var buf: [64]u8 = undefined;
    while (true) {
        const first_byte = file_reader.readByte() catch break;
        if (mov_imm_to_reg_opcode_mask.apply(first_byte) == mov_imm_to_reg_opcode) {
            _ = try output_file.write("mov ");
            const w = mov_imm_to_reg_w_mask.apply(first_byte);
            const reg = mov_imm_to_reg_reg_mask.apply(first_byte);
            switch (w) {
                0 => {
                    const num_string = try readNextByteToNumString(i8, file_reader, &buf);
                    _ = try output_file.write((try reg_lookup(reg, w)).toString());
                    _ = try output_file.write(", ");
                    _ = try output_file.write(num_string);
                },
                1 => {
                    const num_string = try readNext2BytesToNumString(i16, file_reader, &buf);
                    _ = try output_file.write((try reg_lookup(reg, w)).toString());
                    _ = try output_file.write(", ");
                    _ = try output_file.write(num_string);
                },
                else => unreachable,
            }
        } else if (byteMatchesSixDigitOpcode(first_byte)) {
            _ = try output_file.write(switch (SixDigitOpcode.fromValue(six_digit_opcode_mask.apply(first_byte))) {
                .mov => "mov ",
                .add => "add ",
            });
            const d = d_mask.apply(first_byte);
            const w = w_mask.apply(first_byte);
            const mod_reg_rm = try readAndParseModRegRmByte(file_reader);
            const mod = mod_reg_rm.mod;
            const reg = mod_reg_rm.reg;
            const r_m = mod_reg_rm.r_m;

            switch (mod) {
                0b00 => {
                    const direct_address: ?[]const u8 = if (r_m == 0b110) try readNext2BytesToNumString(u16, file_reader, &buf) else null;
                    if (d == 0) {
                        _ = try output_file.write(try r_m_mod0_lookup(r_m, direct_address));
                        _ = try output_file.write(", ");
                        _ = try output_file.write((try reg_lookup(reg, w)).toString());
                    } else {
                        _ = try output_file.write((try reg_lookup(reg, w)).toString());
                        _ = try output_file.write(", ");
                        _ = try output_file.write(try r_m_mod0_lookup(r_m, direct_address));
                    }
                },
                0b01 => {
                    const displacement = try readNextByteToNumString(u8, file_reader, &buf);
                    if (d == 0) {
                        _ = try output_file.write(try r_m_mod1_lookup(r_m, displacement));
                        _ = try output_file.write(", ");
                        _ = try output_file.write((try reg_lookup(reg, w)).toString());
                    } else {
                        _ = try output_file.write((try reg_lookup(reg, w)).toString());
                        _ = try output_file.write(", ");
                        _ = try output_file.write(try r_m_mod1_lookup(r_m, displacement));
                    }
                },
                0b10 => {
                    const displacement = try readNext2BytesToNumString(u16, file_reader, &buf);
                    if (d == 0) {
                        _ = try output_file.write(try r_m_mod2_lookup(r_m, displacement));
                        _ = try output_file.write(", ");
                        _ = try output_file.write((try reg_lookup(reg, w)).toString());
                    } else {
                        _ = try output_file.write((try reg_lookup(reg, w)).toString());
                        _ = try output_file.write(", ");
                        _ = try output_file.write(try r_m_mod2_lookup(r_m, displacement));
                    }
                },
                0b11 => {
                    const reg_register = try reg_lookup(reg, w);
                    const r_m_register = try reg_lookup(r_m, w);
                    const source_register = if (d == 0) reg_register else r_m_register;
                    const dest_register = if (d == 0) r_m_register else reg_register;

                    _ = try output_file.write(dest_register.toString());
                    _ = try output_file.write(", ");
                    _ = try output_file.write(source_register.toString());
                },
                else => unreachable,
            }
        }
        _ = try output_file.write("\n");
    }
}

const Mask = struct {
    value: u8,
    shift: u3,

    const Self = @This();

    fn apply(self: Self, byte: u8) u8 {
        return (byte & self.value) >> self.shift;
    }
};

const mod_mask = Mask{
    .value = 0b11000000,
    .shift = 6,
};

const reg_mask = Mask{
    .value = 0b00111000,
    .shift = 3,
};

const rm_mask = Mask{
    .value = 0b00000111,
    .shift = 0,
};

const six_digit_opcode_mask = Mask{
    .value = 0b11111100,
    .shift = 2,
};

const d_mask = Mask{
    .value = 0b00000010,
    .shift = 1,
};

const w_mask = Mask{
    .value = 0b00000001,
    .shift = 0,
};

const mov_imm_to_reg_opcode_mask = Mask{
    .value = 0b11110000,
    .shift = 4,
};

const mov_imm_to_reg_w_mask = Mask{
    .value = 0b00001000,
    .shift = 3,
};

const mov_imm_to_reg_reg_mask = Mask{
    .value = 0b00000111,
    .shift = 0,
};

const SixDigitOpcode = enum(u8) {
    add = 0b000000,
    mov = 0b100010,

    const Self = @This();

    fn isMatching(byte: u8) bool {
        return byte == Self.add.value() or byte == Self.mov.value();
    }

    fn value(self: Self) u8 {
        return @intFromEnum(self);
    }

    fn fromValue(byte: u8) Self {
        return switch (byte) {
            Self.add.value() => Self.add,
            Self.mov.value() => Self.mov,
            else => unreachable,
        };
    }

    fn toString(self: Self) []const u8 {
        return switch (self) {
            .add => "add",
            .mov => "mov",
        };
    }
};
fn byteMatchesSixDigitOpcode(byte: u8) bool {
    const candidate = six_digit_opcode_mask.apply(byte);
    return SixDigitOpcode.isMatching(candidate);
}

const mov_imm_to_reg_opcode = 0b1011;

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

fn r_m_mod0_lookup(r_m: u8, direct_address_string: ?[]const u8) ![]const u8 {
    return switch (r_m) {
        0b000 => "[" ++ Register.BX.toString() ++ " + " ++ Register.SI.toString() ++ "]",
        0b001 => "[" ++ Register.BX.toString() ++ " + " ++ Register.DI.toString() ++ "]",
        0b010 => "[" ++ Register.BP.toString() ++ " + " ++ Register.SI.toString() ++ "]",
        0b011 => "[" ++ Register.BP.toString() ++ " + " ++ Register.DI.toString() ++ "]",
        0b100 => "[" ++ Register.SI.toString() ++ "]",
        0b101 => "[" ++ Register.DI.toString() ++ "]",
        0b110 => {
            var buf: [64]u8 = undefined;
            return std.fmt.bufPrint(&buf, "[{s}]", .{direct_address_string.?});
        },
        0b111 => "[" ++ Register.BX.toString() ++ "]",
        else => unreachable,
    };
}

fn r_m_mod1_lookup(r_m: u8, displacement: []const u8) ![]const u8 {
    var buf: [64]u8 = undefined;
    return switch (r_m) {
        0b000 => std.fmt.bufPrint(&buf, "[{s} + {s} + {s}]", .{ Register.BX.toString(), Register.SI.toString(), displacement }),
        0b001 => std.fmt.bufPrint(&buf, "[{s} + {s} + {s}]", .{ Register.BX.toString(), Register.DI.toString(), displacement }),
        0b010 => std.fmt.bufPrint(&buf, "[{s} + {s} + {s}]", .{ Register.BP.toString(), Register.SI.toString(), displacement }),
        0b011 => std.fmt.bufPrint(&buf, "[{s} + {s} + {s}]", .{ Register.BP.toString(), Register.DI.toString(), displacement }),
        0b100 => std.fmt.bufPrint(&buf, "[{s} + {s}]", .{ Register.SI.toString(), displacement }),
        0b101 => std.fmt.bufPrint(&buf, "[{s} + {s}]", .{ Register.DI.toString(), displacement }),
        0b110 => std.fmt.bufPrint(&buf, "[{s} + {s}]", .{ Register.BP.toString(), displacement }),
        0b111 => std.fmt.bufPrint(&buf, "[{s} + {s}]", .{ Register.BX.toString(), displacement }),
        else => unreachable,
    };
}

fn r_m_mod2_lookup(r_m: u8, displacement: []const u8) ![]const u8 {
    var buf: [64]u8 = undefined;
    return switch (r_m) {
        0b000 => std.fmt.bufPrint(&buf, "[{s} + {s} + {s}]", .{ Register.BX.toString(), Register.SI.toString(), displacement }),
        0b001 => std.fmt.bufPrint(&buf, "[{s} + {s} + {s}]", .{ Register.BX.toString(), Register.DI.toString(), displacement }),
        0b010 => std.fmt.bufPrint(&buf, "[{s} + {s} + {s}]", .{ Register.BP.toString(), Register.SI.toString(), displacement }),
        0b011 => std.fmt.bufPrint(&buf, "[{s} + {s} + {s}]", .{ Register.BP.toString(), Register.DI.toString(), displacement }),
        0b100 => std.fmt.bufPrint(&buf, "[{s} + {s}]", .{ Register.SI.toString(), displacement }),
        0b101 => std.fmt.bufPrint(&buf, "[{s} + {s}]", .{ Register.DI.toString(), displacement }),
        0b110 => std.fmt.bufPrint(&buf, "[{s} + {s}]", .{ Register.BP.toString(), displacement }),
        0b111 => std.fmt.bufPrint(&buf, "[{s} + {s}]", .{ Register.BX.toString(), displacement }),
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

fn readNextByteToNumString(comptime T: type, reader: std.fs.File.Reader, buf: []u8) ![]const u8 {
    const data: T = @bitCast(try reader.readByte());
    return std.fmt.bufPrint(buf, "{}", .{data});
}

fn readNext2BytesToNumString(comptime T: type, reader: std.fs.File.Reader, buf: []u8) ![]const u8 {
    const data_lo = try reader.readByte();
    const data_hi = try reader.readByte();
    const data_combined: u16 = (@as(u16, @intCast(data_hi)) << 8) + (@as(u16, @intCast(data_lo)));
    const data: T = @bitCast(data_combined);
    return std.fmt.bufPrint(buf, "{}", .{data});
}

const ModRegRm = struct {
    mod: u8,
    reg: u8,
    r_m: u8,
};

fn readAndParseModRegRmByte(reader: std.fs.File.Reader) !ModRegRm {
    const byte = try reader.readByte();
    const mod = mod_mask.apply(byte);
    const reg = reg_mask.apply(byte);
    const r_m = rm_mask.apply(byte);
    return .{ .mod = mod, .reg = reg, .r_m = r_m };
}
