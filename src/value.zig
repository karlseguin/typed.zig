const std = @import("std");
const typed = @import("typed.zig");

const Map = typed.Map;
const Type = typed.Type;
const Time = typed.Time;
const Date = typed.Date;
const Array = typed.Array;
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
	timestamp: Timestamp,

	pub fn deinit(self: Value) void {
		switch (self) {
			.array => |arr| {
				for (arr.items) |child| {
					child.deinit();
				}
				arr.deinit();
			},
			.map => |map| {
				var tm = map;
				tm.deinit();
			},
			inline else => {},
		}
	}

	pub fn get(self: Value, comptime T: type) optionalReturnType(T) {
		return self.strictGet(T) catch return null;
	}

	pub fn strictGet(self: Value, comptime T: type) !returnType(T) {
		switch (@typeInfo(T)) {
			.Optional => |opt| {
				switch (self) {
					.null => return null,
					else => return try self.strictGet(opt.child),
				}
			},
			else => {},
		}

		switch (T) {
			[]u8, []const u8 => switch (self) {.string => |v| return v, else => {}},
			i8 => switch (self) {.i8 => |v| return v, else => {}},
			i16 => switch (self) {.i16 => |v| return v, else => {}},
			i32 => switch (self) {.i32 => |v| return v, else => {}},
			i64 => switch (self) {.i64 => |v| return v, else => {}},
			i128 => switch (self) {.i128 => |v| return v, else => {}},
			u8 => switch (self) {.u8 => |v| return v, else => {}},
			u16 => switch (self) {.u16 => |v| return v, else => {}},
			u32 => switch (self) {.u32 => |v| return v, else => {}},
			u64 => switch (self) {.u64 => |v| return v, else => {}},
			u128 => switch (self) {.u128 => |v| return v, else => {}},
			f32 => switch (self) {.f32 => |v| return v, else => {}},
			f64 => switch (self) {.f64 => |v| return v, else => {}},
			bool => switch (self) {.bool => |v| return v, else => {}},
			Map => switch (self) {.map => |v| return v, else => {}},
			Array => switch (self) {.array => |v| return v, else => {}},
			Time => switch (self) {.time => |v| return v, else => {}},
			Date => switch (self) {.date => |v| return v, else => {}},
			Timestamp => switch (self) {.timestamp => |v| return v, else => {}},
			else => |other| @compileError("Unsupported type: " ++ @typeName(other)),
		}
		return error.WrongType;
	}

	pub fn mustGet(self: Value, comptime T: type) returnType(T) {
		return self.get(T) orelse unreachable;
	}

	pub fn isNull(self: Value) bool {
		return switch (self) {
			.null => true,
			else => false
		};
	}

	pub fn jsonStringify(self: Value, options: std.json.StringifyOptions, out: anytype) anyerror!void {
		switch (self) {
			.null => return out.writeAll("null"),
			.bool => |v| return out.writeAll(if (v) "true" else "false"),
			.i8 => |v| return std.fmt.formatInt(v, 10, .lower, .{}, out),
			.i16 => |v| return std.fmt.formatInt(v, 10, .lower, .{}, out),
			.i32 => |v| return std.fmt.formatInt(v, 10, .lower, .{}, out),
			.i64 => |v| return std.fmt.formatInt(v, 10, .lower, .{}, out),
			.i128 => |v| return std.fmt.formatInt(v, 10, .lower, .{}, out),
			.u8 => |v| return std.fmt.formatInt(v, 10, .lower, .{}, out),
			.u16 => |v| return std.fmt.formatInt(v, 10, .lower, .{}, out),
			.u32 => |v| return std.fmt.formatInt(v, 10, .lower, .{}, out),
			.u64 => |v| return std.fmt.formatInt(v, 10, .lower, .{}, out),
			.u128 => |v| return std.fmt.formatInt(v, 10, .lower, .{}, out),
			.f32 => |v| return std.fmt.formatFloatDecimal(v, .{}, out),
			.f64 => |v| return std.fmt.formatFloatDecimal(v, .{}, out),
			.string => |v| return std.json.encodeJsonString(v, options, out),
			.map => |v| return v.jsonStringify(options, out),
			.array => |arr| {
				try out.writeByte('[');
				const items = arr.items;
				if (items.len > 0) {
					try items[0].jsonStringify(options, out);
					for (items[1..]) |v| {
						try out.writeByte(',');
						try v.jsonStringify(options, out);
					}
				}
				try out.writeByte(']');
			},
			.timestamp => |v| return std.fmt.formatIntValue(v.micros, "", .{}, out),
			.time => |v| return v.jsonStringify(options, out),
			.date => |v| return v.jsonStringify(options, out),
		}
	}

	pub fn write(self: Value, writer: anytype) !void {
		switch (self) {
			.string => |v| return writer.writeAll(v),
			inline else => |v| {
				if (comptime std.meta.trait.hasFn("format")(@TypeOf(v))) {
					return v.format("", .{}, writer);
				} else {
					return self.jsonStringify(.{}, writer);
				}
			}
		}
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
				const n = std.fmt.formatIntBuf(&buf, v, 10, .lower, .{});
				return allocator.dupe(u8, buf[0..n]);
			},
			.i16 => |v| {
				const n = std.fmt.formatIntBuf(&buf, v, 10, .lower, .{});
				return allocator.dupe(u8, buf[0..n]);
			},
			.i32 => |v| {
				const n = std.fmt.formatIntBuf(&buf, v, 10, .lower, .{});
				return allocator.dupe(u8, buf[0..n]);
			},
			.i64 => |v| {
				const n = std.fmt.formatIntBuf(&buf, v, 10, .lower, .{});
				return allocator.dupe(u8, buf[0..n]);
			},
			.i128 => |v| {
				const n = std.fmt.formatIntBuf(&buf, v, 10, .lower, .{});
				return allocator.dupe(u8, buf[0..n]);
			},
			.u8 => |v| {
				const n = std.fmt.formatIntBuf(&buf, v, 10, .lower, .{});
				return allocator.dupe(u8, buf[0..n]);
			},
			.u16 => |v| {
				const n = std.fmt.formatIntBuf(&buf, v, 10, .lower, .{});
				return allocator.dupe(u8, buf[0..n]);
			},
			.u32 => |v| {
				const n = std.fmt.formatIntBuf(&buf, v, 10, .lower, .{});
				return allocator.dupe(u8, buf[0..n]);
			},
			.u64 => |v| {
				const n = std.fmt.formatIntBuf(&buf, v, 10, .lower, .{});
				return allocator.dupe(u8, buf[0..n]);
			},
			.u128 => |v| {
				const n = std.fmt.formatIntBuf(&buf, v, 10, .lower, .{});
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
			else => return error.NotAString,
		}
	}

	// hack so that we can call:
	//    get([]u8, "somekey")
	// instead of the more verbose:
	//    get([]const u8, "somekey")
	// In both cases, []const u8 is returned.
	pub fn returnType(comptime T: type) type {
		return switch (T) {
			[]u8 => []const u8,
			?[]u8 => ?[]const u8,
			else => T
		};
	}

	// Some functions, like get, always return an optional type.
	// but if we just define the type as `?T`, if the user asks does map.get(?u32, "key")
	// then the return type will be ??T, which is not what we want.
	// When T is an optional (e.g. ?u32), this returns T
	// When T is not an optional (e.g. u32). this returns ?T
	pub fn optionalReturnType(comptime T: type) type {
		return switch (@typeInfo(T)) {
			.Optional => |o| returnType(o.child),
			else => returnType(?T),
		};
	}
};

