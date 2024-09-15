// Task:
// input - file containing compiled binary instructions
// output - valid assembly that compiles to matching binary instructions

const std = @import("std");

pub fn main() !void {
    const file = try std.fs.openFileAbsolute("/home/matt/code/perf-aware/part1/section1/single_register_mov", .{});
    const file_reader = file.reader();

    while (true) {
        const read_byte_result = file_reader.readByte() catch break;
        std.debug.print("{b}\n", .{read_byte_result});
    }

    std.debug.print("Done\n", .{});
}
