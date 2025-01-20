const std = @import("std");

const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;

const datetime = @import("date_time.zig");

pub const Map = @import("map.zig").Map;
pub const Value = @import("value.zig").Value;
pub const Date = datetime.Date;
pub const Time = datetime.Time;
pub const DateTime = datetime.DateTime;
pub const Timestamp = datetime.Timestamp;
pub const Array = ArrayList(Value);

pub const Type = enum {
    null,
    bool,
    i8,
    i16,
    i32,
    i64,
    i128,
    u8,
    u16,
    u32,
    u64,
    u128,
    f32,
    f64,
    string,
    map,
    array,
    time,
    date,
    datetime,
    timestamp,
};

// gets a typed.Value from a std.json.Value
pub fn fromJson(allocator: Allocator, optional_value: ?std.json.Value) anyerror!Value {
    const value = optional_value orelse {
        return .{ .null = {} };
    };

    switch (value) {
        .null => return .{ .null = {} },
        .bool => |b| return .{ .bool = b },
        .integer => |n| return .{ .i64 = n },
        .float => |f| return .{ .f64 = f },
        .number_string => |s| return .{ .string = s }, // TODO: decide how to handle this
        .string => |s| return .{ .string = s },
        .array => |arr| {
            var ta = Array.init(allocator);
            try ta.ensureTotalCapacity(arr.items.len);
            for (arr.items) |json_value| {
                ta.appendAssumeCapacity(try fromJson(allocator, json_value));
            }
            return .{ .array = ta };
        },
        .object => |obj| return .{ .map = try Map.fromJson(allocator, obj) },
    }
}

pub fn new(allocator: Allocator, value: anytype) !Value {
    const T = @TypeOf(value);
    switch (@typeInfo(T)) {
        .null => return .{ .null = {} },
        .int => |int| {
            if (int.signedness == .signed) {
                switch (int.bits) {
                    1...8 => return .{ .i8 = value },
                    9...16 => return .{ .i16 = value },
                    17...32 => return .{ .i32 = value },
                    33...64 => return .{ .i64 = value },
                    65...128 => return .{ .i128 = value },
                    else => return error.UnsupportedValueType,
                }
            } else {
                switch (int.bits) {
                    1...8 => return .{ .u8 = value },
                    9...16 => return .{ .u16 = value },
                    17...32 => return .{ .u32 = value },
                    33...64 => return .{ .u64 = value },
                    65...128 => return .{ .u128 = value },
                    else => return error.UnsupportedValueType,
                }
            }
        },
        .float => |float| {
            switch (float.bits) {
                1...32 => return .{ .f32 = value },
                33...64 => return .{ .f64 = value },
                else => return error.UnsupportedValueType,
            }
        },
        .bool => return .{ .bool = value },
        .comptime_int => return .{ .i64 = value },
        .comptime_float => return .{ .f64 = value },
        .pointer => |ptr| switch (ptr.size) {
            .one => switch (@typeInfo(ptr.child)) {
                .array => {
                    const Slice = []const std.meta.Elem(ptr.child);
                    return new(allocator, @as(Slice, value));
                },
                else => return new(allocator, value.*),
            }
                .Many,
            .slice => {
                if (ptr.size == .many and ptr.sentinel_ptr == null) {
                    return error.UnsupportedValueTypeA;
                }
                const slice = if (ptr.size == .many) std.mem.span(value) else value;
                const child = ptr.child;
                if (child == u8) return .{ .string = slice };

                var arr = Array.init(allocator);
                try arr.ensureTotalCapacity(slice.len);
                for (slice) |v| {
                    arr.appendAssumeCapacity(try new(allocator, v));
                }
                return .{ .array = arr };
            },
            else => return error.UnsupportedValueTypeC,
        },
        .array => return new(allocator, &value),
        .@"struct" => |s| {
            if (T == Map) return .{ .map = value };
            if (T == Array) return .{ .array = value };
            if (T == Date) return .{ .date = value };
            if (T == Time) return .{ .time = value };
            if (T == DateTime) return .{ .datetime = value };
            if (T == Timestamp) return .{ .timestamp = value };

            var m = Map.init(allocator);
            try m.ensureTotalCapacity(s.fields.len);
            inline for (s.fields) |field| {
                try m.putAssumeCapacity(field.name, @field(value, field.name));
            }
            return .{ .map = m };
        },
        .optional => |opt| {
            if (value) |v| {
                return new(allocator, @as(opt.child, v));
            }
            return .{ .null = {} };
        },
        .@"union" => {
            if (T == Value) {
                return value;
            }
            return error.UnsupportedValueType;
        },
        else => return error.UnsupportedValueType,
    }
}

