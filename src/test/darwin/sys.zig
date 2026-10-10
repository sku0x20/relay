const std = @import("std");
const sys = @import("../../main/darwin/sys.zig");

test "opens and closes a kqueue" {
    const fd = sys.kqueue();
    try std.testing.expect(fd >= 0);
    try std.testing.expectEqual(0, sys.close(fd));
}

test "reports EBADF closing an invalid descriptor" {
    const rc = sys.close(-1);
    try std.testing.expectEqual(-1, rc);
    try std.testing.expectEqual(sys.E.BADF, sys.errno(rc));
}

test "lays out Kevent like struct kevent" {
    try std.testing.expectEqual(32, @sizeOf(sys.Kevent));
    try std.testing.expectEqual(0, @offsetOf(sys.Kevent, "ident"));
    try std.testing.expectEqual(8, @offsetOf(sys.Kevent, "filter"));
    try std.testing.expectEqual(10, @offsetOf(sys.Kevent, "flags"));
    try std.testing.expectEqual(12, @offsetOf(sys.Kevent, "fflags"));
    try std.testing.expectEqual(16, @offsetOf(sys.Kevent, "data"));
    try std.testing.expectEqual(24, @offsetOf(sys.Kevent, "udata"));
}

test "delivers a triggered user event" {
    const kq = sys.kqueue();
    defer _ = sys.close(kq);

    const add = [_]sys.Kevent{.{
        .ident = 7,
        .filter = sys.EVFILT.USER,
        .flags = sys.EV.ADD,
        .fflags = 0,
        .data = 0,
        .udata = null,
    }};
    try std.testing.expectEqual(0, sys.kevent(kq, &add, 1, null, 0, null));

    const trigger = [_]sys.Kevent{.{
        .ident = 7,
        .filter = sys.EVFILT.USER,
        .flags = 0,
        .fflags = sys.NOTE.TRIGGER,
        .data = 0,
        .udata = null,
    }};
    const now: sys.Timespec = .{ .sec = 0, .nsec = 0 };
    var events: [1]sys.Kevent = undefined;
    try std.testing.expectEqual(1, sys.kevent(kq, &trigger, 1, &events, 1, &now));
    try std.testing.expectEqual(7, events[0].ident);
    try std.testing.expectEqual(sys.EVFILT.USER, events[0].filter);
}
