//
//
// Generate random json input for exercises.
// Must take argument for number of pairs to generate.
// Casey recommends adding some clustering in the data generation, so the randomly generated points don't have a predictable sum / average.
// I also like his suggestion to have the generator print out the expected sum and dumping the expected values to a binary data file for quick debugging and checking.
//
//
// Json schema:
// {
//   "pairs": [
//     "x0": number, "y0": number, "x1": number, "y1": number
//   ]
// }
//
//
// Usage: havergen seed pair_count
// Output: data_{seed}_{pair_count}.json
//
//

const std = @import("std");
const haversine = @import("haversine.zig").haversine;

pub fn main() void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    const args = std.process.argsAlloc(allocator) catch fatal(null);
    defer std.process.argsFree(allocator, args);

    if (args.len != 3) fatal("USAGE: must pass 2 numeric arguments\n```\nhavergen seed num_pairs\n```\n");

    const seed = std.fmt.parseInt(u64, args[1], 10) catch fatal("USAGE: seed argument must be non-negative integer");
    const pair_count = std.fmt.parseInt(u32, args[2], 10) catch fatal("USAGE: pair_count argument must be non-negative integer");

    var rng = std.rand.DefaultPrng.init(seed);
    const rand = rng.random();
    for (0..pair_count) |_| {
        std.debug.print("{}\n", .{rand.float(f64)});
    }
}

fn fatal(message: ?[]const u8) noreturn {
    if (message) |m| {
        const stderr = std.io.getStdErr();
        _ = stderr.write(m) catch {};
        _ = stderr.write("\n") catch {};
    }
    std.process.exit(1);
}
