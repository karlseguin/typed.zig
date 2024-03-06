const std = @import("std");

pub const allocator = std.testing.allocator;

// std.testing.expectEqual won't coerce expected to actual, which is a problem
// when expected is frequently a comptime.
// https://github.com/ziglang/zig/issues/4437
pub fn expectEqual(expected: anytype, actual: anytype) !void {
	try std.testing.expectEqual(@as(@TypeOf(actual), expected), actual);
}
pub const expectError = std.testing.expectError;
pub const expectString = std.testing.expectEqualStrings;

pub fn print(comptime fmt: []const u8, args: anytype) void {
	if (@inComptime()) {
		@compileError(std.fmt.comptimePrint(fmt, args));
	} else {
		std.debug.print(fmt, args);
	}
}

pub fn expectDelta(expected: anytype, actual: anytype, delta: anytype) !void {
	var diff = expected - actual;
	if (diff < 0) {
		diff = -diff;
	}
	if (diff <= delta) {
		return;
	}

	print("Expected {} to be within {} of {}. Actual diff: {}", .{expected, delta, actual, diff});
	return error.NotWithinDelta;
}
