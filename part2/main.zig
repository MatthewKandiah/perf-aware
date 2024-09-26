const std = @import("std");
const parse_json = @import("parse_json.zig");

pub fn main() !void {
    std.debug.print("Scratch program for testing\n\n", .{});

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    const file = try std.fs.cwd().openFile("data_1_10.json", .{});
    const reader = file.reader();
    _ = try parse_json.parse(allocator, reader.any());
}
