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

const std = @import("std");
const haversine = @import("haversine.zig").haversine;

pub fn main() void {
    const result = haversine(1, 2, 3, 4, 5);
    std.debug.print("It's working {}\n", .{result});
}
