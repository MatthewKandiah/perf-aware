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

        // parse object
        if (byte == '{') {
            return parseObject(allocator, reader);
        }

        try array_list.append(byte);
    }

    @panic("Unimplemented");
}

fn parseObject(allocator: Allocator, reader: AnyReader) !JsonValue {
    _ = allocator;
    _ = reader;
    @panic("Unimplemented json object parser");
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
