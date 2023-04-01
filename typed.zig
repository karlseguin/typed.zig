const std = @import("std");

const json = std.json;
const Allocator = std.mem.Allocator;

const M = @This();

const Typed = struct {
	root: json.ObjectMap,
	tree: ?json.ValueTree,

	pub fn deinit(self: Typed) void {
		if (self.tree) |ct| {
			var tree = ct;
			tree.deinit();
		}
	}

	pub fn int(self: Typed, field: []const u8) ?i64 {
		if (self.root.get(field)) |v| {
			return M.int(v);
		}
		return null;
	}

	pub fn boolean(self: Typed, field: []const u8) ?bool {
		if (self.root.get(field)) |v| {
			return M.boolean(v);
		}
		return null;
	}

	pub fn float(self: Typed, field: []const u8) ?f64 {
		if (self.root.get(field)) |v| {
			return M.float(v);
		}
		return null;
	}

	pub fn string(self: Typed, field: []const u8) ?[]const u8 {
		if (self.root.get(field)) |v| {
			return M.string(v);
		}
		return null;
	}

	pub fn array(self: Typed, field: []const u8) ?json.Array {
		if (self.root.get(field)) |v| {
			return M.array(v);
		}
		return null;
	}

	pub fn object(self: Typed, field: []const u8) ?Typed {
		if (self.root.get(field)) |v| {
			return M.object(v);
		}
		return null;
	}
};

pub fn fromJson(allocator: Allocator, data: []const u8, copy: bool) !Typed {
	var parser = json.Parser.init(allocator, copy);
	defer parser.deinit();
	const tree = try parser.parse(data);
	return .{
		.tree = tree,
		.root = tree.root.Object,
	};
}

pub fn boolean(value: json.Value) ?bool {
	switch (value) {
		.Bool => |b| return b,
		else => return null,
	}
}

pub fn int(value: json.Value) ?i64 {
	switch (value) {
		.Integer => |n| return n,
		else => return null,
	}
}

pub fn float(value: json.Value) ?f64 {
	switch (value) {
		.Float => |f| return f,
		else => return null,
	}
}

pub fn string(value: json.Value) ?[]const u8 {
	switch (value) {
		.String => |s| return s,
		else => return null,
	}
}

pub fn array(value: json.Value) ?json.Array {
	switch (value) {
		.Array => |a| return a,
		else => return null,
	}
}

pub fn object(value: json.Value) ?Typed {
	switch (value) {
		.Object => |o| return .{.root = o, .tree = null},
		else => return null,
	}
}

test "typed: field access" {
	const typed = try fromJson(std.testing.allocator, \\
	\\{
	\\ "tea": true,
	\\ "coffee": false,
	\\ "quality": 9.4,
	\\ "quantity": 88,
	\\ "type": "keemun",
	\\ "power": {"over": 9000}
	\\}
	,false);
	defer typed.deinit();

	try std.testing.expectEqual(true, typed.boolean("tea").?);
	try std.testing.expectEqual(false, typed.boolean("coffee").?);
	try std.testing.expectEqual(@as(?bool, null), typed.boolean("nope"));
	try std.testing.expectEqual(@as(?bool, null), typed.boolean("quality"));

	try std.testing.expectEqual(@as(f64, 9.4), typed.float("quality").?);
	try std.testing.expectEqual(@as(?f64, null), typed.float("nope"));
	try std.testing.expectEqual(@as(?f64, null), typed.float("tea"));

	try std.testing.expectEqual(@as(i64, 88), typed.int("quantity").?);
	try std.testing.expectEqual(@as(?i64, null), typed.int("coffee"));
	try std.testing.expectEqual(@as(?i64, null), typed.int("quality"));

	try std.testing.expectEqualStrings(@as([]const u8, "keemun"), typed.string("type").?);
	try std.testing.expectEqual(@as(?[]const u8, null), typed.string("coffee"));
	try std.testing.expectEqual(@as(?[]const u8, null), typed.string("quality"));

	try std.testing.expectEqual(@as(i64, 9000), typed.object("power").?.int("over").?);
	try std.testing.expectEqual(@as(?Typed, null), typed.object("nope"));
	try std.testing.expectEqual(@as(?Typed, null), typed.object("quantity"));
}

test "typed: int array" {
	const typed = try fromJson(std.testing.allocator, \\
	\\{
	\\ "values": [1, 2, 3, true]
	\\}
	,false);
	defer typed.deinit();

	const values = typed.array("values").?;
	try std.testing.expectEqual(@as(usize, 4), values.items.len);
	try std.testing.expectEqual(@intCast(i64, 1), int(values.items[0]).?);
	try std.testing.expectEqual(@intCast(i64, 2), int(values.items[1]).?);
	try std.testing.expectEqual(@intCast(i64, 3), int(values.items[2]).?);
	try std.testing.expectEqual(@as(?i64, null), int(values.items[3]));
}

test "typed: float array" {
	const typed = try fromJson(std.testing.allocator, \\
	\\{
	\\ "values": [1.1, 2.2, 3.3, "a"]
	\\}
	,false);
	defer typed.deinit();

	const values = typed.array("values").?;
	try std.testing.expectEqual(@as(usize, 4), values.items.len);
	try std.testing.expectEqual(@as(f64, 1.1), float(values.items[0]).?);
	try std.testing.expectEqual(@as(f64, 2.2), float(values.items[1]).?);
	try std.testing.expectEqual(@as(f64, 3.3), float(values.items[2]).?);
	try std.testing.expectEqual(@as(?f64, null), float(values.items[3]));
}

test "typed: bool array" {
	const typed = try fromJson(std.testing.allocator, \\
	\\{
	\\ "values": [true, false, true, 12]
	\\}
	,false);
	defer typed.deinit();

	const values = typed.array("values").?;
	try std.testing.expectEqual(@as(usize, 4), values.items.len);
	try std.testing.expectEqual(@as(bool, true), boolean(values.items[0]).?);
	try std.testing.expectEqual(@as(bool, false), boolean(values.items[1]).?);
	try std.testing.expectEqual(@as(bool, true), boolean(values.items[2]).?);
	try std.testing.expectEqual(@as(?bool, null), boolean(values.items[3]));
}

test "typed: string array" {
	const typed = try fromJson(std.testing.allocator, \\
	\\{
	\\ "values": ["abc", "123", "tea", 1]
	\\}
	,false);
	defer typed.deinit();

	const values = typed.array("values").?;
	try std.testing.expectEqual(@as(usize, 4), values.items.len);
	try std.testing.expectEqualStrings("abc", string(values.items[0]).?);
	try std.testing.expectEqualStrings("123", string(values.items[1]).?);
	try std.testing.expectEqualStrings("tea", string(values.items[2]).?);
	try std.testing.expectEqual(@as(?[]const u8, null), string(values.items[3]));
}

test "typed: object array" {
	const typed = try fromJson(std.testing.allocator, \\
	\\{
	\\ "values": [{"over":1}, {"over":2}, {"over":3}, 33]
	\\}
	,false);
	defer typed.deinit();

	const values = typed.array("values").?;
	try std.testing.expectEqual(@as(usize, 4), values.items.len);
	try std.testing.expectEqual(@as(i64, 1), object(values.items[0]).?.int("over").?);
	try std.testing.expectEqual(@as(i64, 2), object(values.items[1]).?.int("over").?);
	try std.testing.expectEqual(@as(i64, 3), object(values.items[2]).?.int("over").?);
	try std.testing.expectEqual(@as(?Typed, null), object(values.items[3]));
}


