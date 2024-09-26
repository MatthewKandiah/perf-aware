//
//
// Generate random json input for exercises.
// Must take argument for number of pairs to generate.
// Casey recommends adding some clustering in the data generation, so the randomly generated points don't have a predictable sum / average.
//
//

const std = @import("std");
const haversine = @import("haversine.zig");

pub fn main() void {
    const result = haversine.haversine(1, 2, 3, 4, 5);
    std.debug.print("It's working {}\n", .{result});
}
