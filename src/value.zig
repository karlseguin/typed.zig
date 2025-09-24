const std = @import("std");
const json = std.json;

const typed = @import("typed.zig");

const Map = typed.Map;
const Type = typed.Type;
const Time = typed.Time;
const Date = typed.Date;
const Array = typed.Array;
const DateTime = typed.DateTime;
const Timestamp = typed.Timestamp;
const Allocator = std.mem.Allocator;

pub const Value = union(Type) {
    null,
    bool: bool,
    i8: i8,
    i16: i16,
    i32: i32,
    i64: i64,
    i128: i128,
    u8: u8,
    u16: u16,
    u32: u32,
    u64: u64,
    u128: u128,
    f32: f32,
    f64: f64,
    string: []const u8,
    map: Map,
    array: Array,
    time: Time,
    date: Date,
    datetime: DateTime,
    timestamp: Timestamp,

    pub fn deinit(self: Value) void {
        switch (self) {
            .array => |arr| {
                for (arr.items) |child| {
                    child.deinit();
                }
                var mutable_arr = arr;
                mutable_arr.deinit(t.allocator);
            },
            .map => |map| {
                var tm = map;
                tm.deinit();
            },
            inline else => {},
        }
    }

    pub fn get(self: Value, comptime T: type) OptionalReturnType(T) {
        return self.strictGet(T) catch return null;
    }

    pub fn strictGet(self: Value, comptime T: type) !T {
        switch (@typeInfo(T)) {
            .optional => |opt| {
                switch (self) {
                    .null => return null,
                    else => return try self.strictGet(opt.child),
                }
            },
            else => {},
        }

        switch (T) {
            []u8, []const u8 => switch (self) {
                .string => |v| return v,
                else => {},
            },
            i8 => switch (self) {
                .i8 => |v| return v,
                else => {},
            },
            i16 => switch (self) {
                .i16 => |v| return v,
                else => {},
            },
            i32 => switch (self) {
                .i32 => |v| return v,
                else => {},
            },
            i64 => switch (self) {
                .i64 => |v| return v,
                else => {},
            },
            i128 => switch (self) {
                .i128 => |v| return v,
                else => {},
            },
            u8 => switch (self) {
                .u8 => |v| return v,
                else => {},
            },
            u16 => switch (self) {
                .u16 => |v| return v,
                else => {},
            },
            u32 => switch (self) {
                .u32 => |v| return v,
                else => {},
            },
            u64 => switch (self) {
                .u64 => |v| return v,
                else => {},
            },
            u128 => switch (self) {
                .u128 => |v| return v,
                else => {},
            },
            f32 => switch (self) {
                .f32 => |v| return v,
                else => {},
            },
            f64 => switch (self) {
                .f64 => |v| return v,
                else => {},
            },
            bool => switch (self) {
                .bool => |v| return v,
                else => {},
            },
            Map => switch (self) {
                .map => |v| return v,
                else => {},
            },
            Array => switch (self) {
                .array => |v| return v,
                else => {},
            },
            Time => switch (self) {
                .time => |v| return v,
                else => {},
            },
            Date => switch (self) {
                .date => |v| return v,
                else => {},
            },
            DateTime => switch (self) {
                .datetime => |v| return v,
                else => {},
            },
            Timestamp => switch (self) {
                .timestamp => |v| return v,
                else => {},
            },
            else => |other| @compileError("Unsupported type: " ++ @typeName(other)),
        }
        return error.WrongType;
    }

    pub fn mustGet(self: Value, comptime T: type) T {
        return self.get(T) orelse unreachable;
    }

    pub fn isNull(self: Value) bool {
        return switch (self) {
            .null => true,
            else => false,
        };
    }

    pub fn jsonStringify(self: Value, out: anytype) !void {
        switch (self) {
            .null => return out.print("null", .{}),
            .bool => |v| return out.print("{s}", .{if (v) "true" else "false"}),
            .i8 => |v| {
                var buf: [4]u8 = undefined;
                var stream = std.io.fixedBufferStream(&buf);
                std.fmt.format(stream.writer(), "{d}", .{v}) catch unreachable;
                const n = stream.getWritten().len;
                try out.print("{s}", .{buf[0..n]});
            },
            .i16 => |v| {
                var buf: [6]u8 = undefined;
                var stream = std.io.fixedBufferStream(&buf);
                std.fmt.format(stream.writer(), "{d}", .{v}) catch unreachable;
                const n = stream.getWritten().len;
                try out.print("{s}", .{buf[0..n]});
            },
            .i32 => |v| {
                var buf: [11]u8 = undefined;
                var stream = std.io.fixedBufferStream(&buf);
                std.fmt.format(stream.writer(), "{d}", .{v}) catch unreachable;
                const n = stream.getWritten().len;
                try out.print("{s}", .{buf[0..n]});
            },
            .i64 => |v| {
                var buf: [21]u8 = undefined;
                var stream = std.io.fixedBufferStream(&buf);
                std.fmt.format(stream.writer(), "{d}", .{v}) catch unreachable;
                const n = stream.getWritten().len;
                try out.print("{s}", .{buf[0..n]});
            },
            .i128 => |v| {
                var buf: [40]u8 = undefined;
                var stream = std.io.fixedBufferStream(&buf);
                std.fmt.format(stream.writer(), "{d}", .{v}) catch unreachable;
                const n = stream.getWritten().len;
                try out.print("{s}", .{buf[0..n]});
            },
            .u8 => |v| {
                var buf: [3]u8 = undefined;
                var stream = std.io.fixedBufferStream(&buf);
                std.fmt.format(stream.writer(), "{d}", .{v}) catch unreachable;
                const n = stream.getWritten().len;
                try out.print("{s}", .{buf[0..n]});
            },
            .u16 => |v| {
                var buf: [5]u8 = undefined;
                var stream = std.io.fixedBufferStream(&buf);
                std.fmt.format(stream.writer(), "{d}", .{v}) catch unreachable;
                const n = stream.getWritten().len;
                try out.print("{s}", .{buf[0..n]});
            },
            .u32 => |v| {
                var buf: [10]u8 = undefined;
                var stream = std.io.fixedBufferStream(&buf);
                std.fmt.format(stream.writer(), "{d}", .{v}) catch unreachable;
                const n = stream.getWritten().len;
                try out.print("{s}", .{buf[0..n]});
            },
            .u64 => |v| {
                var buf: [20]u8 = undefined;
                var stream = std.io.fixedBufferStream(&buf);
                std.fmt.format(stream.writer(), "{d}", .{v}) catch unreachable;
                const n = stream.getWritten().len;
                try out.print("{s}", .{buf[0..n]});
            },
            .u128 => |v| {
                var buf: [39]u8 = undefined;
                var stream = std.io.fixedBufferStream(&buf);
                std.fmt.format(stream.writer(), "{d}", .{v}) catch unreachable;
                const n = stream.getWritten().len;
                try out.print("{s}", .{buf[0..n]});
            },
            .f32 => |v| try out.print("{d}", .{v}),
            .f64 => |v| try out.print("{d}", .{v}),
            .timestamp => |v| {
                var buf: [20]u8 = undefined;
                var stream = std.io.fixedBufferStream(&buf);
                std.fmt.format(stream.writer(), "{d}", .{v.micros}) catch unreachable;
                const n = stream.getWritten().len;
                try out.print("{s}", .{buf[0..n]});
            },
            .array => |arr| {
                try out.beginArray();
                const items = arr.items;
                if (items.len > 0) {
                    try out.write(items[0]);
                    for (items[1..]) |v| {
                        try out.write(v);
                    }
                }
                try out.endArray();
            },
            inline else => |v| return out.write(v),
        }
    }

    pub fn jsonParse(allocator: Allocator, source: anytype, options: json.ParseOptions) json.ParseError(@TypeOf(source.*))!Value {
        const token = try source.nextAlloc(allocator, .alloc_if_needed);
        return jsonTokenToValue(allocator, source, options, token);
    }

    // For null, bool and string, toString() doesn't require any allocations. But
    // our caller might not know this and if we don't allocate, but they call free
    // they'll crash. By default, we'll dupe everything, so that callers can safely
    //    str = value.toString(allocator);
    //    defer allocator.free(str);
    //
    // For more aware callers, they can specify {.force_dupe = false} and then
    // deal with the fact that the returned string may or may not be a dupe.
    // (the most likely way to "deal" with this is for allocator to come from an
    // arena, in which case, allocator.free(str) is never called)
    pub const ToStringOptions = struct {
        force_dupe: bool = true,
    };

    pub fn toString(self: Value, allocator: Allocator, opts: ToStringOptions) ![]const u8 {
        var buf: [40]u8 = undefined;
        switch (self) {
            .string => |v| return if (opts.force_dupe) allocator.dupe(u8, v) else v,
            .null => return if (opts.force_dupe) allocator.dupe(u8, "null") else "null",
            .bool => |v| {
                const b = if (v) "true" else "false";
                return if (opts.force_dupe) allocator.dupe(u8, b) else b;
            },
            .i8 => |v| {
                var stream = std.io.fixedBufferStream(&buf);
                std.fmt.format(stream.writer(), "{d}", .{v}) catch unreachable;
                const n = stream.getWritten().len;
                return allocator.dupe(u8, buf[0..n]);
            },
            .i16 => |v| {
                var stream = std.io.fixedBufferStream(&buf);
                std.fmt.format(stream.writer(), "{d}", .{v}) catch unreachable;
                const n = stream.getWritten().len;
                return allocator.dupe(u8, buf[0..n]);
            },
            .i32 => |v| {
                var stream = std.io.fixedBufferStream(&buf);
                std.fmt.format(stream.writer(), "{d}", .{v}) catch unreachable;
                const n = stream.getWritten().len;
                return allocator.dupe(u8, buf[0..n]);
            },
            .i64 => |v| {
                var stream = std.io.fixedBufferStream(&buf);
                std.fmt.format(stream.writer(), "{d}", .{v}) catch unreachable;
                const n = stream.getWritten().len;
                return allocator.dupe(u8, buf[0..n]);
            },
            .i128 => |v| {
                var stream = std.io.fixedBufferStream(&buf);
                std.fmt.format(stream.writer(), "{d}", .{v}) catch unreachable;
                const n = stream.getWritten().len;
                return allocator.dupe(u8, buf[0..n]);
            },
            .u8 => |v| {
                var stream = std.io.fixedBufferStream(&buf);
                std.fmt.format(stream.writer(), "{d}", .{v}) catch unreachable;
                const n = stream.getWritten().len;
                return allocator.dupe(u8, buf[0..n]);
            },
            .u16 => |v| {
                var stream = std.io.fixedBufferStream(&buf);
                std.fmt.format(stream.writer(), "{d}", .{v}) catch unreachable;
                const n = stream.getWritten().len;
                return allocator.dupe(u8, buf[0..n]);
            },
            .u32 => |v| {
                var stream = std.io.fixedBufferStream(&buf);
                std.fmt.format(stream.writer(), "{d}", .{v}) catch unreachable;
                const n = stream.getWritten().len;
                return allocator.dupe(u8, buf[0..n]);
            },
            .u64 => |v| {
                var stream = std.io.fixedBufferStream(&buf);
                std.fmt.format(stream.writer(), "{d}", .{v}) catch unreachable;
                const n = stream.getWritten().len;
                return allocator.dupe(u8, buf[0..n]);
            },
            .u128 => |v| {
                var stream = std.io.fixedBufferStream(&buf);
                std.fmt.format(stream.writer(), "{d}", .{v}) catch unreachable;
                const n = stream.getWritten().len;
                return allocator.dupe(u8, buf[0..n]);
            },
            .f32 => |v| return try std.fmt.allocPrint(allocator, "{d}", .{v}),
            .f64 => |v| return try std.fmt.allocPrint(allocator, "{d}", .{v}),
            .time => |v| {
                var stream = std.io.fixedBufferStream(&buf);
                try v.format("{s}", .{}, stream.writer());
                return allocator.dupe(u8, stream.getWritten());
            },
            .date => |v| {
                var stream = std.io.fixedBufferStream(&buf);
                try v.format("{s}", .{}, stream.writer());
                return allocator.dupe(u8, stream.getWritten());
            },
            .datetime => |v| {
                var stream = std.io.fixedBufferStream(&buf);
                try v.format("{s}", .{}, stream.writer());
                return allocator.dupe(u8, stream.getWritten());
            },
            .timestamp => |v| {
                var stream = std.io.fixedBufferStream(&buf);
                std.fmt.format(stream.writer(), "{d}", .{v.micros}) catch unreachable;
                const n = stream.getWritten().len;
                return allocator.dupe(u8, buf[0..n]);
            },
            .map, .array => return error.NotAString,
        }
    }

    pub const WriteOpts = struct {
        null_value: []const u8 = "null",
    };

    pub fn write(self: Value, writer: anytype, opts: WriteOpts) !void {
        switch (self) {
            .string => |v| return writer.writeAll(v),
            .null => return writer.writeAll(opts.null_value),
            .bool => |v| return writer.writeAll(if (v) "true" else "false"),
            .i8 => |v| return std.fmt.format(writer, "{d}", .{v}),
            .i16 => |v| return std.fmt.format(writer, "{d}", .{v}),
            .i32 => |v| return std.fmt.format(writer, "{d}", .{v}),
            .i64 => |v| return std.fmt.format(writer, "{d}", .{v}),
            .i128 => |v| return std.fmt.format(writer, "{d}", .{v}),
            .u8 => |v| return std.fmt.format(writer, "{d}", .{v}),
            .u16 => |v| return std.fmt.format(writer, "{d}", .{v}),
            .u32 => |v| return std.fmt.format(writer, "{d}", .{v}),
            .u64 => |v| return std.fmt.format(writer, "{d}", .{v}),
            .u128 => |v| return std.fmt.format(writer, "{d}", .{v}),
            .f32 => |v| return std.fmt.format(writer, "{d}", .{v}),
            .f64 => |v| return std.fmt.format(writer, "{d}", .{v}),
            .time => |v| return v.format("", .{}, writer),
            .date => |v| return v.format("", .{}, writer),
            .datetime => |v| return v.format("", .{}, writer),
            .timestamp => |v| return std.fmt.format(writer, "{d}", .{v.micros}),
            .map, .array => return error.NotAString,
        }
    }

    // Some functions, like get, always return an optional type.
    // but if we just define the type as `?T`, if the user asks does map.get(?u32, "key")
    // then the return type will be ??T, which is not what we want.
    // When T is an optional (e.g. ?u32), this returns T
    // When T is not an optional (e.g. u32). this returns ?T
    pub fn OptionalReturnType(comptime T: type) type {
        return switch (@typeInfo(T)) {
            .optional => |o| o.child,
            else => ?T,
        };
    }
};

