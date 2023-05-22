const std = @import("std");

const ArrayList = std.ArrayList;
const StringHashMap = std.StringHashMap;
const Allocator = std.mem.Allocator;

const M = @This();

pub const Date = struct {
	year: i16,
	month: u8,
	day: u8,

	const month_days = [_]u8{31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31};

	pub fn init(year: i16, month: u8, day: u8) !Date {
		if (month == 0 or month > 12) return error.InvalidDate;
		if (day == 0) return error.InvalidDate;

		const max_days = if (month == 2 and (@rem(year, 400) == 0 or (@rem(year, 100) != 0 and @rem(year, 4) == 0))) 29 else month_days[month - 1];
		if (day > max_days) return error.InvalidDate;

		return .{
			.year = year,
			.month = month,
			.day = day,
		};
	}

	pub fn parse(input: []const u8) !Date {
		if (input.len < 8) return error.InvalidDate;

		var negative = false;
		var buf = input;
		if (input[0] == '-') {
			buf = input[1..];
			negative = true;
		}
		var year = parseInt(i16, buf[0..4]) orelse return error.InvalidDate;
		if (negative) {
			year = -year;
		}

		// YYYY-MM-DD
		if (buf.len == 10 and buf[4] == '-' and buf[7] == '-') {
			const month = parseInt(u8, buf[5..7]) orelse return error.InvalidDate;
			const day = parseInt(u8, buf[8..10]) orelse return error.InvalidDate;
			return init(year, month, day);
		}

		// YYYYMMDD
		const month = parseInt(u8, buf[4..6]) orelse return error.InvalidDate;
		const day = parseInt(u8, buf[6..8]) orelse return error.InvalidDate;
		return init(year, month, day);
	}

	pub fn order(a: Date, b: Date) std.math.Order {
		const year_order = std.math.order(a.year, b.year);
		if (year_order != .eq) return year_order;

		const month_order = std.math.order(a.month, b.month);
		if (month_order != .eq) return month_order;

		return std.math.order(a.day, b.day);
	}

	pub fn format(self: Date, comptime _: []const u8, _: std.fmt.FormatOptions, out: anytype) !void {
		var buf: [11]u8 = undefined;
		const n = self.bufWrite(&buf);
		try out.writeAll(buf[0..n]);
	}

	pub fn jsonStringify(self: Date, _: std.json.StringifyOptions, out: anytype) anyerror!void {
		// Our goal here isn't to validate the date. It's to write what we have
		// in a YYYY-MM-DD format. If the data in Date isn't valid, that's not
		// our problem and we don't guarantee any reasonable output in such cases.

		// std.fmt.formatInt is difficult to work with. The padding with signs
		// doesn't work and it'll always put a + sign given a signed integer with padding
		// So, for year, we always feed it an unsigned number (which avoids both issues)
		// and prepend the - if we need it.s
		var buf: [13]u8 = undefined;
		const n = self.bufWrite(buf[1..12]);
		buf[0] = '"';
		buf[n+1] = '"';
		try out.writeAll(buf[0..n+2]);
	}

	fn bufWrite(self: Date, into: []u8) u8 {
		std.debug.assert(into.len == 11);
		const year = self.year;
		var buf: []u8 = undefined;
		// cast this to a u16 so it doesn't insert a sign
		// we don't want the + sign, ever
		// and we don't even want it to insert the - sign, because it screws up
		// the padding (we need to do it ourselfs)
		if (year < 0) {
			_ = std.fmt.formatIntBuf(into[1..], @intCast(u16, year * -1), 10, .lower, .{.width = 4, .fill = '0'});
			into[0] = '-';
			buf = into[5..];
		} else {
			_ = std.fmt.formatIntBuf(into, @intCast(u16, year), 10, .lower, .{.width = 4, .fill = '0'});
			buf = into[4..];
		}

		buf[0] = '-';
		paddingTwoDigits(buf[1..3], self.month);
		buf[3] = '-';
		paddingTwoDigits(buf[4..6], self.day);

		if (year < 0) {
			return 11;
		}
		// we didn't write the leading +
		return 10;
	}
};

