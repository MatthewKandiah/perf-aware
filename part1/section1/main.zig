// Task:
// input - file containing compiled binary instructions
// output - valid assembly that compiles to matching binary instructions

const std = @import("std");

pub fn main() !void {
    // const file = try std.fs.openFileAbsolute("/home/matt/code/perf-aware/part1/section1/single_register_mov", .{});
    const file = try std.fs.openFileAbsolute("/home/matt/code/perf-aware/part1/section1/many_register_mov", .{});
    const file_reader = file.reader();

    while (true) {
        const byte1 = file_reader.readByte() catch break;
        const byte2 = try file_reader.readByte();
        std.debug.print("{b} {b}\n", .{ byte1, byte2 });
    }

    std.debug.print("Done\n", .{});
}
