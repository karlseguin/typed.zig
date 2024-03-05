const std = @import("std");
const typed = @import("typed.zig");

const Value = typed.Value;
const Array = typed.Array;
const StringHashMap = std.StringHashMap;
const Allocator = std.mem.Allocator;

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
		try map.ensureTotalCapacity(@intCast(obj.count()));

		var it = obj.iterator();
		while (it.next()) |entry| {
			map.putAssumeCapacity(entry.key_ptr.*, try typed.fromJson(allocator, entry.value_ptr.*));
		}
		return to;
	}

	// dangerous!
	pub fn readonlyEmpty() Map {
		return init(undefined);
	}

	pub fn ensureTotalCapacity(self: *Map, size: u32) !void {
		return self.m.ensureTotalCapacity(size);
	}

	pub fn ensureUnusedCapacity(self: *Map, size: u32) !void {
		return self.m.ensureUnusedCapacity(size);
	}

	pub fn put(self: *Map, key: []const u8, value: anytype) !void {
		return self.putT(@TypeOf(value), key, value);
	}

	pub fn putAll(self: *Map, values: anytype) !void {
		const fields = std.meta.fields(@TypeOf(values));
		try self.m.ensureUnusedCapacity(fields.len);

		inline for (fields) |field| {
			try self.putAssumeCapacityT(field.type, field.name, @field(values, field.name));
		}
	}

	pub fn putT(self: *Map, comptime T: type, key: []const u8, value: anytype) !void {
		return self.m.put(key, try typed.newT(T, self.m.allocator, value));
	}

	pub fn putAssumeCapacity(self: *Map, key: []const u8, value: anytype) !void {
		return self.putAssumeCapacityT(@TypeOf(value), key, value);
	}

	pub fn putAssumeCapacityT(self: *Map, comptime T: type, key: []const u8, value: anytype) !void {
		self.m.putAssumeCapacity(key, try typed.newT(T, self.m.allocator, value));
	}

	pub fn getValue(self: Map, key: []const u8) ?Value {
		return self.m.get(key);
	}

	pub fn get(self: Map, comptime T: type, key: []const u8) Value.OptionalReturnType(T) {
		if (self.m.get(key)) |v| {
			return v.get(T);
		}
		return null;
	}

	pub fn mustGet(self: Map, comptime T: type, key: []const u8) Value.ReturnType(T) {
		return self.get(T, key) orelse unreachable;
	}

	pub fn strictGet(self: Map, comptime T: type, key: []const u8) !Value.ReturnType(T) {
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

	pub fn jsonStringify(self: Map, out: anytype) !void {
		try out.beginObject();
		var it = self.m.iterator();
		while (it.next()) |entry| {
			try out.objectField(entry.key_ptr.*);
			try out.write(entry.value_ptr.*);
		}
		try out.endObject();
	}
};

const t = @import("t.zig");
test "map: value" {
	var map = Map.init(t.allocator);
	defer map.deinit();

	try map.put("key", Value{.i64 = 331});
	try t.expectEqual(@as(i64, 331), map.get(i64, "key").?);
}

