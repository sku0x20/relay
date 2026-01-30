const std = @import("std");

pub fn runCatching(func: anytype, args: anytype) void {
    @call(.auto, func, args) catch |err| {
        std.log.err("err: {s}\n", .{@errorName(err)});
    };
}
