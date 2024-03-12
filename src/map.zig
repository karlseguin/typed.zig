const std = @import("std");
const typed = @import("typed.zig");

const Value = typed.Value;
const Array = typed.Array;
const Allocator = std.mem.Allocator;
const StringHashMapUnmanaged = std.StringHashMapUnmanaged;

pub const Map = struct {
	allocator: Allocator,
	unmanaged: StringHashMapUnmanaged(Value),

	pub fn init(allocator: Allocator) Map {
		return .{
			.allocator = allocator,
			.unmanaged = StringHashMapUnmanaged(Value){},
		};
	}

	pub fn deinit(self: *Map) void {
		var it = self.valueIterator();
		while (it.next()) |value| {
			value.deinit();
		}
		self.unmanaged.deinit(self.allocator);
	}

	pub fn fromJson(allocator: Allocator, obj: std.json.ObjectMap) !Map {
		var to = init(allocator);
		var unmanaged = &to.unmanaged;
		try unmanaged.ensureTotalCapacity(allocator, @intCast(obj.count()));

		var it = obj.iterator();
		while (it.next()) |entry| {
			unmanaged.putAssumeCapacity(entry.key_ptr.*, try typed.fromJson(allocator, entry.value_ptr.*));
		}
		return to;
	}

	pub fn iterator(self: *const Map) StringHashMapUnmanaged(Value).Iterator {
		return self.unmanaged.iterator();
	}

	pub fn keyIterator(self: *const Map) StringHashMapUnmanaged(Value).KeyIterator {
			return self.unmanaged.keyIterator();
	}

	pub fn valueIterator(self: *const Map) StringHashMapUnmanaged(Value).ValueIterator {
			return self.unmanaged.valueIterator();
	}

	// dangerous!
	pub fn readonlyEmpty() Map {
		return init(undefined);
	}

	pub fn ensureTotalCapacity(self: *Map, size: u32) !void {
		return self.unmanaged.ensureTotalCapacity(self.allocator, size);
	}

	pub fn ensureUnusedCapacity(self: *Map, size: u32) !void {
		return self.unmanaged.ensureUnusedCapacity(size);
	}

	pub fn put(self: *Map, key: []const u8, value: anytype) !void {
		return self.unmanaged.put(self.allocator, key, try typed.new(self.allocator, value));
	}

	pub fn putAll(self: *Map, values: anytype) !void {
		const fields = std.meta.fields(@TypeOf(values));
		try self.unmanaged.ensureUnusedCapacity(self.allocator, fields.len);

		inline for (fields) |field| {
			try self.putAssumeCapacity(field.name, @field(values, field.name));
		}
	}

	pub fn putAssumeCapacity(self: *Map, key: []const u8, value: anytype) !void {
		self.unmanaged.putAssumeCapacity(key, try typed.new(self.allocator, value));
	}

	pub fn get(self: Map, key: []const u8) ?Value {
		return self.unmanaged.get(key);
	}

	pub fn contains(self: Map, key: []const u8) bool {
		return self.unmanaged.contains(key);
	}

	pub fn count(self: Map) usize {
		return self.unmanaged.count();
	}

	pub fn isNull(self: Map, key: []const u8) bool {
		if (self.m.get(key)) |v| {
			return v.isNull();
		}
		return true;
	}

	pub fn jsonStringify(self: Map, out: anytype) !void {
		try out.beginObject();
		var it = self.iterator();
		while (it.next()) |entry| {
			try out.objectField(entry.key_ptr.*);
			try out.write(entry.value_ptr.*);
		}
		try out.endObject();
	}

	pub fn jsonParse(allocator: Allocator, source: anytype, options: std.json.ParseOptions) !Map {
		if (try source.next() != .object_begin) {
			return error.UnexpectedToken;
		}
		return mapFromJsonObject(allocator, source, options);
	}
};

// extracted like this because typed.Value can call this directly. This is needed
// since it will have already consumed the .object_begin token.
pub fn mapFromJsonObject(allocator: Allocator, source: anytype, options: std.json.ParseOptions) std.json.ParseError(@TypeOf(source.*))!Map {
	var map = Map.init(allocator);
	errdefer map.deinit();

	while (true) {
		const token = try source.nextAlloc(allocator, options.allocate.?);
		switch (token) {
			inline .string, .allocated_string => |k| {
				const v = try Value.jsonParse(allocator, source, options);
				try map.unmanaged.put(allocator, k, v);
			},
			.object_end => break,
			else => unreachable,
		}
	}
	return map;
}