test "map: comptime_int" {
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

test "map: comptime_float" {
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

test "map: i8" {
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

test "map: i16" {
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

test "map: i32" {
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

test "map: i64" {
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

test "map: i128" {
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

test "map: u8" {
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

test "map: u16" {
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

test "map: u32" {
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

test "map: u64" {
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

test "map: u128" {
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

test "map: f32" {
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

test "map: f64" {
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

test "map: bool" {
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

test "map: string" {
	var map = Map.init(t.allocator);
	defer map.deinit();

	try map.put("key", "teg");
	try map.put("nope", 33);

	{
		// using shortcut []u8 type
		try t.expectString("teg", map.get([]u8, "key").?);
		try t.expectEqual(@as(?[]const u8, null), map.get([]u8, "nope"));
		try t.expectString("teg", (try map.strictGet([]u8, "key")));
		try t.expectError(error.KeyNotFound, map.strictGet([]u8, "other"));
		try t.expectError(error.WrongType, map.strictGet([]u8, "nope"));
	}

	{
		// using full []const u8 type
		try t.expectString("teg", map.get([]const u8, "key").?);
		try t.expectEqual(@as(?[]const u8, null), map.get([]const u8, "nope"));
		try t.expectString("teg", (try map.strictGet([]const u8, "key")));
		try t.expectError(error.KeyNotFound, map.strictGet([]const u8, "other"));
		try t.expectError(error.WrongType, map.strictGet([]const u8, "nope"));
	}

	{
		//dynamic string
		const flow = try t.allocator.alloc(u8, 4);
		defer t.allocator.free(flow);
		@memcpy(flow, "flow");
		try map.put("spice", flow);
		try t.expectString("flow", map.mustGet([]const u8, "spice"));
	}
}

test "map: null" {
	var map = Map.init(t.allocator);
	defer map.deinit();

	try map.put("key", null);
	try map.put("nope", 33);

	try t.expectEqual(true, map.isNull("key"));
	try t.expectEqual(true, map.isNull("does_not_exist"));
	try t.expectEqual(false, map.isNull("nope"));
}

test "map: contains" {
	var map = Map.init(t.allocator);
	defer map.deinit();

	try map.put("key", null);
	try map.put("nope", 33);

	try t.expectEqual(true, map.contains("key"));
	try t.expectEqual(true, map.contains("nope"));
	try t.expectEqual(false, map.contains("does_not_exist"));
}

test "map: count" {
	var map = Map.init(t.allocator);
	defer map.deinit();
	try t.expectEqual(@as(usize, 0), map.count());

	try map.put("key", null);
	try t.expectEqual(@as(usize, 1), map.count());
	try map.put("nope", 33);
	try t.expectEqual(@as(usize, 2), map.count());
}

test "map: nullable" {
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

test "map: object" {
	var child = Map.init(t.allocator);
	try child.put("power", 9001);
	try child.put("name", "goku");

	var map = Map.init(t.allocator);
	defer map.deinit();
	try map.put("child", child);

	{
		try t.expectEqual(@as(i64, 9001), map.mustGet(Map, "child").mustGet(i64, "power"));
		try t.expectString("goku", map.mustGet(Map, "child").mustGet([]const u8, "name"));
	}
}

test "map: array" {
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

test "map: putAll" {
	var map = Map.init(t.allocator);
	defer map.deinit();

	try map.putAll(.{.over = 9000, .spice = "flow", .ok = true});
	try t.expectEqual(true, map.get(bool, "ok").?);
	try t.expectEqual(@as(i64, 9000), map.get(i64, "over").?);
	try t.expectString("flow", map.get([]u8, "spice").?);
	try t.expectEqual(@as(u32, 3), map.m.count());
}

test "map: getValue" {
	var m = Map.init(t.allocator);
	defer m.deinit();

	try m.putAll(.{.age = 50, .name = "Ghanima"});
	try t.expectEqual(@as(?Value, null), m.getValue("nope"));
	try t.expectEqual(@as(i64, 50), m.getValue("age").?.i64);
	try t.expectString("Ghanima", m.getValue("name").?.string);
}

test "map: putAssumeCapacity" {
	var map = Map.init(t.allocator);
	defer map.deinit();

	try map.ensureTotalCapacity(3);

	try map.putAssumeCapacity("a", 1);
	try map.putAssumeCapacity("b", true);
	try map.putAssumeCapacity("c", "hello");
	try t.expectEqual(@as(i64, 1), map.get(i64, "a").?);
	try t.expectEqual(true, map.get(bool, "b").?);
	try t.expectString("hello", map.get([]u8, "c").?);
}

test "map: fromJson" {
	const json = std.json;
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


	var tm2 = try Map.fromJson(t.allocator, json_object1);

	defer tm2.deinit();
	try t.expectEqual(@as(usize, 2), tm2.count());
	try t.expectEqual(@as(i64, 33), tm2.mustGet(i64, "k1"));

	var ta2 = tm2.mustGet(Array, "k2");
	try t.expectEqual(true, ta2.items[0].mustGet(bool));
	try t.expectEqual(@as(f64, 0.3211), ta2.items[1].mustGet(Map).mustGet(f64, "k3"));

	const out = try std.json.stringifyAlloc(t.allocator, tm2, .{});
	defer t.allocator.free(out);
	try t.expectString("{\"k1\":33,\"k2\":[true,{\"k3\":0.3211}]}", out);
}