fn jsonTokenToValue(allocator: Allocator, source: anytype, options: json.ParseOptions, token: json.Token) !Value {
    switch (token) {
        .allocated_string => |str| return .{ .string = str },
        .string => |str| return .{ .string = try allocator.dupe(u8, str) },
        inline .number, .allocated_number => |str| {
            const result = try parseJsonInteger(str);
            if (result.rest.len == 0) {
                const value = result.value;
                if (result.negative) {
                    return if (value == 0) .{ .f64 = -0.0 } else .{ .i64 = -value };
                }
                return .{ .i64 = value };
            } else {
                return .{ .f64 = std.fmt.parseFloat(f64, str) catch unreachable };
            }
        },
        .null => return .{ .null = {} },
        .true => return .{ .bool = true },
        .false => return .{ .bool = false },
        .object_begin => return .{ .map = try @import("map.zig").mapFromJsonObject(allocator, source, options) },
        .array_begin => return .{ .array = try arrayFromJson(allocator, source, options) },
        else => {
            unreachable;
        },
    }
}

const ParseJsonIntegerResult = struct {
    value: i64,
    negative: bool,
    rest: []const u8,
};

fn parseJsonInteger(str: []const u8) error{InvalidNumber}!ParseJsonIntegerResult {
    std.debug.assert(str.len != 0);

    var pos: usize = 0;
    var negative = false;
    if (str[0] == '-') {
        pos = 1;
        negative = true;
    }

    var n: i64 = 0;
    for (str[pos..]) |b| {
        if (b < '0' or b > '9') {
            break;
        }

        pos += 1;
        {
            n, const overflowed = @mulWithOverflow(n, 10);
            if (overflowed != 0) {
                return error.InvalidNumber;
            }
        }
        {
            n, const overflowed = @addWithOverflow(n, @as(i64, @intCast(b - '0')));
            if (overflowed != 0) {
                return error.InvalidNumber;
            }
        }
    }

    return .{
        .value = n,
        .negative = negative,
        .rest = str[pos..],
    };
}

