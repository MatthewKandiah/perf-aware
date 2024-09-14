// Task:
// input - file containing compiled binary instructions
// output - valid assembly that compiles to matching binary instructions

const std = @import("std");

pub fn main() !void {
    const file = try std.fs.openFileAbsolute("/home/matt/code/perf-aware/part1/section1/single_register_mov.asm", .{});
    const file_reader = file.reader();

    const first_byte = try file_reader.readByte();
    const second_byte = try file_reader.readByte();

    std.debug.print("{b} {b}\n", .{ first_byte, second_byte });
}
