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

// NOTE - see https://www.json.org/json-en.html for details of JSON decoding
pub fn parse(allocator: Allocator, reader: *AnyReader) !JsonValue {
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

        // parse string
        if (byte == '"') {
            try parseString(reader, &array_list);
            const output = try allocator.alloc(u8, array_list.items.len);
            std.mem.copyForwards(u8, output, array_list.items);
            // Note - this will need to be freed by caller
            return JsonValue{ .STRING = output };
        }

        // parse object
        if (byte == '{') {
            byte = try reader.readByte();
            while (ascii.isWhitespace(byte)) {
                byte = try reader.readByte();
            }
            while (true) {
                try parseField(reader, &array_list);
                while (ascii.isWhitespace(byte)) {
                    byte = try reader.readByte();
                }
                // TODO - does this need to take a pointer to reader so calling readByte in the recursive call advances the file position here too?
                const value = try parse(allocator, reader);
                _ = value;
            }
        }

        // parse array
        if (byte == '[') {
            // TODO
        }

        try array_list.append(byte);
    }

    return error.InvalidJsonValue;
}

// NOTE - doesn't strictly enforce the json spec. Should correctly parse any valid stri but will also successfully parse invalid strings with newlines in them.
fn parseString(reader: *AnyReader, array_list: *ArrayList(u8)) !void {
    var is_escaped = false;
    var byte = try reader.readByte();
    while (byte != '"' or is_escaped) {
        if (is_escaped) {
            is_escaped = false;
            try array_list.append(switch (byte) {
                'n' => '\n',
                'r' => '\r',
                't' => '\t',
                else => byte, // NOTE - pretty sure this doesn't handle a bunch of escaped characters properly, but hopefully it's good enough for the exercises
            });
        } else if (byte == '\\') {
            is_escaped = true;
        } else if (byte == '"') {
            return;
        } else {
            try array_list.append(byte);
        }
        byte = try reader.readByte();
    }
}