const t = @import("t.zig");
test "typed: new" {
    try t.expectEqual(true, (try new(undefined, true)).bool);
    try t.expectEqual(@as(i64, 33), (try new(undefined, 33)).i64);
    try t.expectEqual(@as(i32, -88811123), (try new(undefined, @as(i32, -88811123))).i32);
    try t.expectString("over 9000", (try new(undefined, "over 9000")).string);

    {
        var list = std.ArrayList(u8).init(t.allocator);
        defer list.deinit();
        try list.appendSlice("i love keemun");
        try t.expectString("i love keemun", (try new(undefined, list.items)).string);
    }

    {
        var m = (try new(t.allocator, .{ .name = "Leto", .location = .{ .birth = "Caladan", .present = "Arrakis" }, .age = 3000 })).map;
        defer m.deinit();
        try t.expectEqual(3000, m.get("age").?.i64);
        try t.expectString("Caladan", m.get("location").?.map.get("birth").?.string);
        try t.expectString("Arrakis", m.get("location").?.map.get("present").?.string);
        try t.expectString("Leto", m.get("name").?.string);
    }

    {
        var l = (try new(t.allocator, [3]i32{ -32, 38181354, -984 })).array;
        defer l.deinit();
        try t.expectEqual(3, l.items.len);
        try t.expectEqual(-32, l.items[0].i32);
        try t.expectEqual(38181354, l.items[1].i32);
        try t.expectEqual(-984, l.items[2].i32);
    }
}

test "typed: fromJson" {
    const json = std.json;

    try t.expectEqual(Value{ .null = {} }, try fromJson(undefined, null));
    try t.expectEqual(Value{ .null = {} }, try fromJson(undefined, json.Value{ .null = {} }));
    try t.expectEqual(Value{ .bool = true }, try fromJson(undefined, json.Value{ .bool = true }));
    try t.expectEqual(Value{ .i64 = 110 }, try fromJson(undefined, json.Value{ .integer = 110 }));
    try t.expectEqual(Value{ .f64 = 2.223 }, try fromJson(undefined, json.Value{ .float = 2.223 }));
    try t.expectEqual(Value{ .string = "teg atreides" }, try fromJson(undefined, json.Value{ .string = "teg atreides" }));

    {
        var json_array = json.Array.init(t.allocator);
        defer json_array.deinit();
        try json_array.append(.{ .bool = false });
        try json_array.append(.{ .float = -3.4 });

        var ta = (try fromJson(t.allocator, json.Value{ .array = json_array })).array;
        defer ta.deinit();
        try t.expectEqual(Value{ .bool = false }, ta.items[0]);
        try t.expectEqual(Value{ .f64 = -3.4 }, ta.items[1]);
    }

    {
        var json_object1 = json.ObjectMap.init(t.allocator);
        defer json_object1.deinit();

        var json_object2 = json.ObjectMap.init(t.allocator);
        defer json_object2.deinit();
        try json_object2.put("k3", json.Value{ .float = 0.3211 });

        var json_array = json.Array.init(t.allocator);
        defer json_array.deinit();
        try json_array.append(.{ .bool = true });
        try json_array.append(.{ .object = json_object2 });

        try json_object1.put("k1", json.Value{ .integer = 33 });
        try json_object1.put("k2", json.Value{ .array = json_array });

        var tm = (try fromJson(t.allocator, json.Value{ .object = json_object1 })).map;
        defer tm.deinit();
        try t.expectEqual(2, tm.count());
        try t.expectEqual(33, tm.get("k1").?.i64);

        var ta = tm.get("k2").?.array;
        try t.expectEqual(true, ta.items[0].mustGet(bool));
        try t.expectEqual(0.3211, ta.items[1].mustGet(Map).get("k3").?.f64);
    }
}
