const std = @import("std");

const ArrayList = std.ArrayList;
const StringHashMap = std.StringHashMap;
const Allocator = std.mem.Allocator;

const M = @This();

pub const Value = union(enum) {
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
			.i8 => |v| return std.fmt.formatIntValue(v, "", .{}, out),
			.i16 => |v| return std.fmt.formatIntValue(v, "", .{}, out),
			.i32 => |v| return std.fmt.formatIntValue(v, "", .{}, out),
			.i64 => |v| return std.fmt.formatIntValue(v, "", .{}, out),
			.i128 => |v| return std.fmt.formatIntValue(v, "", .{}, out),
			.u8 => |v| return std.fmt.formatIntValue(v, "", .{}, out),
			.u16 => |v| return std.fmt.formatIntValue(v, "", .{}, out),
			.u32 => |v| return std.fmt.formatIntValue(v, "", .{}, out),
			.u64 => |v| return std.fmt.formatIntValue(v, "", .{}, out),
			.u128 => |v| return std.fmt.formatIntValue(v, "", .{}, out),
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
		}
	}
};

pub const Array = ArrayList(Value);

// gets a typed.Value from a std.json.Value
pub fn fromJson(allocator: Allocator, optional_value: ?std.json.Value) anyerror!Value {
	const value = optional_value orelse {
		return .{.null = {}};
	};

	switch (value) {
		.null => return .{.null = {}},
		.bool => |b| return .{.bool = b},
		.integer => |n| return .{.i64 = n},
		.float => |f| return .{.f64 = f},
		.number_string => |s| return .{.string = s}, // TODO: decide how to handle this
		.string => |s| return .{.string = s},
		.array => |arr| {
			var ta = Array.init(allocator);
			try ta.ensureTotalCapacity(arr.items.len);
			for (arr.items) |json_value| {
				ta.appendAssumeCapacity(try fromJson(allocator, json_value));
			}
			return .{.array = ta};
		},
		.object => |obj| return .{.map = try Map.fromJson(allocator, obj)},
	}
}

pub fn new(value: anytype) !Value {
	return newT(@TypeOf(value), value);
}

pub fn newT(comptime T: type, value: anytype) !Value {
	switch (@typeInfo(T)) {
		.Null => return .{.null = {}},
		.Int => |int| {
			if (int.signedness == .signed) {
				switch (int.bits) {
					1...8 => return .{.i8 = value},
					9...16 => return .{.i16 = value},
					17...32 => return .{.i32 = value},
					33...64 => return .{.i64 = value},
					65...128 => return .{.i128 = value},
					else => return error.UnsupportedValueType,
				}
			} else {
				switch (int.bits) {
					1...8 => return .{.u8 = value},
					9...16 => return .{.u16 = value},
					17...32 => return .{.u32 = value},
					33...64 => return .{.u64 = value},
					65...128 => return .{.u128 = value},
					else => return error.UnsupportedValueType,
				}
			}
		},
		.Float => |float| {
			switch (float.bits) {
				1...32 => return .{.f32 = value},
				33...64 => return .{.f64 = value},
				else => return error.UnsupportedValueType,
			}
		},
		.Bool => return .{.bool = value},
		.ComptimeInt => return .{.i64 = value},
		.ComptimeFloat => return .{.f64 = value},
		.Pointer => |ptr| {
			switch (ptr.size) {
				.One => return newT(ptr.child, value),
				.Slice => switch (ptr.child) {
					u8 => return .{.string = value.ptr[0..value.len]},
					else => return error.UnsupportedValueType,
				},
				else => return error.UnsupportedValueType,
			}
		},
		.Array => |arr| {
			switch (arr.child) {
				u8 => return .{.string = value},
				else => return error.UnsupportedValueType,
			}
		},
		.Struct => {
			if (T == Map) {
				return .{.map = value};
			}
			if (T == Array) {
				return .{.array = value};
			}
			return error.UnsupportedValueType;
		},
		.Optional => |opt| {
			if (value) |v| {
				return newT(opt.child, v);
			}
			return .{.null = {}};
		},
		.Union => {
			if (T == Value) {
				return value;
			}
			return error.UnsupportedValueType;
		},
		else => return error.UnsupportedValueType,
	}
}

