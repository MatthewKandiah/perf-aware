const std = @import("std");
const parse = @import("parse_json.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const gpa_allocator = gpa.allocator();

    var arena = std.heap.ArenaAllocator.init(gpa_allocator);
    defer _ = arena.reset(.free_all);
    const arena_allocator = arena.allocator();

    const args = std.process.argsAlloc(arena_allocator) catch std.process.exit(1);
    if (args.len != 2) {
        std.debug.print("USAGE: must pass path to input data file\n", .{});
        std.process.exit(1);
    }

    const file_name = args[1];

    const sum = try parse.haversineSumForFile(arena_allocator, file_name);
    std.debug.print("sum: {d}\n", .{sum});
}