const t = @import("t.zig");
test "map: value" {
	var map = Map.init(t.allocator);
	defer map.deinit();

	try map.put("key", Value{.i64 = 441});
	try t.expectEqual(441, map.get("key").?.i64);
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

test "map: object" {
	var child = Map.init(t.allocator);
	try child.put("power", 9001);
	try child.put("name", "goku");

	var map = Map.init(t.allocator);
	defer map.deinit();
	try map.put("child", child);

	{
		try t.expectEqual(9001, map.get("child").?.map.get("power").?.i64);
		try t.expectString("goku", map.get("child").?.map.get("name").?.string);
	}
}

test "map: array" {
	var map = Map.init(t.allocator);
	defer map.deinit();

	var child = Array.init(t.allocator);
	try child.append(.{.i32 = 32});
	try map.put("child", child);

	{
		const arr = map.get("child").?.array;
		try t.expectEqual(1, arr.items.len);
		try t.expectEqual(32, arr.items[0].get(i32));
	}
}

test "map: putAll" {
	var map = Map.init(t.allocator);
	defer map.deinit();

	try map.putAll(.{.over = 9000, .spice = "flow", .ok = true});
	try t.expectEqual(true, map.get("ok").?.bool);
	try t.expectEqual(9000, map.get("over").?.i64);
	try t.expectString("flow", map.get("spice").?.string);
	try t.expectEqual(3, map.count());
}

test "map: putAssumeCapacity" {
	var map = Map.init(t.allocator);
	defer map.deinit();

	try map.ensureTotalCapacity(3);

	try map.putAssumeCapacity("a", 1);
	try map.putAssumeCapacity("b", true);
	try map.putAssumeCapacity("c", "hello");
	try t.expectEqual(1, map.get("a").?.i64);
	try t.expectEqual(true, map.get("b").?.bool);
	try t.expectString("hello", map.get("c").?.string);
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
	try t.expectEqual(2, tm2.count());
	try t.expectEqual(33, tm2.get("k1").?.i64);

	var ta2 = tm2.get("k2").?.array;
	try t.expectEqual(true, ta2.items[0].bool);
	try t.expectEqual(0.3211, ta2.items[1].map.get("k3").?.f64);

	const out = try std.json.stringifyAlloc(t.allocator, tm2, .{});
	defer t.allocator.free(out);
	try t.expectString("{\"k1\":33,\"k2\":[true,{\"k3\":0.3211}]}", out);
}

test "map: jsonParse" {
	{
		var parsed = try std.json.parseFromSlice(Map, t.allocator, "{}", .{});
		defer parsed.deinit();
		try t.expectEqual(0, parsed.value.count());
	}

	{
		// integers
		var parsed = try std.json.parseFromSlice(Map, t.allocator, "{\"a\": 123, \"b\": -3939255931, \"c\": 0, \"d\": -0}", .{});
		defer parsed.deinit();
		try t.expectEqual(4, parsed.value.count());
		try t.expectEqual(123, parsed.value.get("a").?.i64);
		try t.expectEqual(-3939255931, parsed.value.get("b").?.i64);
		try t.expectEqual(0, parsed.value.get("c").?.i64);
		try t.expectEqual(-0.0, parsed.value.get("d").?.f64);
	}

	{
		// floats
		var parsed = try std.json.parseFromSlice(Map, t.allocator, "{\"a\": 0.1, \"b\": -9.2, \"c\": 392866.838180045, \"d\": 3.4e10}", .{});
		defer parsed.deinit();
		try t.expectEqual(4, parsed.value.count());
		try t.expectEqual(0.1, parsed.value.get("a").?.f64);
		try t.expectEqual(-9.2, parsed.value.get("b").?.f64);
		try t.expectEqual(392866.838180045, parsed.value.get("c").?.f64);
		try t.expectEqual(3.4e+10, parsed.value.get("d").?.f64);
	}

	{
		// bool / null
		var parsed = try std.json.parseFromSlice(Map, t.allocator, "{\"key-1\": true, \"another-key\": false, \"x123\": null}", .{});
		defer parsed.deinit();
		try t.expectEqual(3, parsed.value.count());
		try t.expectEqual(true, parsed.value.get("key-1").?.bool);
		try t.expectEqual(false, parsed.value.get("another-key").?.bool);
		try t.expectEqual(true,  parsed.value.get("x123").?.isNull());
	}

	{
		// strings
		var parsed = try std.json.parseFromSlice(Map, t.allocator, "{\"a\":\"\",\"b\":\"9001\\u00B0C\"}", .{});
		defer parsed.deinit();
		try t.expectEqual(2, parsed.value.count());
		try t.expectString("", parsed.value.get("a").?.string);
		try t.expectString("9001°C", parsed.value.get("b").?.string);
	}

	{
		// long key / values
		const key = "a" ** 10_000;
		const value = "b" ** 10_000;
		var parsed = try std.json.parseFromSlice(Map, t.allocator, "{\"" ++ key ++ "\":\"" ++ value ++ "\"}", .{});
		defer parsed.deinit();
		try t.expectEqual(1, parsed.value.count());
		try t.expectString(value, parsed.value.get(key).?.string);
	}

		{
		// nested map
		var parsed = try std.json.parseFromSlice(Map, t.allocator, "{\"a\": {\"b\": {\"c\": 1234}}}", .{});
		defer parsed.deinit();
		try t.expectEqual(1, parsed.value.count());
		try t.expectEqual(1234, parsed.value.get("a").?.map.get("b").?.map.get("c").?.i64);
	}

		{
		// nested array
		var parsed = try std.json.parseFromSlice(Map, t.allocator, "{\"a\": [1, true, null, {\"b\":[0.1]}]}", .{});
		defer parsed.deinit();
		try t.expectEqual(1, parsed.value.count());

		const arr = parsed.value.get("a").?.array.items;
		try t.expectEqual(4, arr.len);
		try t.expectEqual(1, arr[0].i64);
		try t.expectEqual(true, arr[1].bool);
		try t.expectEqual(true, arr[2].isNull());
	}
}
