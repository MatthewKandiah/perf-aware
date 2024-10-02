const std = @import("std");
const parse = @import("parse_json.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const gpa_allocator = gpa.allocator();

    var arena = std.heap.ArenaAllocator.init(gpa_allocator);
    defer _ = arena.reset(.free_all);
    const arena_allocator = arena.allocator();
    const result = try parse.parseFile(arena_allocator, "data_1_10.json");
    std.debug.print("result:\n{any}\n", .{result});
}
