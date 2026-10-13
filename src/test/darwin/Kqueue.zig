const std = @import("std");
const Kqueue = @import("../../main/darwin/Kqueue.zig");
const sys = @import("../../main/darwin/sys.zig");

test "init and deinit" {
    const kq = try Kqueue.init();
    defer kq.deinit();
}

test "closing invalid kqueue" {
    const kq = Kqueue{
        .fd = -1,
    };
    try std.testing.expectError(error.BadFd, kq.close());
}

test "applies user event" {
    const kq = try Kqueue.init();
    defer kq.deinit();

    try kq.apply(&.{.{
        .fd = 7,
        .filter = sys.USER.FILTER,
        .flags = sys.EV.ADD,
        .fflags = 0,
        .data = 0,
        .userData = null,
    }});
}

test "deleting unregistered event" {
    const kq = try Kqueue.init();
    defer kq.deinit();

    try std.testing.expectError(error.NotFound, kq.apply(&.{.{
        .fd = 1,
        .filter = sys.USER.FILTER,
        .flags = sys.EV.DELETE,
        .fflags = 0,
        .data = 0,
        .userData = null,
    }}));
}