// hack so that we can call:
//    get([]u8, "somekey")
// instead of the more verbose:
//    get([]const u8, "somekey")
// In both cases, []const u8 is returned.
fn returnType(comptime T: type) type {
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
fn optionalReturnType(comptime T: type) type {
	return switch (@typeInfo(T)) {
		.Optional => |o| returnType(o.child),
		else => returnType(?T),
	};
}

pub const Map = struct {
	m: StringHashMap(Value),

	pub fn init(allocator: Allocator) Map {
		return .{
			.m = StringHashMap(Value).init(allocator),
		};
	}

	pub fn deinit(self: *Map) void {
		var it = self.m.valueIterator();
		while (it.next()) |value| {
			value.deinit();
		}
		self.m.deinit();
	}

	pub fn fromJson(allocator: Allocator, obj: std.json.ObjectMap) !Map {
			var to = init(allocator);
			var map = &to.m;
			try map.ensureTotalCapacity(@intCast(u32, obj.count()));

			var it = obj.iterator();
			while (it.next()) |entry| {
				map.putAssumeCapacity(entry.key_ptr.*, try M.fromJson(allocator, entry.value_ptr.*));
			}
			return to;
	}

	// dangerous!
	pub fn readonlyEmpty() Map {
		return init(undefined);
	}

	pub fn put(self: *Map, key: []const u8, value: anytype) !void {
		return self.putT(@TypeOf(value), key, value);
	}

	pub fn putT(self: *Map, comptime T: type, key: []const u8, value: anytype) !void {
		return self.m.put(key, try newT(T, value));
	}

	pub fn get(self: Map, comptime T: type, key: []const u8) optionalReturnType(T) {
		if (self.m.get(key)) |v| {
			return v.get(T);
		}
		return null;
	}

	pub fn mustGet(self: Map, comptime T: type, key: []const u8) returnType(T) {
		return self.get(T, key) orelse unreachable;
	}

	pub fn strictGet(self: Map, comptime T: type, key: []const u8) !returnType(T) {
		if (self.m.get(key)) |v| {
			return v.strictGet(T);
		}
		return error.KeyNotFound;
	}

	pub fn contains(self: Map, key: []const u8) bool {
		return self.m.contains(key);
	}

	pub fn count(self: Map) usize {
		return self.m.count();
	}

	pub fn isNull(self: Map, key: []const u8) bool {
		if (self.m.get(key)) |v| {
			return v.isNull();
		}
		return true;
	}

	pub fn jsonStringify(self: Map, options: std.json.StringifyOptions, out: anytype) !void {
		try out.writeByte('{');
		var first = true;
		var it = self.m.iterator();
		while (it.next()) |entry| {
			if (first) {
				first = false;
			} else {
				try out.writeByte(',');
			}
			try std.json.encodeJsonString(entry.key_ptr.*, options, out);
			try out.writeByte(':');
			try std.json.stringify(entry.value_ptr.*, options, out);
		}
		try out.writeByte('}');
	}
};

const t = std.testing;
test "comptime_int" {
	var map = Map.init(t.allocator);
	defer map.deinit();

	try map.put("key", 120);
	try map.put("nope", true);

	try t.expectEqual(@as(i64, 120), map.get(i64, "key").?);
	try t.expectEqual(@as(?i64, null), map.get(i64, "nope"));
	try t.expectEqual(@as(i64, 120), (try map.strictGet(i64, "key")));
	try t.expectError(error.KeyNotFound, map.strictGet(i64, "other"));
	try t.expectError(error.WrongType, map.strictGet(i64, "nope"));
}

test "comptime_float" {
	var map = Map.init(t.allocator);
	defer map.deinit();

	try map.put("key", 3.229);
	try map.put("nope", true);

	try t.expectEqual(@as(f64, 3.229), map.get(f64, "key").?);
	try t.expectEqual(@as(?f64, null), map.get(f64, "nope"));
	try t.expectEqual(@as(f64, 3.229), (try map.strictGet(f64, "key")));
	try t.expectError(error.KeyNotFound, map.strictGet(f64, "other"));
	try t.expectError(error.WrongType, map.strictGet(f64, "nope"));
}

test "i8" {
	var map = Map.init(t.allocator);
	defer map.deinit();

	try map.put("key", @as(i8, 120));
	try map.put("nope", true);

	try t.expectEqual(@as(i8, 120), map.get(i8, "key").?);
	try t.expectEqual(@as(?i8, null), map.get(i8, "nope"));
	try t.expectEqual(@as(i8, 120), (try map.strictGet(i8, "key")));
	try t.expectError(error.KeyNotFound, map.strictGet(i8, "other"));
	try t.expectError(error.WrongType, map.strictGet(i8, "nope"));
}

test "i16" {
	var map = Map.init(t.allocator);
	defer map.deinit();

	try map.put("key", @as(i16, -121));
	try map.put("nope", true);

	try t.expectEqual(@as(i16, -121), map.get(i16, "key").?);
	try t.expectEqual(@as(?i16, null), map.get(i16, "nope"));
	try t.expectEqual(@as(i16, -121), (try map.strictGet(i16, "key")));
	try t.expectError(error.KeyNotFound, map.strictGet(i16, "other"));
	try t.expectError(error.WrongType, map.strictGet(i16, "nope"));
}

test "i32" {
	var map = Map.init(t.allocator);
	defer map.deinit();

	try map.put("key", @as(i32, 12289031));
	try map.put("nope", true);

	try t.expectEqual(@as(i32, 12289031), map.get(i32, "key").?);
	try t.expectEqual(@as(?i32, null), map.get(i32, "nope"));
	try t.expectEqual(@as(i32, 12289031), (try map.strictGet(i32, "key")));
	try t.expectError(error.KeyNotFound, map.strictGet(i32, "other"));
	try t.expectError(error.WrongType, map.strictGet(i32, "nope"));
}

test "i64" {
	var map = Map.init(t.allocator);
	defer map.deinit();

	try map.put("key", @as(i64, -238390288181223));
	try map.put("nope", true);

	try t.expectEqual(@as(i64, -238390288181223), map.get(i64, "key").?);
	try t.expectEqual(@as(?i64, null), map.get(i64, "nope"));
	try t.expectEqual(@as(i64, -238390288181223), (try map.strictGet(i64, "key")));
	try t.expectError(error.KeyNotFound, map.strictGet(i64, "other"));
	try t.expectError(error.WrongType, map.strictGet(i64, "nope"));
}

test "i128" {
	var map = Map.init(t.allocator);
	defer map.deinit();

	try map.put("key", @as(i128, 39193828192238390288181223));
	try map.put("nope", true);

	try t.expectEqual(@as(i128, 39193828192238390288181223), map.get(i128, "key").?);
	try t.expectEqual(@as(?i128, null), map.get(i128, "nope"));
	try t.expectEqual(@as(i128, 39193828192238390288181223), (try map.strictGet(i128, "key")));
	try t.expectError(error.KeyNotFound, map.strictGet(i128, "other"));
	try t.expectError(error.WrongType, map.strictGet(i128, "nope"));
}

test "u8" {
	var map = Map.init(t.allocator);
	defer map.deinit();

	try map.put("key", @as(u8, 240));
	try map.put("nope", true);

	try t.expectEqual(@as(u8, 240), map.get(u8, "key").?);
	try t.expectEqual(@as(?u8, null), map.get(u8, "nope"));
	try t.expectEqual(@as(u8, 240), (try map.strictGet(u8, "key")));
	try t.expectError(error.KeyNotFound, map.strictGet(u8, "other"));
	try t.expectError(error.WrongType, map.strictGet(u8, "nope"));
}

test "u16" {
	var map = Map.init(t.allocator);
	defer map.deinit();

	try map.put("key", @as(u16, 14021));
	try map.put("nope", true);

	try t.expectEqual(@as(u16, 14021), map.get(u16, "key").?);
	try t.expectEqual(@as(?u16, null), map.get(u16, "nope"));
	try t.expectEqual(@as(u16, 14021), (try map.strictGet(u16, "key")));
	try t.expectError(error.KeyNotFound, map.strictGet(u16, "other"));
	try t.expectError(error.WrongType, map.strictGet(u16, "nope"));
}

test "u32" {
	var map = Map.init(t.allocator);
	defer map.deinit();

	try map.put("key", @as(u32, 3991992991));
	try map.put("nope", true);

	try t.expectEqual(@as(u32, 3991992991), map.get(u32, "key").?);
	try t.expectEqual(@as(?u32, null), map.get(u32, "nope"));
	try t.expectEqual(@as(u32, 3991992991), (try map.strictGet(u32, "key")));
	try t.expectError(error.KeyNotFound, map.strictGet(u32, "other"));
	try t.expectError(error.WrongType, map.strictGet(u32, "nope"));
}

test "u64" {
	var map = Map.init(t.allocator);
	defer map.deinit();

	try map.put("key", @as(u64, 399293189283821));
	try map.put("nope", true);

	try t.expectEqual(@as(u64, 399293189283821), map.get(u64, "key").?);
	try t.expectEqual(@as(?u64, null), map.get(u64, "nope"));
	try t.expectEqual(@as(u64, 399293189283821), (try map.strictGet(u64, "key")));
	try t.expectError(error.KeyNotFound, map.strictGet(u64, "other"));
	try t.expectError(error.WrongType, map.strictGet(u64, "nope"));
}

test "u128" {
	var map = Map.init(t.allocator);
	defer map.deinit();

	try map.put("key", @as(u128, 392193828192238390288181223));
	try map.put("nope", true);

	try t.expectEqual(@as(u128, 392193828192238390288181223), map.get(u128, "key").?);
	try t.expectEqual(@as(?u128, null), map.get(u128, "nope"));
	try t.expectEqual(@as(u128, 392193828192238390288181223), (try map.strictGet(u128, "key")));
	try t.expectError(error.KeyNotFound, map.strictGet(u128, "other"));
	try t.expectError(error.WrongType, map.strictGet(u128, "nope"));
}

test "f32" {
	var map = Map.init(t.allocator);
	defer map.deinit();

	try map.put("key", @as(f32, -0.32911));
	try map.put("nope", true);

	try t.expectEqual(@as(f32, -0.32911), map.get(f32, "key").?);
	try t.expectEqual(@as(?f32, null), map.get(f32, "nope"));
	try t.expectEqual(@as(f32, -0.32911), (try map.strictGet(f32, "key")));
	try t.expectError(error.KeyNotFound, map.strictGet(f32, "other"));
	try t.expectError(error.WrongType, map.strictGet(f32, "nope"));
}

test "f64" {
	var map = Map.init(t.allocator);
	defer map.deinit();

	try map.put("key", @as(f64, 32.991818282));
	try map.put("nope", true);

	try t.expectEqual(@as(f64, 32.991818282), map.get(f64, "key").?);
	try t.expectEqual(@as(?f64, null), map.get(f64, "nope"));
	try t.expectEqual(@as(f64, 32.991818282), (try map.strictGet(f64, "key")));
	try t.expectError(error.KeyNotFound, map.strictGet(f64, "other"));
	try t.expectError(error.WrongType, map.strictGet(f64, "nope"));
}

test "bool" {
	var map = Map.init(t.allocator);
	defer map.deinit();

	try map.put("key", true);
	try map.put("nope", 33);

	try t.expectEqual(true, map.get(bool, "key").?);
	try t.expectEqual(@as(?bool, null), map.get(bool, "nope"));
	try t.expectEqual(true, (try map.strictGet(bool, "key")));
	try t.expectError(error.KeyNotFound, map.strictGet(bool, "other"));
	try t.expectError(error.WrongType, map.strictGet(bool, "nope"));
}

test "string" {
	var map = Map.init(t.allocator);
	defer map.deinit();

	try map.put("key", "teg");
	try map.put("nope", 33);

	{
		// using shortcut []u8 type
		try t.expectEqualStrings("teg", map.get([]u8, "key").?);
		try t.expectEqual(@as(?[]const u8, null), map.get([]u8, "nope"));
		try t.expectEqualStrings("teg", (try map.strictGet([]u8, "key")));
		try t.expectError(error.KeyNotFound, map.strictGet([]u8, "other"));
		try t.expectError(error.WrongType, map.strictGet([]u8, "nope"));
	}

	{
		// using full []const u8 type
		try t.expectEqualStrings("teg", map.get([]const u8, "key").?);
		try t.expectEqual(@as(?[]const u8, null), map.get([]const u8, "nope"));
		try t.expectEqualStrings("teg", (try map.strictGet([]const u8, "key")));
		try t.expectError(error.KeyNotFound, map.strictGet([]const u8, "other"));
		try t.expectError(error.WrongType, map.strictGet([]const u8, "nope"));
	}

	{
		//dynamic string
		var flow = try t.allocator.alloc(u8, 4);
		defer t.allocator.free(flow);
		@memcpy(flow, "flow");
		try map.put("spice", flow);
		try t.expectEqualStrings("flow", map.mustGet([]const u8, "spice"));
	}
}

test "null" {
	var map = Map.init(t.allocator);
	defer map.deinit();

	try map.put("key", null);
	try map.put("nope", 33);

	try t.expectEqual(true, map.isNull("key"));
	try t.expectEqual(true, map.isNull("does_not_exist"));
	try t.expectEqual(false, map.isNull("nope"));
}

test "contains" {
	var map = Map.init(t.allocator);
	defer map.deinit();

	try map.put("key", null);
	try map.put("nope", 33);

	try t.expectEqual(true, map.contains("key"));
	try t.expectEqual(true, map.contains("nope"));
	try t.expectEqual(false, map.contains("does_not_exist"));
}

test "count" {
	var map = Map.init(t.allocator);
	defer map.deinit();
	try t.expectEqual(@as(usize, 0), map.count());

	try map.put("key", null);
	try t.expectEqual(@as(usize, 1), map.count());
	try map.put("nope", 33);
	try t.expectEqual(@as(usize, 2), map.count());
}

test "nullable" {
	var map = Map.init(t.allocator);
	defer map.deinit();
	try map.put("a", @as(?u32, null));
	try map.put("b", @as(?u32, 821));

	try t.expectEqual(@as(?u32, null), map.get(u32, "a"));
	try t.expectEqual(@as(u32, 821), map.get(u32, "b").?);
	try t.expectEqual(@as(?u32, null), try map.strictGet(?u32, "a"));
	try t.expectEqual(@as(u32, 821), (try map.strictGet(u32, "b")));
	try t.expectEqual(@as(u32, 821), (try map.strictGet(?u32, "b")).?);
	try t.expectError(error.WrongType, map.strictGet(bool, "a"));
	try t.expectError(error.WrongType, map.strictGet(f32, "b"));
}

test "object" {
	var child = Map.init(t.allocator);
	try child.put("power", 9001);
	try child.put("name", "goku");

	var map = Map.init(t.allocator);
	defer map.deinit();
	try map.put("child", child);

	{
		try t.expectEqual(@as(i64, 9001), map.mustGet(Map, "child").mustGet(i64, "power"));
		try t.expectEqualStrings("goku", map.mustGet(Map, "child").mustGet([]const u8, "name"));
	}
}

test "array" {
	var map = Map.init(t.allocator);
	defer map.deinit();

	var child = Array.init(t.allocator);
	try child.append(.{.i32 = 32});
	try map.put("child", child);

	{
		const arr = map.mustGet(Array, "child");
		try t.expectEqual(@as(usize, 1), arr.items.len);
		try t.expectEqual(@as(i32, 32), arr.items[0].mustGet(i32));
	}
}

test "json" {
	const json = std.json;

	try t.expectEqual(Value{.null = {}}, try fromJson(undefined, null));
	try t.expectEqual(Value{.null = {}}, try fromJson(undefined, json.Value{.null = {}}));
	try t.expectEqual(Value{.bool = true}, try fromJson(undefined, json.Value{.bool = true}));
	try t.expectEqual(Value{.i64 = 110}, try fromJson(undefined, json.Value{.integer = 110}));
	try t.expectEqual(Value{.f64 = 2.223}, try fromJson(undefined, json.Value{.float = 2.223}));
	try t.expectEqual(Value{.string = "teg atreides"}, try fromJson(undefined, json.Value{.string = "teg atreides"}));

	{
		var json_array = json.Array.init(t.allocator);
		defer json_array.deinit();
		try json_array.append(.{.bool = false});
		try json_array.append(.{.float = -3.4});

		var ta = (try fromJson(t.allocator, json.Value{.array = json_array})).array;
		defer ta.deinit();
		try t.expectEqual(Value{.bool = false}, ta.items[0]);
		try t.expectEqual(Value{.f64 = -3.4}, ta.items[1]);
	}

	{
		var json_object1 = json.ObjectMap.init(t.allocator);
		defer json_object1.deinit();

		var json_object2 = json.ObjectMap.init(t.allocator);
		defer json_object2.deinit();
		try json_object2.put("k3", json.Value{.float = 0.3211});

		var json_array = json.Array.init(t.allocator);
		defer json_array.deinit();
		try json_array.append(.{.bool = true});
		try json_array.append(.{.object = json_object2});

		try json_object1.put("k1", json.Value{.integer = 33});
		try json_object1.put("k2", json.Value{.array = json_array});

		var tm = (try fromJson(t.allocator, json.Value{.object = json_object1})).map;
		defer tm.deinit();
		try t.expectEqual(@as(usize, 2), tm.count());
		try t.expectEqual(@as(i64, 33), tm.mustGet(i64, "k1"));

		var ta = tm.mustGet(Array, "k2");
		try t.expectEqual(true, ta.items[0].mustGet(bool));
		try t.expectEqual(@as(f64, 0.3211), ta.items[1].mustGet(Map).mustGet(f64, "k3"));

		// load a map directly
		var tm2 = try Map.fromJson(t.allocator, json_object1);

		defer tm2.deinit();
		try t.expectEqual(@as(usize, 2), tm2.count());
		try t.expectEqual(@as(i64, 33), tm2.mustGet(i64, "k1"));

		var ta2 = tm2.mustGet(Array, "k2");
		try t.expectEqual(true, ta2.items[0].mustGet(bool));
		try t.expectEqual(@as(f64, 0.3211), ta2.items[1].mustGet(Map).mustGet(f64, "k3"));

		const out = try std.json.stringifyAlloc(t.allocator, tm2, .{});
		defer t.allocator.free(out);
		try t.expectEqualStrings("{\"k2\":[true,{\"k3\":0.3211}],\"k1\":33}", out);
	}
}

test "put Value" {
	var map = Map.init(t.allocator);
	defer map.deinit();

	try map.put("key", Value{.i64 = 331});
	try t.expectEqual(@as(i64, 331), map.get(i64, "key").?);
}