// NOTE - again doesn't enforce the spec, just aims to correctly parse any valid input
fn parseField(reader: *AnyReader, array_list: *ArrayList(u8)) !void {
    var byte = try reader.readByte();
    while (byte != '"') {
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
    var reader = fixedBufferStream.reader().any();
    const result = parse(test_allocator, &reader);
    try expectEqual(JsonValue.NULL, result);
}

test "should parse null whitespace" {
    var input = ArrayList(u8).init(test_allocator);
    defer input.deinit();
    _ = try input.writer().write("null ");

    var fixedBufferStream = std.io.fixedBufferStream(input.items);
    var reader = fixedBufferStream.reader().any();
    const result = parse(test_allocator, &reader);
    try expectEqual(JsonValue.NULL, result);
}

test "should parse true EOS" {
    var input = ArrayList(u8).init(test_allocator);
    defer input.deinit();
    _ = try input.writer().write("true");

    var fixedBufferStream = std.io.fixedBufferStream(input.items);
    var reader = fixedBufferStream.reader().any();
    const result = parse(test_allocator, &reader);
    try expectEqual(JsonValue{ .BOOLEAN = true }, result);
}

test "should parse true whitespace" {
    var input = ArrayList(u8).init(test_allocator);
    defer input.deinit();
    _ = try input.writer().write("true ");

    var fixedBufferStream = std.io.fixedBufferStream(input.items);
    var reader = fixedBufferStream.reader().any();
    const result = parse(test_allocator, &reader);
    try expectEqual(JsonValue{ .BOOLEAN = true }, result);
}

test "should parse false EOS" {
    var input = ArrayList(u8).init(test_allocator);
    defer input.deinit();
    _ = try input.writer().write("false");

    var fixedBufferStream = std.io.fixedBufferStream(input.items);
    var reader = fixedBufferStream.reader().any();
    const result = parse(test_allocator, &reader);
    try expectEqual(JsonValue{ .BOOLEAN = false }, result);
}

test "should parse false whitespace" {
    var input = ArrayList(u8).init(test_allocator);
    defer input.deinit();
    _ = try input.writer().write("false\n");

    var fixedBufferStream = std.io.fixedBufferStream(input.items);
    var reader = fixedBufferStream.reader().any();
    const result = parse(test_allocator, &reader);
    try expectEqual(JsonValue{ .BOOLEAN = false }, result);
}

test "should throw on keyword near miss" {
    var input = ArrayList(u8).init(test_allocator);
    defer input.deinit();
    _ = try input.writer().write("nulll");
    var fixedBufferStream = std.io.fixedBufferStream(input.items);
    var reader = fixedBufferStream.reader().any();
    const result = parse(test_allocator, &reader);
    try expectEqual(ParseError.InvalidKeyword, result);
}

test "should throw on EOS mid keyword" {
    var input = ArrayList(u8).init(test_allocator);
    defer input.deinit();
    _ = try input.writer().write("nul");
    var fixedBufferStream = std.io.fixedBufferStream(input.items);
    var reader = fixedBufferStream.reader().any();
    const result = parse(test_allocator, &reader);
    try expectEqual(ParseError.InvalidKeyword, result);
}

test "should parse int to f64" {
    var input = ArrayList(u8).init(test_allocator);
    defer input.deinit();
    _ = try input.writer().write("123");
    var fixedBufferStream = std.io.fixedBufferStream(input.items);
    var reader = fixedBufferStream.reader().any();
    const result = parse(test_allocator, &reader);
    try expectEqual(JsonValue{ .NUMBER = 123 }, result);
}

test "should parse float to f64" {
    var input = ArrayList(u8).init(test_allocator);
    defer input.deinit();
    _ = try input.writer().write("123.456");
    var fixedBufferStream = std.io.fixedBufferStream(input.items);
    var reader = fixedBufferStream.reader().any();
    const result = parse(test_allocator, &reader);
    try expectEqual(JsonValue{ .NUMBER = 123.456 }, result);
}

test "should parse int with leading zeroes" {
    var input = ArrayList(u8).init(test_allocator);
    defer input.deinit();
    _ = try input.writer().write("0004520");
    var fixedBufferStream = std.io.fixedBufferStream(input.items);
    var reader = fixedBufferStream.reader().any();
    const result = parse(test_allocator, &reader);
    try expectEqual(JsonValue{ .NUMBER = 4520 }, result);
}

test "should parse float with leading zero" {
    var input = ArrayList(u8).init(test_allocator);
    defer input.deinit();
    _ = try input.writer().write("0.258");
    var fixedBufferStream = std.io.fixedBufferStream(input.items);
    var reader = fixedBufferStream.reader().any();
    const result = parse(test_allocator, &reader);
    try expectEqual(JsonValue{ .NUMBER = 0.258 }, result);
}

test "should parse float with leading zeroes" {
    var input = ArrayList(u8).init(test_allocator);
    defer input.deinit();
    _ = try input.writer().write("000003.69");
    var fixedBufferStream = std.io.fixedBufferStream(input.items);
    var reader = fixedBufferStream.reader().any();
    const result = parse(test_allocator, &reader);
    try expectEqual(JsonValue{ .NUMBER = 3.69 }, result);
}

test "should parse float in scientific notation" {
    var input = ArrayList(u8).init(test_allocator);
    defer input.deinit();
    _ = try input.writer().write("2e-2");
    var fixedBufferStream = std.io.fixedBufferStream(input.items);
    var reader = fixedBufferStream.reader().any();
    const result = parse(test_allocator, &reader);
    try expectEqual(JsonValue{ .NUMBER = 0.02 }, result);
}

test "should parse negative number" {
    var input = ArrayList(u8).init(test_allocator);
    defer input.deinit();
    _ = try input.writer().write("-987.654321");
    var fixedBufferStream = std.io.fixedBufferStream(input.items);
    var reader = fixedBufferStream.reader().any();
    const result = parse(test_allocator, &reader);
    try expectEqual(JsonValue{ .NUMBER = -987.654321 }, result);
}

test "should parse string" {
    var input = ArrayList(u8).init(test_allocator);
    defer input.deinit();
    _ = try input.writer().write("\"test\"");
    var fixedBufferStream = std.io.fixedBufferStream(input.items);
    var reader = fixedBufferStream.reader().any();
    const result = try parse(test_allocator, &reader);
    try expect(std.mem.eql(u8, "test", result.STRING));
    test_allocator.free(result.STRING);
}

test "should parse string with whitespace" {
    var input = ArrayList(u8).init(test_allocator);
    defer input.deinit();
    _ = try input.writer().write("\" t e s t \"");
    var fixedBufferStream = std.io.fixedBufferStream(input.items);
    var reader = fixedBufferStream.reader().any();
    const result = try parse(test_allocator, &reader);
    try expect(std.mem.eql(u8, " t e s t ", result.STRING));
    test_allocator.free(result.STRING);
}

test "should parse string with escaped characters" {
    var input = ArrayList(u8).init(test_allocator);
    defer input.deinit();
    _ = try input.writer().write("\"\\n\\t\"");
    var fixedBufferStream = std.io.fixedBufferStream(input.items);
    var reader = fixedBufferStream.reader().any();
    const result = try parse(test_allocator, &reader);
    try expect(std.mem.eql(u8, "\n\t", result.STRING));
    test_allocator.free(result.STRING);
}

test "should parse string with escaped quotation marks in it" {
    var input = ArrayList(u8).init(test_allocator);
    defer input.deinit();
    _ = try input.writer().write("\"left \\\" right\"");
    var fixedBufferStream = std.io.fixedBufferStream(input.items);
    var reader = fixedBufferStream.reader().any();
    const result = try parse(test_allocator, &reader);
    try expect(std.mem.eql(u8, "left \" right", result.STRING));
    test_allocator.free(result.STRING);
}
