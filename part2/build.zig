const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const haversine_lib = b.addStaticLibrary(.{
        .name = "haversine",
        .root_source_file = b.path("haversine.zig"),
        .target = target,
        .optimize = optimize,
    });

    const havergen_exe = b.addExecutable(.{
        .name = "havergen",
        .root_source_file = b.path("havergen.zig"),
        .target = target,
        .optimize = optimize,
    });

    b.installArtifact(haversine_lib);
    b.installArtifact(havergen_exe);
}