fn arrayFromJson(allocator: Allocator, source: anytype, options: json.ParseOptions) json.ParseError(@TypeOf(source.*))!Array {
    var arr = Array{};
    errdefer arr.deinit(allocator);

    while (true) {
        const token = try source.nextAlloc(allocator, options.allocate.?);
        switch (token) {
            .array_end => break,
            else => try arr.append(allocator, try jsonTokenToValue(allocator, source, options, token)),
        }
    }
    return arr;
}

const t = @import("t.zig");
test "parseJsonInteger" {
    const assertResult = struct {
        fn assertFn(input: []const u8, expected: ParseJsonIntegerResult) !void {
            const actual = try parseJsonInteger(input);
            try t.expectString(expected.rest, actual.rest);
            try t.expectEqual(expected.value, actual.value);
            try t.expectEqual(expected.negative, actual.negative);
        }
    }.assertFn;

    try assertResult("0", .{ .value = 0, .negative = false, .rest = "" });
    try assertResult("-0", .{ .value = 0, .negative = true, .rest = "" });

    try assertResult("9223372036854775807", .{ .value = 9223372036854775807, .negative = false, .rest = "" });
    try assertResult("-9223372036854775807", .{ .value = 9223372036854775807, .negative = true, .rest = "" });

    try assertResult("0.01", .{ .value = 0, .negative = false, .rest = ".01" });
    try assertResult("-0.992", .{ .value = 0, .negative = true, .rest = ".992" });

    try assertResult("1234.5678", .{ .value = 1234, .negative = false, .rest = ".5678" });
    try assertResult("-9998.8747281", .{ .value = 9998, .negative = true, .rest = ".8747281" });

    try t.expectError(error.InvalidNumber, parseJsonInteger("9223372036854775808"));
}

