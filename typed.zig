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
	object: Object,
	array: Array,

	fn deinit(self: Value) void {
		switch (self) {
			.array => |arr| {
				for (arr.items) |child| {
					child.deinit();
				}
				arr.deinit();
			},
			.object => |obj| {
				var to = obj;
				to.deinit();
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
			Object => switch (self) {.object => |v| return v, else => {}},
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
};

pub const Array = ArrayList(Value);

// gets a typed.Value from a std.json.Value
pub fn fromJson(allocator: Allocator, optional_value: ?std.json.Value) !Value {
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
		.object => |obj| {
			var to = Object.init(allocator);
			var map = &to.map;
			try map.ensureTotalCapacity(@intCast(u32, obj.count()));

			var it = obj.iterator();
			while (it.next()) |entry| {
				map.putAssumeCapacity(entry.key_ptr.*, try fromJson(allocator, entry.value_ptr.*));
			}
			return .{.object = to};
		}
	}
}

// hack so that we can call:
//    typed.get([]u"8, "somekey")
// instead of the more verbose:
//    typed.get([]const u8, "somekey")
// In both cases, []const u8 is returned.
fn returnType(comptime T: type) type {
	return switch (T) {
		[]u8 => []const u8,
		?[]u8 => ?[]const u8,
		else => T
	};
}

// Some functions, like get, always return an optional type.
// but if we just define the type as `?T`, if the user asks does typed.get(?u32, "key")
// then the return type will be ??T, which is not what we want.
// When T is an optional (e.g. ?u32), this returns T
// When T is not an optional (e.g. u32). this returns ?T
fn optionalReturnType(comptime T: type) type {
	return switch (@typeInfo(T)) {
		.Optional => |o| returnType(o.child),
		else => returnType(?T),
	};
}

pub const Object = struct {
	map: StringHashMap(Value),

	pub fn init(allocator: Allocator) Object {
		return .{
			.map = StringHashMap(Value).init(allocator),
		};
	}

	pub fn deinit(self: *Object) void {
		var it = self.map.valueIterator();
		while (it.next()) |value| {
			value.deinit();
		}
		self.map.deinit();
	}

	// dangerous!
	pub fn readonlyEmpty() Object {
		return init(undefined);
	}

	pub fn put(self: *Object, key: []const u8, value: anytype) !void {
		return self.putT(@TypeOf(value), key, value);
	}

	pub fn putT(self: *Object, comptime T: type, key: []const u8, value: anytype) !void {
		const typed_value = switch (@typeInfo(T)) {
			.Null => .{.null = {}},
			.Int => |int| blk: {
				if (int.signedness == .signed) {
					switch (int.bits) {
						1...8 => break :blk .{.i8 = value},
						9...16 => break :blk .{.i16 = value},
						17...32 => break :blk .{.i32 = value},
						33...64 => break :blk .{.i64 = value},
						65...128 => break :blk .{.i128 = value},
						else => return error.UnsupportedValueType,
					}
				} else {
					switch (int.bits) {
						1...8 => break :blk .{.u8 = value},
						9...16 => break :blk .{.u16 = value},
						17...32 => break :blk .{.u32 = value},
						33...64 => break :blk .{.u64 = value},
						65...128 => break :blk .{.u128 = value},
						else => return error.UnsupportedValueType,
					}
				}
			},
			.Float => |float| blk: {
				switch (float.bits) {
					1...32 => break :blk .{.f32 = value},
					33...64 => break :blk .{.f64 = value},
					else => return error.UnsupportedValueType,
				}
			},
			.Bool => .{.bool = value},
			.ComptimeInt => .{.i64 = value},
			.ComptimeFloat => .{.f64 = value},
			.Pointer => |ptr| blk: {
				switch (ptr.size) {
					.One => return try self.putT(ptr.child, key, value),
					.Slice => switch (ptr.child) {
						u8 => break :blk .{.string = value.ptr},
						else => return error.UnsupportedValueType,
					},
					else => return error.UnsupportedValueType,
				}
			},
			.Array => |arr| blk: {
				switch (arr.child) {
					u8 => break :blk .{.string = value},
					else => return error.UnsupportedValueType,
				}
			},
			.Struct => blk: {
				if (T == Object) {
					break :blk .{.object = value};
				}
				if (T == Array) {
					break :blk .{.array = value};
				}
				return error.UnsupportedValueType;
			},
			.Optional => |opt| blk: {
				if (value) |v| {
					return self.putT(opt.child, key, v);
				}
				break :blk .{.null = {}};
			},
			.Union => blk: {
				if (T == Value) {
					break :blk value;
				} else {
					return error.UnsupportedValueType;
				}
			},
			else => return error.UnsupportedValueType,
		};
		return self.map.put(key, typed_value);
	}

	pub fn get(self: Object, comptime T: type, key: []const u8) optionalReturnType(T) {
		if (self.map.get(key)) |v| {
			return v.get(T);
		}
		return null;
	}

	pub fn mustGet(self: Object, comptime T: type, key: []const u8) returnType(T) {
		return self.get(T, key) orelse unreachable;
	}

	pub fn strictGet(self: Object, comptime T: type, key: []const u8) !returnType(T) {
		if (self.map.get(key)) |v| {
			return v.strictGet(T);
		}
		return error.KeyNotFound;
	}

	pub fn contains(self: Object, key: []const u8) bool {
		return self.map.contains(key);
	}

	pub fn count(self: Object) usize {
		return self.map.count();
	}

	pub fn isNull(self: Object, key: []const u8) bool {
		if (self.map.get(key)) |v| {
			return v.isNull();
		}
		return true;
	}
};

const t = std.testing;
test "comptime_int" {
	var typed = Object.init(t.allocator);
	defer typed.deinit();

	try typed.put("key", 120);
	try typed.put("nope", true);

	try t.expectEqual(@as(i64, 120), typed.get(i64, "key").?);
	try t.expectEqual(@as(?i64, null), typed.get(i64, "nope"));
	try t.expectEqual(@as(i64, 120), (try typed.strictGet(i64, "key")));
	try t.expectError(error.KeyNotFound, typed.strictGet(i64, "other"));
	try t.expectError(error.WrongType, typed.strictGet(i64, "nope"));
}

test "comptime_float" {
	var typed = Object.init(t.allocator);
	defer typed.deinit();

	try typed.put("key", 3.229);
	try typed.put("nope", true);

	try t.expectEqual(@as(f64, 3.229), typed.get(f64, "key").?);
	try t.expectEqual(@as(?f64, null), typed.get(f64, "nope"));
	try t.expectEqual(@as(f64, 3.229), (try typed.strictGet(f64, "key")));
	try t.expectError(error.KeyNotFound, typed.strictGet(f64, "other"));
	try t.expectError(error.WrongType, typed.strictGet(f64, "nope"));
}

test "i8" {
	var typed = Object.init(t.allocator);
	defer typed.deinit();

	try typed.put("key", @as(i8, 120));
	try typed.put("nope", true);

	try t.expectEqual(@as(i8, 120), typed.get(i8, "key").?);
	try t.expectEqual(@as(?i8, null), typed.get(i8, "nope"));
	try t.expectEqual(@as(i8, 120), (try typed.strictGet(i8, "key")));
	try t.expectError(error.KeyNotFound, typed.strictGet(i8, "other"));
	try t.expectError(error.WrongType, typed.strictGet(i8, "nope"));
}

test "i16" {
	var typed = Object.init(t.allocator);
	defer typed.deinit();

	try typed.put("key", @as(i16, -121));
	try typed.put("nope", true);

	try t.expectEqual(@as(i16, -121), typed.get(i16, "key").?);
	try t.expectEqual(@as(?i16, null), typed.get(i16, "nope"));
	try t.expectEqual(@as(i16, -121), (try typed.strictGet(i16, "key")));
	try t.expectError(error.KeyNotFound, typed.strictGet(i16, "other"));
	try t.expectError(error.WrongType, typed.strictGet(i16, "nope"));
}

test "i32" {
	var typed = Object.init(t.allocator);
	defer typed.deinit();

	try typed.put("key", @as(i32, 12289031));
	try typed.put("nope", true);

	try t.expectEqual(@as(i32, 12289031), typed.get(i32, "key").?);
	try t.expectEqual(@as(?i32, null), typed.get(i32, "nope"));
	try t.expectEqual(@as(i32, 12289031), (try typed.strictGet(i32, "key")));
	try t.expectError(error.KeyNotFound, typed.strictGet(i32, "other"));
	try t.expectError(error.WrongType, typed.strictGet(i32, "nope"));
}

test "i64" {
	var typed = Object.init(t.allocator);
	defer typed.deinit();

	try typed.put("key", @as(i64, -238390288181223));
	try typed.put("nope", true);

	try t.expectEqual(@as(i64, -238390288181223), typed.get(i64, "key").?);
	try t.expectEqual(@as(?i64, null), typed.get(i64, "nope"));
	try t.expectEqual(@as(i64, -238390288181223), (try typed.strictGet(i64, "key")));
	try t.expectError(error.KeyNotFound, typed.strictGet(i64, "other"));
	try t.expectError(error.WrongType, typed.strictGet(i64, "nope"));
}

test "i128" {
	var typed = Object.init(t.allocator);
	defer typed.deinit();

	try typed.put("key", @as(i128, 39193828192238390288181223));
	try typed.put("nope", true);

	try t.expectEqual(@as(i128, 39193828192238390288181223), typed.get(i128, "key").?);
	try t.expectEqual(@as(?i128, null), typed.get(i128, "nope"));
	try t.expectEqual(@as(i128, 39193828192238390288181223), (try typed.strictGet(i128, "key")));
	try t.expectError(error.KeyNotFound, typed.strictGet(i128, "other"));
	try t.expectError(error.WrongType, typed.strictGet(i128, "nope"));
}

test "u8" {
	var typed = Object.init(t.allocator);
	defer typed.deinit();

	try typed.put("key", @as(u8, 240));
	try typed.put("nope", true);

	try t.expectEqual(@as(u8, 240), typed.get(u8, "key").?);
	try t.expectEqual(@as(?u8, null), typed.get(u8, "nope"));
	try t.expectEqual(@as(u8, 240), (try typed.strictGet(u8, "key")));
	try t.expectError(error.KeyNotFound, typed.strictGet(u8, "other"));
	try t.expectError(error.WrongType, typed.strictGet(u8, "nope"));
}

test "u16" {
	var typed = Object.init(t.allocator);
	defer typed.deinit();

	try typed.put("key", @as(u16, 14021));
	try typed.put("nope", true);

	try t.expectEqual(@as(u16, 14021), typed.get(u16, "key").?);
	try t.expectEqual(@as(?u16, null), typed.get(u16, "nope"));
	try t.expectEqual(@as(u16, 14021), (try typed.strictGet(u16, "key")));
	try t.expectError(error.KeyNotFound, typed.strictGet(u16, "other"));
	try t.expectError(error.WrongType, typed.strictGet(u16, "nope"));
}

test "u32" {
	var typed = Object.init(t.allocator);
	defer typed.deinit();

	try typed.put("key", @as(u32, 3991992991));
	try typed.put("nope", true);

	try t.expectEqual(@as(u32, 3991992991), typed.get(u32, "key").?);
	try t.expectEqual(@as(?u32, null), typed.get(u32, "nope"));
	try t.expectEqual(@as(u32, 3991992991), (try typed.strictGet(u32, "key")));
	try t.expectError(error.KeyNotFound, typed.strictGet(u32, "other"));
	try t.expectError(error.WrongType, typed.strictGet(u32, "nope"));
}

test "u64" {
	var typed = Object.init(t.allocator);
	defer typed.deinit();

	try typed.put("key", @as(u64, 399293189283821));
	try typed.put("nope", true);

	try t.expectEqual(@as(u64, 399293189283821), typed.get(u64, "key").?);
	try t.expectEqual(@as(?u64, null), typed.get(u64, "nope"));
	try t.expectEqual(@as(u64, 399293189283821), (try typed.strictGet(u64, "key")));
	try t.expectError(error.KeyNotFound, typed.strictGet(u64, "other"));
	try t.expectError(error.WrongType, typed.strictGet(u64, "nope"));
}

test "u128" {
	var typed = Object.init(t.allocator);
	defer typed.deinit();

	try typed.put("key", @as(u128, 392193828192238390288181223));
	try typed.put("nope", true);

	try t.expectEqual(@as(u128, 392193828192238390288181223), typed.get(u128, "key").?);
	try t.expectEqual(@as(?u128, null), typed.get(u128, "nope"));
	try t.expectEqual(@as(u128, 392193828192238390288181223), (try typed.strictGet(u128, "key")));
	try t.expectError(error.KeyNotFound, typed.strictGet(u128, "other"));
	try t.expectError(error.WrongType, typed.strictGet(u128, "nope"));
}

test "f32" {
	var typed = Object.init(t.allocator);
	defer typed.deinit();

	try typed.put("key", @as(f32, -0.32911));
	try typed.put("nope", true);

	try t.expectEqual(@as(f32, -0.32911), typed.get(f32, "key").?);
	try t.expectEqual(@as(?f32, null), typed.get(f32, "nope"));
	try t.expectEqual(@as(f32, -0.32911), (try typed.strictGet(f32, "key")));
	try t.expectError(error.KeyNotFound, typed.strictGet(f32, "other"));
	try t.expectError(error.WrongType, typed.strictGet(f32, "nope"));
}

test "f64" {
	var typed = Object.init(t.allocator);
	defer typed.deinit();

	try typed.put("key", @as(f64, 32.991818282));
	try typed.put("nope", true);

	try t.expectEqual(@as(f64, 32.991818282), typed.get(f64, "key").?);
	try t.expectEqual(@as(?f64, null), typed.get(f64, "nope"));
	try t.expectEqual(@as(f64, 32.991818282), (try typed.strictGet(f64, "key")));
	try t.expectError(error.KeyNotFound, typed.strictGet(f64, "other"));
	try t.expectError(error.WrongType, typed.strictGet(f64, "nope"));
}

test "bool" {
	var typed = Object.init(t.allocator);
	defer typed.deinit();

	try typed.put("key", true);
	try typed.put("nope", 33);

	try t.expectEqual(true, typed.get(bool, "key").?);
	try t.expectEqual(@as(?bool, null), typed.get(bool, "nope"));
	try t.expectEqual(true, (try typed.strictGet(bool, "key")));
	try t.expectError(error.KeyNotFound, typed.strictGet(bool, "other"));
	try t.expectError(error.WrongType, typed.strictGet(bool, "nope"));
}

test "string" {
	var typed = Object.init(t.allocator);
	defer typed.deinit();

	try typed.put("key", "teg");
	try typed.put("nope", 33);

	{
		// using shortcut []u8 type
		try t.expectEqualStrings("teg", typed.get([]u8, "key").?);
		try t.expectEqual(@as(?[]const u8, null), typed.get([]u8, "nope"));
		try t.expectEqualStrings("teg", (try typed.strictGet([]u8, "key")));
		try t.expectError(error.KeyNotFound, typed.strictGet([]u8, "other"));
		try t.expectError(error.WrongType, typed.strictGet([]u8, "nope"));
	}

	{
		// using full []const u8 type
		try t.expectEqualStrings("teg", typed.get([]const u8, "key").?);
		try t.expectEqual(@as(?[]const u8, null), typed.get([]const u8, "nope"));
		try t.expectEqualStrings("teg", (try typed.strictGet([]const u8, "key")));
		try t.expectError(error.KeyNotFound, typed.strictGet([]const u8, "other"));
		try t.expectError(error.WrongType, typed.strictGet([]const u8, "nope"));
	}
}

test "null" {
	var typed = Object.init(t.allocator);
	defer typed.deinit();

	try typed.put("key", null);
	try typed.put("nope", 33);

	try t.expectEqual(true, typed.isNull("key"));
	try t.expectEqual(true, typed.isNull("does_not_exist"));
	try t.expectEqual(false, typed.isNull("nope"));
}

test "contains" {
	var typed = Object.init(t.allocator);
	defer typed.deinit();

	try typed.put("key", null);
	try typed.put("nope", 33);

	try t.expectEqual(true, typed.contains("key"));
	try t.expectEqual(true, typed.contains("nope"));
	try t.expectEqual(false, typed.contains("does_not_exist"));
}

test "count" {
	var typed = Object.init(t.allocator);
	defer typed.deinit();
	try t.expectEqual(@as(usize, 0), typed.count());

	try typed.put("key", null);
	try t.expectEqual(@as(usize, 1), typed.count());
	try typed.put("nope", 33);
	try t.expectEqual(@as(usize, 2), typed.count());
}

test "nullable" {
	var typed = Object.init(t.allocator);
	defer typed.deinit();
	try typed.put("a", @as(?u32, null));
	try typed.put("b", @as(?u32, 821));

	try t.expectEqual(@as(?u32, null), typed.get(u32, "a"));
	try t.expectEqual(@as(u32, 821), typed.get(u32, "b").?);
	try t.expectEqual(@as(?u32, null), try typed.strictGet(?u32, "a"));
	try t.expectEqual(@as(u32, 821), (try typed.strictGet(u32, "b")));
	try t.expectEqual(@as(u32, 821), (try typed.strictGet(?u32, "b")).?);
	try t.expectError(error.WrongType, typed.strictGet(bool, "a"));
	try t.expectError(error.WrongType, typed.strictGet(f32, "b"));
}

test "object" {
	var child = Object.init(t.allocator);
	try child.put("power", 9001);
	try child.put("name", "goku");

	var typed = Object.init(t.allocator);
	defer typed.deinit();
	try typed.put("child", child);

	{
		try t.expectEqual(@as(i64, 9001), typed.mustGet(Object, "child").mustGet(i64, "power"));
		try t.expectEqualStrings("goku", typed.mustGet(Object, "child").mustGet([]const u8, "name"));
	}
}

test "array" {
	var typed = Object.init(t.allocator);
	defer typed.deinit();

	var child = Array.init(t.allocator);
	try child.append(.{.i32 = 32});
	try typed.put("child", child);

	{
		const arr = typed.mustGet(Array, "child");
		try t.expectEqual(@as(usize, 1), arr.items.len);
		try t.expectEqual(@as(i32, 32), arr.items[0].mustGet(i32));
	}
}

test "fromJson" {
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

		var to = (try fromJson(t.allocator, json.Value{.object = json_object1})).object;
		defer to.deinit();
		try t.expectEqual(@as(usize, 2), to.count());
		try t.expectEqual(@as(i64, 33), to.mustGet(i64, "k1"));

		var ta = to.mustGet(Array, "k2");
		try t.expectEqual(true, ta.items[0].mustGet(bool));
		try t.expectEqual(@as(f64, 0.3211), ta.items[1].mustGet(Object).mustGet(f64, "k3"));
	}
}

test "put Value" {
	var typed = Object.init(t.allocator);
	defer typed.deinit();

	try typed.put("key", Value{.i64 = 331});
	try t.expectEqual(@as(i64, 331), typed.get(i64, "key").?);
}