const t = @import("t.zig");
test "value: write" {
	const new = typed.new;

	var buf = std.ArrayList(u8).init(t.allocator);
	defer buf.deinit();

	{
		try (try new(undefined, @as(i8, -32))).write(buf.writer());
		try t.expectString("-32", buf.items);
	}

	{
		buf.clearRetainingCapacity();
		try (try new(undefined, null)).write(buf.writer());
		try t.expectString("null", buf.items);
	}

	{
		buf.clearRetainingCapacity();
		try (try new(undefined, "Hello World")).write(buf.writer());
		try t.expectString("Hello World", buf.items);
	}

	{
		buf.clearRetainingCapacity();
		var value = try new(t.allocator, [_]f64{1.1, 2.2, -3.3});
		defer value.deinit();
		try value.write(buf.writer());
		try t.expectString("[1.1,2.2,-3.3]", buf.items);
	}

	{
		buf.clearRetainingCapacity();
		var value = try new(t.allocator, .{.over = 9000});
		defer value.deinit();
		try value.write(buf.writer());
		try t.expectString("{\"over\":9000}", buf.items);
	}

	{
		buf.clearRetainingCapacity();
		var value = try new(t.allocator, try Time.parse("18:12:33"));
		defer value.deinit();
		try value.write(buf.writer());
		try t.expectString("18:12:33", buf.items);
	}

	{
		buf.clearRetainingCapacity();
		var value = try new(t.allocator, try Date.parse("2023-06-26"));
		defer value.deinit();
		try value.write(buf.writer());
		try t.expectString("2023-06-26", buf.items);
	}
}