pub const Time = struct {
	hour: u8,
	min: u8,
	sec: u8,
	micros: u32 = 0,

	pub fn init(hour: u8, min: u8, sec: u8, micros: u32) !Time {
		if (hour > 23) return error.InvalidTime;
		if (min > 59) return error.InvalidTime;
		if (sec > 59) return error.InvalidTime;
		if (micros > 999999) return error.InvalidTime;

		return .{
			.hour = hour,
			.min = min,
			.sec = sec,
			.micros = micros,
		};
	}

	pub fn parse(input: []const u8) !Time {
		const len = input.len;
		if (len < 8 or len > 15 or len == 9) return error.InvalidTime;
		if (input[2] != ':' or input[5] != ':') return error.InvalidTime;

		const hour = parseInt(u8, input[0..2]) orelse return error.InvalidTime;
		const min = parseInt(u8, input[3..5]) orelse return error.InvalidTime;
		const sec = parseInt(u8, input[6..8]) orelse return error.InvalidTime;
		var micros: u32 = 0;

		// we already guarded against len == 9 (which would be invalid)
		if (len > 9) {
			if (input[8] != '.') return error.InvalidTime;
			const tmp = parseInt(u32, input[9..]) orelse return error.InvalidTime;
			micros = switch (len) {
				10 => tmp * 100000,
				11 => tmp * 10000,
				12 => tmp * 1000,
				13 => tmp * 100,
				14 => tmp * 10,
				15 => tmp,
				else => unreachable,
			};
		}
		return init(hour, min, sec, micros);
	}

	pub fn order(a: Time, b: Time) std.math.Order {
		const hour_order = std.math.order(a.hour, b.hour);
		if (hour_order != .eq) return hour_order;

		const min_order = std.math.order(a.min, b.min);
		if (min_order != .eq) return min_order;

		const sec_order = std.math.order(a.sec, b.sec);
		if (sec_order != .eq) return sec_order;

		return std.math.order(a.micros, b.micros);
	}

	pub fn format(self: Time, comptime _: []const u8, _: std.fmt.FormatOptions, out: anytype) !void {
		var buf: [15]u8 = undefined;
		const n = self.bufWrite(&buf);
		try out.writeAll(buf[0..n]);
	}

	pub fn jsonStringify(self: Time, _: std.json.StringifyOptions, out: anytype) anyerror!void {
		// Our goal here isn't to validate the time. It's to write what we have
		// in a hh:mm:ss.sss format. If the data in Time isn't valid, that's not
		// our problem and we don't guarantee any reasonable output in such cases.
		var buf: [17]u8 = undefined;
		const n = self.bufWrite(buf[1..16]);
		buf[0] = '"';
		buf[n+1] = '"';
		try out.writeAll(buf[0..n+2]);
	}

	fn bufWrite(self: Time, buf: []u8) u8 {
		std.debug.assert(buf.len == 15);
		paddingTwoDigits(buf[0..2], self.hour);
		buf[2] = ':';
		paddingTwoDigits(buf[3..5], self.min);
		buf[5] = ':';
		paddingTwoDigits(buf[6..8], self.sec);

		const micros = self.micros;
		if (micros == 0) {
			return 8;
		}
		if (@rem(micros, 1000) == 0) {
			buf[8] = '.';
			_ = std.fmt.formatIntBuf(buf[9..12], micros / 1000, 10, .lower, .{.width = 3, .fill = '0'});
			return 12;
		}
		buf[8] = '.';
		_ = std.fmt.formatIntBuf(buf[9..15], micros, 10, .lower, .{.width = 6, .fill = '0'});
		return 15;
	}
};