test "value: toString" {
    {
        const str = try (Value{ .i8 = -32 }).toString(t.allocator, .{});
        defer t.allocator.free(str);
        try t.expectString("-32", str);
    }

    {
        const str = try (Value{ .f64 = -392932.1992321382 }).toString(t.allocator, .{});
        defer t.allocator.free(str);
        try t.expectString("-392932.1992321382", str);
    }

    { //null
        {
            const str = try (Value{ .null = {} }).toString(t.allocator, .{});
            defer t.allocator.free(str);
            try t.expectString("null", str);
        }
        {
            const str = try (Value{ .null = {} }).toString(t.allocator, .{ .force_dupe = false });
            try t.expectString("null", str);
        }
    }

    { //bool
        {
            const str = try (Value{ .bool = true }).toString(t.allocator, .{});
            defer t.allocator.free(str);
            try t.expectString("true", str);
        }
        {
            const str = try (Value{ .bool = false }).toString(t.allocator, .{ .force_dupe = false });
            try t.expectString("false", str);
        }
    }

    { // string
        {
            const str = try (Value{ .string = "hello" }).toString(t.allocator, .{});
            defer t.allocator.free(str);
            try t.expectString("hello", str);
        }

        {
            const str = try (Value{ .string = "hello2" }).toString(t.allocator, .{ .force_dupe = false });
            try t.expectString("hello2", str);
        }
    }

    {
        const value = try typed.new(t.allocator, [_]f64{ 1.1, 2.2, -3.3 });
        defer value.deinit();
        try t.expectError(error.NotAString, value.toString(undefined, .{}));
    }
}

