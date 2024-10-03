const std = @import("std");
const lib = @import("haversine.zig");

// not got the time to write a real generic json parser
// going to write something minimal that can extract values from the generated input to use for the following exercises
// writing a proper parser and repeating might be interesting to do later!

const Mode = enum {
    line_start,
    field,
    semi_colon,
    value,
};

const Field = enum {
    x0,
    x1,
    y0,
    y1,
};

fn parseLine(line: []const u8) !?HaversineData {
    var x0: ?f64 = null;
    var y0: ?f64 = null;
    var x1: ?f64 = null;
    var y1: ?f64 = null;
    var mode: Mode = .line_start;
    var field: ?Field = null;
    var field_buf: [2]u8 = undefined;
    var num_buf: [64]u8 = undefined;
    var num_char_count: usize = 0;
    for (line) |char| {
        switch (mode) {
            .line_start => switch (char) {
                '"' => mode = .field,
                else => {},
            },
            .field => switch (char) {
                'x', 'y' => field_buf[0] = char,
                '0', '1' => field_buf[1] = char,
                '"' => {
                    if (std.mem.eql(u8, &field_buf, "x1")) {
                        field = .x1;
                    } else if (std.mem.eql(u8, &field_buf, "x0")) {
                        field = .x0;
                    } else if (std.mem.eql(u8, &field_buf, "y1")) {
                        field = .y1;
                    } else if (std.mem.eql(u8, &field_buf, "y0")) {
                        field = .y0;
                    }
                    mode = .semi_colon;
                },
                else => {},
            },
            .semi_colon => switch (char) {
                ':' => mode = .value,
                else => {},
            },
            .value => switch (char) {
                '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', '.', '-' => {
                    num_buf[num_char_count] = char;
                    num_char_count += 1;
                },
                ' ' => {},
                else => {
                    if (num_char_count > 0) {
                        const num = try std.fmt.parseFloat(f64, num_buf[0..num_char_count]);
                        switch (field.?) {
                            .x0 => x0 = num,
                            .x1 => x1 = num,
                            .y0 => y0 = num,
                            .y1 => y1 = num,
                        }
                    }
                    num_char_count = 0;
                    mode = .line_start;
                },
            },
        }
    }
    if (x0 != null and x1 != null and y0 != null and y1 != null) {
        return HaversineData{ .x0 = x0.?, .y0 = y0.?, .x1 = x1.?, .y1 = y1.? };
    }
    return null;
}

fn parse(allocator: std.mem.Allocator, reader: std.io.AnyReader) ![]HaversineData {
    var result_array_list = std.ArrayList(HaversineData).init(allocator);
    var line_array_list = std.ArrayList(u8).init(allocator);
    while (true) {
        const line_read_result = reader.streamUntilDelimiter(line_array_list.writer(), '\n', null);
        if (line_read_result == error.EndOfStream) {
            break;
        }
        try line_read_result;
        const value = try parseLine(line_array_list.items);
        if (value) |v| {
            try result_array_list.append(v);
        }
        line_array_list.clearAndFree();
    }
    line_array_list.deinit();
    return result_array_list.items;
}

// caller will need to free output
pub fn parseFile(allocator: std.mem.Allocator, filename: []const u8) ![]HaversineData {
    const file = try std.fs.cwd().openFile(filename, .{});
    const reader = file.reader();
    return parse(allocator, reader.any());
}

pub fn haversineSumForFile(allocator: std.mem.Allocator, filename: []const u8) !f64 {
    const data = try parseFile(allocator, filename);
    var result: f64 = 0;
    for (data) |h| {
        result += lib.haversine(h.x0, h.y0, h.x1, h.y1, lib.EARTH_RADIUS_KM);
    }
    return result;
}

pub const HaversineData = struct {
    x0: f64,
    y0: f64,
    x1: f64,
    y1: f64,
};