pub const Timestamp = struct {
	micros: u64,

	pub fn order(a: Timestamp, b: Timestamp) std.math.Order {
		return std.math.order(a.micros, b.micros);
	}
};

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
	timestamp,
	date,
};

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
};

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
			if (T == Date) {
				return .{.date = value};
			}
			if (T == Time) {
				return .{.time = value};
			}
			if (T == Timestamp) {
				return .{.timestamp = value};
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

fn paddingTwoDigits(buf: *[2]u8, value: u8) void {
	switch (value) {
		0 => buf.* = "00".*,
		1 => buf.* = "01".*,
		2 => buf.* = "02".*,
		3 => buf.* = "03".*,
		4 => buf.* = "04".*,
		5 => buf.* = "05".*,
		6 => buf.* = "06".*,
		7 => buf.* = "07".*,
		8 => buf.* = "08".*,
		9 => buf.* = "09".*,
		10 => buf.* = "10".*,
		11 => buf.* = "11".*,
		12 => buf.* = "12".*,
		13 => buf.* = "13".*,
		14 => buf.* = "14".*,
		15 => buf.* = "15".*,
		16 => buf.* = "16".*,
		17 => buf.* = "17".*,
		18 => buf.* = "18".*,
		19 => buf.* = "19".*,
		20 => buf.* = "20".*,
		21 => buf.* = "21".*,
		22 => buf.* = "22".*,
		23 => buf.* = "23".*,
		24 => buf.* = "24".*,
		25 => buf.* = "25".*,
		26 => buf.* = "26".*,
		27 => buf.* = "27".*,
		28 => buf.* = "28".*,
		29 => buf.* = "29".*,
		30 => buf.* = "30".*,
		31 => buf.* = "31".*,
		32 => buf.* = "32".*,
		33 => buf.* = "33".*,
		34 => buf.* = "34".*,
		35 => buf.* = "35".*,
		36 => buf.* = "36".*,
		37 => buf.* = "37".*,
		38 => buf.* = "38".*,
		39 => buf.* = "39".*,
		40 => buf.* = "40".*,
		41 => buf.* = "41".*,
		42 => buf.* = "42".*,
		43 => buf.* = "43".*,
		44 => buf.* = "44".*,
		45 => buf.* = "45".*,
		46 => buf.* = "46".*,
		47 => buf.* = "47".*,
		48 => buf.* = "48".*,
		49 => buf.* = "49".*,
		50 => buf.* = "50".*,
		51 => buf.* = "51".*,
		52 => buf.* = "52".*,
		53 => buf.* = "53".*,
		54 => buf.* = "54".*,
		55 => buf.* = "55".*,
		56 => buf.* = "56".*,
		57 => buf.* = "57".*,
		58 => buf.* = "58".*,
		59 => buf.* = "59".*,
		else => _ = std.fmt.formatIntBuf(buf, value, 10, .lower, .{}),
	}
}

fn parseInt(comptime T: type, buf: []const u8) ?T {
	// std.debug.print("{s}\n", .{buf});
	var total: T = 0;
	for (buf)  |b| {
		const n = b -% '0'; // wrapping subtraction
		if (n > 9) return null;
		total = total * 10 + n;
	}
	return total;
}

const t = std.testing;
test "value" {
	var map = Map.init(t.allocator);
	defer map.deinit();

	try map.put("key", Value{.i64 = 331});
	try t.expectEqual(@as(i64, 331), map.get(i64, "key").?);
}

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

test "json: date" {
	{
		// date, positive year
		const date = Date{.year = 2023, .month = 9, .day = 22};
		const out = try std.json.stringifyAlloc(t.allocator, Value{.date = date}, .{});
		defer t.allocator.free(out);
		try t.expectEqualStrings("\"2023-09-22\"", out);
	}

	{
		// date, negative year
		const date = Date{.year = -4, .month = 12, .day = 3};
		const out = try std.json.stringifyAlloc(t.allocator, Value{.date = date}, .{});
		defer t.allocator.free(out);
		try t.expectEqualStrings("\"-0004-12-03\"", out);
	}
}

test "json: time" {
	{
		// time no fraction
		const time = Time{.hour = 23, .min = 59, .sec = 2};
		const out = try std.json.stringifyAlloc(t.allocator, Value{.time = time}, .{});
		defer t.allocator.free(out);
		try t.expectEqualStrings("\"23:59:02\"", out);
	}

	{
		// time, milliseconds only
		const time = Time{.hour = 7, .min = 9, .sec = 32, .micros = 202000};
		const out = try std.json.stringifyAlloc(t.allocator, Value{.time = time}, .{});
		defer t.allocator.free(out);
		try t.expectEqualStrings("\"07:09:32.202\"", out);
	}


	{
		// time, micros
		const time = Time{.hour = 1, .min = 2, .sec = 3, .micros = 123456};
		const out = try std.json.stringifyAlloc(t.allocator, Value{.time = time}, .{});
		defer t.allocator.free(out);
		try t.expectEqualStrings("\"01:02:03.123456\"", out);
	}
}

test "Date.format" {
	{
		var buf: [20]u8 = undefined;
		const out = try std.fmt.bufPrint(&buf, "{s}", .{Date{.year = 2023, .month = 5, .day = 22}});
		try t.expectEqualStrings("2023-05-22", out);
	}

	{
		var buf: [20]u8 = undefined;
		const out = try std.fmt.bufPrint(&buf, "{s}", .{Date{.year = -102, .month = 12, .day = 9}});
		try t.expectEqualStrings("-0102-12-09", out);
	}
}

test "Date.parse" {
	{
		//valid YYYY-MM-DD
		try t.expectEqual(Date{.year = 2023, .month = 5, .day = 22}, try Date.parse("2023-05-22"));
		try t.expectEqual(Date{.year = -2023, .month = 2, .day = 3}, try Date.parse("-2023-02-03"));
		try t.expectEqual(Date{.year = 1, .month = 2, .day = 3}, try Date.parse("0001-02-03"));
		try t.expectEqual(Date{.year = -1, .month = 2, .day = 3}, try Date.parse("-0001-02-03"));
	}

	{
		//valid YYYYMMDD
		try t.expectEqual(Date{.year = 2023, .month = 5, .day = 22}, try Date.parse("20230522"));
		try t.expectEqual(Date{.year = -2023, .month = 2, .day = 3}, try Date.parse("-20230203"));
		try t.expectEqual(Date{.year = 1, .month = 2, .day = 3}, try Date.parse("00010203"));
		try t.expectEqual(Date{.year = -1, .month = 2, .day = 3}, try Date.parse("-00010203"));
	}

	{
		// invalid format
		try t.expectError(error.InvalidDate, Date.parse(""));
		try t.expectError(error.InvalidDate, Date.parse("2023/01-02"));
		try t.expectError(error.InvalidDate, Date.parse("2023-01/02"));
		try t.expectError(error.InvalidDate, Date.parse("0001-01-01 "));
		try t.expectError(error.InvalidDate, Date.parse("2023-1-02"));
		try t.expectError(error.InvalidDate, Date.parse("2023-01-2"));
		try t.expectError(error.InvalidDate, Date.parse("9-01-2"));
		try t.expectError(error.InvalidDate, Date.parse("99-01-2"));
		try t.expectError(error.InvalidDate, Date.parse("999-01-2"));
		try t.expectError(error.InvalidDate, Date.parse("-999-01-2"));
		try t.expectError(error.InvalidDate, Date.parse("-1-01-2"));
	}

	{
		// invalid month
		try t.expectError(error.InvalidDate, Date.parse("2023-00-22"));
		try t.expectError(error.InvalidDate, Date.parse("2023-0A-22"));
		try t.expectError(error.InvalidDate, Date.parse("2023-13-22"));
		try t.expectError(error.InvalidDate, Date.parse("2023-99-22"));
		try t.expectError(error.InvalidDate, Date.parse("-2023-00-22"));
		try t.expectError(error.InvalidDate, Date.parse("-2023-13-22"));
		try t.expectError(error.InvalidDate, Date.parse("-2023-99-22"));

		try t.expectError(error.InvalidDate, Date.parse("20230022"));
		try t.expectError(error.InvalidDate, Date.parse("20230A22"));
		try t.expectError(error.InvalidDate, Date.parse("20231322"));
		try t.expectError(error.InvalidDate, Date.parse("20239922"));
		try t.expectError(error.InvalidDate, Date.parse("-20230022"));
		try t.expectError(error.InvalidDate, Date.parse("-20231322"));
		try t.expectError(error.InvalidDate, Date.parse("-20239922"));
	}

	{
		// invalid day
		try t.expectError(error.InvalidDate, Date.parse("2023-01-00"));
		try t.expectError(error.InvalidDate, Date.parse("2023-01-32"));
		try t.expectError(error.InvalidDate, Date.parse("2023-02-29"));
		try t.expectError(error.InvalidDate, Date.parse("2023-03-32"));
		try t.expectError(error.InvalidDate, Date.parse("2023-04-31"));
		try t.expectError(error.InvalidDate, Date.parse("2023-05-32"));
		try t.expectError(error.InvalidDate, Date.parse("2023-06-31"));
		try t.expectError(error.InvalidDate, Date.parse("2023-07-32"));
		try t.expectError(error.InvalidDate, Date.parse("2023-08-32"));
		try t.expectError(error.InvalidDate, Date.parse("2023-09-31"));
		try t.expectError(error.InvalidDate, Date.parse("2023-10-32"));
		try t.expectError(error.InvalidDate, Date.parse("2023-11-31"));
		try t.expectError(error.InvalidDate, Date.parse("2023-12-32"));
	}

	{
		// valid (max day)
		try t.expectEqual(Date{.year = 2023, .month = 1, .day = 31}, try Date.parse("2023-01-31"));
		try t.expectEqual(Date{.year = 2023, .month = 2, .day = 28}, try Date.parse("2023-02-28"));
		try t.expectEqual(Date{.year = 2023, .month = 3, .day = 31}, try Date.parse("2023-03-31"));
		try t.expectEqual(Date{.year = 2023, .month = 4, .day = 30}, try Date.parse("2023-04-30"));
		try t.expectEqual(Date{.year = 2023, .month = 5, .day = 31}, try Date.parse("2023-05-31"));
		try t.expectEqual(Date{.year = 2023, .month = 6, .day = 30}, try Date.parse("2023-06-30"));
		try t.expectEqual(Date{.year = 2023, .month = 7, .day = 31}, try Date.parse("2023-07-31"));
		try t.expectEqual(Date{.year = 2023, .month = 8, .day = 31}, try Date.parse("2023-08-31"));
		try t.expectEqual(Date{.year = 2023, .month = 9, .day = 30}, try Date.parse("2023-09-30"));
		try t.expectEqual(Date{.year = 2023, .month = 10, .day = 31}, try Date.parse("2023-10-31"));
		try t.expectEqual(Date{.year = 2023, .month = 11, .day = 30}, try Date.parse("2023-11-30"));
		try t.expectEqual(Date{.year = 2023, .month = 12, .day = 31}, try Date.parse("2023-12-31"));
	}

	{
		// leap years
		try t.expectEqual(Date{.year = 2000, .month = 2, .day = 29}, try Date.parse("2000-02-29"));
		try t.expectEqual(Date{.year = 2400, .month = 2, .day = 29}, try Date.parse("2400-02-29"));
		try t.expectEqual(Date{.year = 2012, .month = 2, .day = 29}, try Date.parse("2012-02-29"));
		try t.expectEqual(Date{.year = 2024, .month = 2, .day = 29}, try Date.parse("2024-02-29"));

		try t.expectError(error.InvalidDate, Date.parse("2000-02-30"));
		try t.expectError(error.InvalidDate, Date.parse("2400-02-30"));
		try t.expectError(error.InvalidDate, Date.parse("2012-02-30"));
		try t.expectError(error.InvalidDate, Date.parse("2024-02-30"));

		try t.expectError(error.InvalidDate, Date.parse("2100-02-29"));
		try t.expectError(error.InvalidDate, Date.parse("2200-02-29"));
	}
}

test "Date.order" {
	{
		const a = Date{.year = 2023, .month = 5, .day = 22};
		const b = Date{.year = 2023, .month = 5, .day = 22};
		try t.expectEqual(std.math.Order.eq, a.order(b));
	}

	{
		{
			const a = Date{.year = 2023, .month = 5, .day = 22};
			const b = Date{.year = 2022, .month = 5, .day = 22};
			try t.expectEqual(std.math.Order.gt, a.order(b));
			try t.expectEqual(std.math.Order.lt, b.order(a));
		}

		{
			const a = Date{.year = 2022, .month = 6, .day = 22};
			const b = Date{.year = 2022, .month = 5, .day = 22};
			try t.expectEqual(std.math.Order.gt, a.order(b));
			try t.expectEqual(std.math.Order.lt, b.order(a));
		}

		{
			const a = Date{.year = 2023, .month = 5, .day = 23};
			const b = Date{.year = 2022, .month = 5, .day = 22};
			try t.expectEqual(std.math.Order.gt, a.order(b));
			try t.expectEqual(std.math.Order.lt, b.order(a));
		}
	}
}

test "Time.format" {
	{
		var buf: [20]u8 = undefined;
		const out = try std.fmt.bufPrint(&buf, "{s}", .{Time{.hour = 23, .min = 59, .sec = 59, .micros = 0}});
		try t.expectEqualStrings("23:59:59", out);
	}

	{
		var buf: [20]u8 = undefined;
		const out = try std.fmt.bufPrint(&buf, "{s}", .{Time{.hour = 8, .min = 9, .sec = 10, .micros = 12}});
		try t.expectEqualStrings("08:09:10.000012", out);
	}

	{
		var buf: [20]u8 = undefined;
		const out = try std.fmt.bufPrint(&buf, "{s}", .{Time{.hour = 8, .min = 9, .sec = 10, .micros = 123}});
		try t.expectEqualStrings("08:09:10.000123", out);
	}

	{
		var buf: [20]u8 = undefined;
		const out = try std.fmt.bufPrint(&buf, "{s}", .{Time{.hour = 8, .min = 9, .sec = 10, .micros = 1234}});
		try t.expectEqualStrings("08:09:10.001234", out);
	}

	{
		var buf: [20]u8 = undefined;
		const out = try std.fmt.bufPrint(&buf, "{s}", .{Time{.hour = 8, .min = 9, .sec = 10, .micros = 12345}});
		try t.expectEqualStrings("08:09:10.012345", out);
	}

	{
		var buf: [20]u8 = undefined;
		const out = try std.fmt.bufPrint(&buf, "{s}", .{Time{.hour = 8, .min = 9, .sec = 10, .micros = 123456}});
		try t.expectEqualStrings("08:09:10.123456", out);
	}


}

test "Time.parse" {
	{
		//valid
		try t.expectEqual(Time{.hour = 9, .min = 8, .sec = 5, .micros = 123000}, try Time.parse("09:08:05.123"));
		try t.expectEqual(Time{.hour = 23, .min = 59, .sec = 59, .micros = 0}, try Time.parse("23:59:59"));
		try t.expectEqual(Time{.hour = 0, .min = 0, .sec = 0, .micros = 0}, try Time.parse("00:00:00"));
		try t.expectEqual(Time{.hour = 0, .min = 0, .sec = 0, .micros = 0}, try Time.parse("00:00:00.0"));
		try t.expectEqual(Time{.hour = 0, .min = 0, .sec = 0, .micros = 1}, try Time.parse("00:00:00.000001"));
		try t.expectEqual(Time{.hour = 0, .min = 0, .sec = 0, .micros = 12}, try Time.parse("00:00:00.000012"));
		try t.expectEqual(Time{.hour = 0, .min = 0, .sec = 0, .micros = 123}, try Time.parse("00:00:00.000123"));
		try t.expectEqual(Time{.hour = 0, .min = 0, .sec = 0, .micros = 1234}, try Time.parse("00:00:00.001234"));
		try t.expectEqual(Time{.hour = 0, .min = 0, .sec = 0, .micros = 12345}, try Time.parse("00:00:00.012345"));
		try t.expectEqual(Time{.hour = 0, .min = 0, .sec = 0, .micros = 123456}, try Time.parse("00:00:00.123456"));
	}

	{
		try t.expectError(error.InvalidTime, Time.parse(""));
		try t.expectError(error.InvalidTime, Time.parse("1:00:00"));
		try t.expectError(error.InvalidTime, Time.parse("10:1:00"));
		try t.expectError(error.InvalidTime, Time.parse("10:11:4"));
		try t.expectError(error.InvalidTime, Time.parse("10:20:30."));
		try t.expectError(error.InvalidTime, Time.parse("10:20:30.a"));
		try t.expectError(error.InvalidTime, Time.parse("10:20:30.1234567"));
		try t.expectError(error.InvalidTime, Time.parse("24:00:00"));
		try t.expectError(error.InvalidTime, Time.parse("00:60:00"));
		try t.expectError(error.InvalidTime, Time.parse("00:00:60"));
		try t.expectError(error.InvalidTime, Time.parse("0a:00:00"));
		try t.expectError(error.InvalidTime, Time.parse("00:0a:00"));
		try t.expectError(error.InvalidTime, Time.parse("00:00:0a"));
		try t.expectError(error.InvalidTime, Time.parse("00/00:00"));
		try t.expectError(error.InvalidTime, Time.parse("00:00 00"));

	}
}

test "Time.order" {
	{
		const a = Time{.hour = 19, .min = 17, .sec = 22, .micros = 101002};
		const b = Time{.hour = 19, .min = 17, .sec = 22, .micros = 101002};
		try t.expectEqual(std.math.Order.eq, a.order(b));
	}

	{
		{
			const a = Time{.hour = 20, .min = 17, .sec = 22, .micros = 101002};
			const b = Time{.hour = 19, .min = 17, .sec = 22, .micros = 101002};
			try t.expectEqual(std.math.Order.gt, a.order(b));
			try t.expectEqual(std.math.Order.lt, b.order(a));
		}

		{
			const a = Time{.hour = 19, .min = 18, .sec = 22, .micros = 101002};
			const b = Time{.hour = 19, .min = 17, .sec = 22, .micros = 101002};
			try t.expectEqual(std.math.Order.gt, a.order(b));
			try t.expectEqual(std.math.Order.lt, b.order(a));
		}

		{
			const a = Time{.hour = 19, .min = 17, .sec = 23, .micros = 101002};
			const b = Time{.hour = 19, .min = 17, .sec = 22, .micros = 101002};
			try t.expectEqual(std.math.Order.gt, a.order(b));
			try t.expectEqual(std.math.Order.lt, b.order(a));
		}

		{
			const a = Time{.hour = 19, .min = 17, .sec = 22, .micros = 101003};
			const b = Time{.hour = 19, .min = 17, .sec = 22, .micros = 101002};
			try t.expectEqual(std.math.Order.gt, a.order(b));
			try t.expectEqual(std.math.Order.lt, b.order(a));
		}
	}
}

test "Timestamp.order" {
	{
		const a = Timestamp{.micros = 1684746656160};
		const b = Timestamp{.micros = 1684746656160};
		try t.expectEqual(std.math.Order.eq, a.order(b));
	}

	{
		const a = Timestamp{.micros = 1684746656161};
		const b = Timestamp{.micros = 1684746656160};
		try t.expectEqual(std.math.Order.gt, a.order(b));
		try t.expectEqual(std.math.Order.lt, b.order(a));
	}
}