test "value: write" {
    var arr = std.ArrayList(u8){};
    defer arr.deinit(t.allocator);

    {
        try (Value{ .i8 = -32 }).write(arr.writer(t.allocator), .{});
        try t.expectString("-32", arr.items);
    }

    {
        arr.clearRetainingCapacity();
        try (Value{ .f64 = -392932.1992321382 }).write(arr.writer(t.allocator), .{});
        try t.expectString("-392932.1992321382", arr.items);
    }

    { //null
        {
            arr.clearRetainingCapacity();
            try (Value{ .null = {} }).write(arr.writer(t.allocator), .{});
            try t.expectString("null", arr.items);
        }
        {
            arr.clearRetainingCapacity();
            try (Value{ .null = {} }).write(arr.writer(t.allocator), .{ .null_value = "x" });
            try t.expectString("x", arr.items);
        }
    }

    { //bool
        {
            arr.clearRetainingCapacity();
            try (Value{ .bool = true }).write(arr.writer(t.allocator), .{});
            try t.expectString("true", arr.items);
        }
        {
            arr.clearRetainingCapacity();
            try (Value{ .bool = false }).write(arr.writer(t.allocator), .{});
            try t.expectString("false", arr.items);
        }
    }

    {
        // string
        arr.clearRetainingCapacity();
        try (Value{ .string = "hello" }).write(arr.writer(t.allocator), .{});
        try t.expectString("hello", arr.items);
    }

    {
        arr.clearRetainingCapacity();
        const value = try typed.new(t.allocator, [_]f64{ 1.1, 2.2, -3.3 });
        defer value.deinit();
        try t.expectError(error.NotAString, value.write(arr.writer(t.allocator), .{}));
    }
}
