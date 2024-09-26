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

    const output_file_name = std.fmt.allocPrint(allocator, "data_{}_{}.json", .{ seed, pair_count }) catch fatal(null);
    const output_file = std.fs.cwd().createFile(output_file_name, .{}) catch fatal("Failed to open output file");
    allocator.free(output_file_name);

    var rng = std.rand.DefaultPrng.init(seed);
    const rand = rng.random();

    const writer = output_file.writer();
    _ = writer.write("{\"pairs\": [\n") catch fatal(null);
    const min_degrees = rand.float(f64) * (-180);
    const max_degrees = rand.float(f64) * 180;
    std.debug.print("min_degrees: {d:0>3}\nmax_degrees: {d:0>3}", .{ min_degrees, max_degrees });
    for (0..pair_count) |i| {
        const x0 = generatePointInRange(rand, min_degrees, max_degrees);
        const y0 = generatePointInRange(rand, min_degrees, max_degrees) / 2;
        const x1 = generatePointInRange(rand, min_degrees, max_degrees);
        const y1 = generatePointInRange(rand, min_degrees, max_degrees) / 2;
        const line = std.fmt.allocPrint(allocator, "\t{{\"x0\":{d:0>12}, \"y0\":{d:0>12}, \"x1\":{d:0>12}, \"y1\":{d:0>12}}}", .{ x0, y0, x1, y1 }) catch fatal(null);
        _ = writer.write(line) catch fatal(null);
        allocator.free(line);
        if (i < pair_count - 1) {
            _ = writer.write(",\n") catch fatal(null);
        } else {
            _ = writer.write("\n") catch fatal(null);
        }
    }
    _ = writer.write("]}\n") catch fatal(null);
    output_file.close();
}

fn generatePointInRange(rand: std.Random, min: f64, max: f64) f64 {
    return rand.float(f64) * (max - min) + min;
}

fn fatal(message: ?[]const u8) noreturn {
    if (message) |m| {
        const stderr = std.io.getStdErr();
        _ = stderr.write(m) catch {};
        _ = stderr.write("\n") catch {};
    }
    std.process.exit(1);
}
