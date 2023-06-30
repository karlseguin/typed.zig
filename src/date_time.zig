const std = @import("std");
const typed = @import("typed.zig");

const Value = typed.Value;

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
			_ = std.fmt.formatIntBuf(into[1..], @as(u16, @intCast(year * -1)), 10, .lower, .{.width = 4, .fill = '0'});
			into[0] = '-';
			buf = into[5..];
		} else {
			_ = std.fmt.formatIntBuf(into, @as(u16, @intCast(year)), 10, .lower, .{.width = 4, .fill = '0'});
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
		if (len < 5 or input[2] != ':') return error.InvalidTime;

		const hour = parseInt(u8, input[0..2]) orelse return error.InvalidTime;
		const min = parseInt(u8, input[3..5]) orelse return error.InvalidTime;
		if (len == 5) {
			return init(hour, min, 0, 0);
		}

		if (len < 8 or len > 15 or len == 9) return error.InvalidTime;
		if (input[5] != ':') return error.InvalidTime;

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
	micros: i64,

	pub fn order(a: Timestamp, b: Timestamp) std.math.Order {
		return std.math.order(a.micros, b.micros);
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

const t = @import("t.zig");
test "date: json" {
	{
		// date, positive year
		const date = Date{.year = 2023, .month = 9, .day = 22};
		const out = try std.json.stringifyAlloc(t.allocator, Value{.date = date}, .{});
		defer t.allocator.free(out);
		try t.expectString("\"2023-09-22\"", out);
	}

	{
		// date, negative year
		const date = Date{.year = -4, .month = 12, .day = 3};
		const out = try std.json.stringifyAlloc(t.allocator, Value{.date = date}, .{});
		defer t.allocator.free(out);
		try t.expectString("\"-0004-12-03\"", out);
	}
}

test "date: format" {
	{
		var buf: [20]u8 = undefined;
		const out = try std.fmt.bufPrint(&buf, "{s}", .{Date{.year = 2023, .month = 5, .day = 22}});
		try t.expectString("2023-05-22", out);
	}

	{
		var buf: [20]u8 = undefined;
		const out = try std.fmt.bufPrint(&buf, "{s}", .{Date{.year = -102, .month = 12, .day = 9}});
		try t.expectString("-0102-12-09", out);
	}
}

test "date: parse" {
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

test "date: order" {
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

test "time: json" {
	{
		// time no fraction
		const time = Time{.hour = 23, .min = 59, .sec = 2};
		const out = try std.json.stringifyAlloc(t.allocator, Value{.time = time}, .{});
		defer t.allocator.free(out);
		try t.expectString("\"23:59:02\"", out);
	}

	{
		// time, milliseconds only
		const time = Time{.hour = 7, .min = 9, .sec = 32, .micros = 202000};
		const out = try std.json.stringifyAlloc(t.allocator, Value{.time = time}, .{});
		defer t.allocator.free(out);
		try t.expectString("\"07:09:32.202\"", out);
	}


	{
		// time, micros
		const time = Time{.hour = 1, .min = 2, .sec = 3, .micros = 123456};
		const out = try std.json.stringifyAlloc(t.allocator, Value{.time = time}, .{});
		defer t.allocator.free(out);
		try t.expectString("\"01:02:03.123456\"", out);
	}
}

test "time: format" {
	{
		var buf: [20]u8 = undefined;
		const out = try std.fmt.bufPrint(&buf, "{s}", .{Time{.hour = 23, .min = 59, .sec = 59, .micros = 0}});
		try t.expectString("23:59:59", out);
	}

	{
		var buf: [20]u8 = undefined;
		const out = try std.fmt.bufPrint(&buf, "{s}", .{Time{.hour = 8, .min = 9, .sec = 10, .micros = 12}});
		try t.expectString("08:09:10.000012", out);
	}

	{
		var buf: [20]u8 = undefined;
		const out = try std.fmt.bufPrint(&buf, "{s}", .{Time{.hour = 8, .min = 9, .sec = 10, .micros = 123}});
		try t.expectString("08:09:10.000123", out);
	}

	{
		var buf: [20]u8 = undefined;
		const out = try std.fmt.bufPrint(&buf, "{s}", .{Time{.hour = 8, .min = 9, .sec = 10, .micros = 1234}});
		try t.expectString("08:09:10.001234", out);
	}

	{
		var buf: [20]u8 = undefined;
		const out = try std.fmt.bufPrint(&buf, "{s}", .{Time{.hour = 8, .min = 9, .sec = 10, .micros = 12345}});
		try t.expectString("08:09:10.012345", out);
	}

	{
		var buf: [20]u8 = undefined;
		const out = try std.fmt.bufPrint(&buf, "{s}", .{Time{.hour = 8, .min = 9, .sec = 10, .micros = 123456}});
		try t.expectString("08:09:10.123456", out);
	}
}

test "time: parse" {
	{
		//valid
		try t.expectEqual(Time{.hour = 9, .min = 8, .sec = 0, .micros = 0}, try Time.parse("09:08"));
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
		try t.expectError(error.InvalidTime, Time.parse("01:00:"));
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

test "time: order" {
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

test "timestamp: order" {
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
