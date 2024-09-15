const std = @import("std");

pub fn build(b: *std.Build) !void {
    const exe = b.addExecutable(.{
        .name = "main",
        .target = b.host,
        .root_source_file = .{ .cwd_relative = "main.zig" },
    });

    b.installArtifact(exe);
}