test "value: toString" {
	{
		var str = try (Value{.i8 = -32}).toString(t.allocator, .{});
		defer t.allocator.free(str);
		try t.expectString("-32", str);
	}

	{
		var str = try (Value{.f64 = -392932.1992321382}).toString(t.allocator, .{});
		defer t.allocator.free(str);
		try t.expectString("-392932.1992321382", str);
	}

	{ //null
		{
			var str = try (Value{.null = {}}).toString(t.allocator, .{});
			defer t.allocator.free(str);
			try t.expectString("null", str);
		}
		{
			var str = try (Value{.null = {}}).toString(t.allocator, .{.force_dupe = false});
			try t.expectString("null", str);
		}
	}

	{ //bool
		{
			var str = try (Value{.bool = true}).toString(t.allocator, .{});
			defer t.allocator.free(str);
			try t.expectString("true", str);
		}
		{
			var str = try (Value{.bool = false}).toString(t.allocator, .{.force_dupe = false});
			try t.expectString("false", str);
		}
	}

	{ // string
		{
			var str = try (Value{.string = "hello"}).toString(t.allocator, .{});
			defer t.allocator.free(str);
			try t.expectString("hello", str);
		}

		{
			var str = try (Value{.string = "hello2"}).toString(t.allocator, .{.force_dupe = false});
			try t.expectString("hello2", str);
		}
	}

	{
		var value = try typed.new(t.allocator, [_]f64{1.1, 2.2, -3.3});
		defer value.deinit();
		try t.expectError(error.NotAString, value.toString(undefined, .{}));
	}

	// {
	// 	buf.clearRetainingCapacity();
	// 	var value = try new(t.allocator, .{.over = 9000});
	// 	defer value.deinit();
	// 	try value.write(buf.writer());
	// 	try t.expectString("{\"over\":9000}", buf.items);
	// }

	// {
	// 	buf.clearRetainingCapacity();
	// 	var value = try new(t.allocator, try Time.parse("18:12:33"));
	// 	defer value.deinit();
	// 	try value.write(buf.writer());
	// 	try t.expectString("18:12:33", buf.items);
	// }

	// {
	// 	buf.clearRetainingCapacity();
	// 	var value = try new(t.allocator, try Date.parse("2023-06-26"));
	// 	defer value.deinit();
	// 	try value.write(buf.writer());
	// 	try t.expectString("2023-06-26", buf.items);
	// }
}
