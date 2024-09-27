const std = @import("std");
const ascii = std.ascii;
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;
const AnyReader = std.io.AnyReader;

// going to assume input is valid ASCII encoding, so a byte is a code point is a character
// avoids the headache of parsing multibyte unicode characters!

pub const ParseError = error{
    InvalidKeyword,
};

// NOTE - planning on passing in an arena allocator, so we'll allocate all the memory we need for recursive calls, then clear the whole lot

// NOTE - see https://www.json.org/json-en.html for details of JSON decoding
pub fn parse(allocator: Allocator, reader: AnyReader) !JsonValue {
    var array_list = ArrayList(u8).init(allocator);
    defer array_list.deinit();
    var maybe_byte = reader.readByte();
    while (maybe_byte != error.EndOfStream) : (maybe_byte = reader.readByte()) {
        var byte = try maybe_byte;
        // skip whitespace
        if (ascii.isWhitespace(byte)) {
            continue;
        }

        // parse keyword
        if (ascii.isAlphabetic(byte)) {
            while (!ascii.isWhitespace(byte)) {
                try array_list.append(byte);
                maybe_byte = reader.readByte();
                if (maybe_byte == error.EndOfStream) {
                    break;
                }
                byte = try maybe_byte;
            }
            const maybe_keyword = array_list.items;
            if (std.mem.eql(u8, maybe_keyword, "null")) {
                return JsonValue.NULL;
            } else if (std.mem.eql(u8, maybe_keyword, "true")) {
                return JsonValue{ .BOOLEAN = true };
            } else if (std.mem.eql(u8, maybe_keyword, "false")) {
                return JsonValue{ .BOOLEAN = false };
            } else {
                return ParseError.InvalidKeyword;
            }
        }

        // parse number
        // NOTE - doesn't strictly enforce the json spec. Should correctly parse any valid number, including scientific notation, but will also successfully parse invalid numbers with unnecessary leading zeroes.
        if (ascii.isDigit(byte) or byte == '-') {
            while (!ascii.isWhitespace(byte)) {
                try array_list.append(byte);
                maybe_byte = reader.readByte();
                if (maybe_byte == error.EndOfStream) {
                    break;
                }
                byte = try maybe_byte;
            }
            const number = try std.fmt.parseFloat(f64, array_list.items);
            return JsonValue{ .NUMBER = number };
        }

        if (byte == '"') {
            try parseString(reader, &array_list);
            const output = try allocator.alloc(u8, array_list.items.len);
            std.mem.copyForwards(u8, output, array_list.items);
            // Note - this will need to be freed by caller
            return JsonValue{ .STRING = output };
        }

        try array_list.append(byte);
    }
    @panic("Unimplemented");
}

// TODO - this will parse escaped character as separate characters
// e.g. \n will be parsed as '\' and 'n', when we want '\n'
// NOTE - doesn't strictly enforce the json spec. Should correctly parse any valid stri but will also successfully parse invalid strings with newlines in them.
fn parseString(reader: AnyReader, array_list: *ArrayList(u8)) !void {
    var byte = try reader.readByte();
    while (byte != '"' or array_list.getLastOrNull() == '\\') {
        try array_list.append(byte);
        byte = try reader.readByte();
    }
}

pub const JsonValueType = enum {
    STRING,
    NUMBER,
    OBJECT,
    ARRAY,
    BOOLEAN,
    NULL,
};

pub const JsonObject = struct {
    keys: [][]const u8,
    values: []JsonValue,
};

pub const JsonValue = union(JsonValueType) {
    STRING: []const u8,
    NUMBER: f64,
    OBJECT: JsonObject,
    ARRAY: []JsonValue,
    BOOLEAN: bool,
    NULL: void,
};

const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const test_allocator = std.testing.allocator;

test "should parse null EOS" {
    var input = ArrayList(u8).init(test_allocator);
    defer input.deinit();
    _ = try input.writer().write("null");

    var fixedBufferStream = std.io.fixedBufferStream(input.items);
    const result = parse(test_allocator, fixedBufferStream.reader().any());
    try expectEqual(JsonValue.NULL, result);
}

test "should parse null whitespace" {
    var input = ArrayList(u8).init(test_allocator);
    defer input.deinit();
    _ = try input.writer().write("null ");

    var fixedBufferStream = std.io.fixedBufferStream(input.items);
    const result = parse(test_allocator, fixedBufferStream.reader().any());
    try expectEqual(JsonValue.NULL, result);
}

test "should parse true EOS" {
    var input = ArrayList(u8).init(test_allocator);
    defer input.deinit();
    _ = try input.writer().write("true");

    var fixedBufferStream = std.io.fixedBufferStream(input.items);
    const result = parse(test_allocator, fixedBufferStream.reader().any());
    try expectEqual(JsonValue{ .BOOLEAN = true }, result);
}

test "should parse true whitespace" {
    var input = ArrayList(u8).init(test_allocator);
    defer input.deinit();
    _ = try input.writer().write("true ");

    var fixedBufferStream = std.io.fixedBufferStream(input.items);
    const result = parse(test_allocator, fixedBufferStream.reader().any());
    try expectEqual(JsonValue{ .BOOLEAN = true }, result);
}

test "should parse false EOS" {
    var input = ArrayList(u8).init(test_allocator);
    defer input.deinit();
    _ = try input.writer().write("false");

    var fixedBufferStream = std.io.fixedBufferStream(input.items);
    const result = parse(test_allocator, fixedBufferStream.reader().any());
    try expectEqual(JsonValue{ .BOOLEAN = false }, result);
}

test "should parse false whitespace" {
    var input = ArrayList(u8).init(test_allocator);
    defer input.deinit();
    _ = try input.writer().write("false\n");

    var fixedBufferStream = std.io.fixedBufferStream(input.items);
    const result = parse(test_allocator, fixedBufferStream.reader().any());
    try expectEqual(JsonValue{ .BOOLEAN = false }, result);
}

test "should throw on keyword near miss" {
    var input = ArrayList(u8).init(test_allocator);
    defer input.deinit();
    _ = try input.writer().write("nulll");
    var fixedBufferStream = std.io.fixedBufferStream(input.items);
    const result = parse(test_allocator, fixedBufferStream.reader().any());
    try expectEqual(ParseError.InvalidKeyword, result);
}

test "should throw on EOS mid keyword" {
    var input = ArrayList(u8).init(test_allocator);
    defer input.deinit();
    _ = try input.writer().write("nul");
    var fixedBufferStream = std.io.fixedBufferStream(input.items);
    const result = parse(test_allocator, fixedBufferStream.reader().any());
    try expectEqual(ParseError.InvalidKeyword, result);
}

test "should parse int to f64" {
    var input = ArrayList(u8).init(test_allocator);
    defer input.deinit();
    _ = try input.writer().write("123");
    var fixedBufferStream = std.io.fixedBufferStream(input.items);
    const result = parse(test_allocator, fixedBufferStream.reader().any());
    try expectEqual(JsonValue{ .NUMBER = 123 }, result);
}

test "should parse float to f64" {
    var input = ArrayList(u8).init(test_allocator);
    defer input.deinit();
    _ = try input.writer().write("123.456");
    var fixedBufferStream = std.io.fixedBufferStream(input.items);
    const result = parse(test_allocator, fixedBufferStream.reader().any());
    try expectEqual(JsonValue{ .NUMBER = 123.456 }, result);
}

test "should parse int with leading zeroes" {
    var input = ArrayList(u8).init(test_allocator);
    defer input.deinit();
    _ = try input.writer().write("0004520");
    var fixedBufferStream = std.io.fixedBufferStream(input.items);
    const result = parse(test_allocator, fixedBufferStream.reader().any());
    try expectEqual(JsonValue{ .NUMBER = 4520 }, result);
}

test "should parse float with leading zero" {
    var input = ArrayList(u8).init(test_allocator);
    defer input.deinit();
    _ = try input.writer().write("0.258");
    var fixedBufferStream = std.io.fixedBufferStream(input.items);
    const result = parse(test_allocator, fixedBufferStream.reader().any());
    try expectEqual(JsonValue{ .NUMBER = 0.258 }, result);
}

test "should parse float with leading zeroes" {
    var input = ArrayList(u8).init(test_allocator);
    defer input.deinit();
    _ = try input.writer().write("000003.69");
    var fixedBufferStream = std.io.fixedBufferStream(input.items);
    const result = parse(test_allocator, fixedBufferStream.reader().any());
    try expectEqual(JsonValue{ .NUMBER = 3.69 }, result);
}

test "should parse float in scientific notation" {
    var input = ArrayList(u8).init(test_allocator);
    defer input.deinit();
    _ = try input.writer().write("2e-2");
    var fixedBufferStream = std.io.fixedBufferStream(input.items);
    const result = parse(test_allocator, fixedBufferStream.reader().any());
    try expectEqual(JsonValue{ .NUMBER = 0.02 }, result);
}

test "should parse negative number" {
    var input = ArrayList(u8).init(test_allocator);
    defer input.deinit();
    _ = try input.writer().write("-987.654321");
    var fixedBufferStream = std.io.fixedBufferStream(input.items);
    const result = parse(test_allocator, fixedBufferStream.reader().any());
    try expectEqual(JsonValue{ .NUMBER = -987.654321 }, result);
}

test "should parse string" {
    var input = ArrayList(u8).init(test_allocator);
    defer input.deinit();
    _ = try input.writer().write("\"test\"");
    var fixedBufferStream = std.io.fixedBufferStream(input.items);
    const result = try parse(test_allocator, fixedBufferStream.reader().any());
    try expect(std.mem.eql(u8, "test", result.STRING));
    test_allocator.free(result.STRING);
}

test "should parse string with whitespace" {
    var input = ArrayList(u8).init(test_allocator);
    defer input.deinit();
    _ = try input.writer().write("\" t e s t \"");
    var fixedBufferStream = std.io.fixedBufferStream(input.items);
    const result = try parse(test_allocator, fixedBufferStream.reader().any());
    try expect(std.mem.eql(u8, " t e s t ", result.STRING));
    test_allocator.free(result.STRING);
}
