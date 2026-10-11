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

// User filter: an event no kernel source fires; our own code triggers it.
test "delivers a triggered user event" {
    const kq = sys.kqueue();
    defer _ = sys.close(kq);

    const add = [_]sys.Kevent{.{
        .ident = 7,
        .filter = sys.USER.FILTER,
        .flags = sys.EV.ADD,
        .fflags = 0,
        .data = 0,
        .udata = null,
    }};
    // register event listening for User Events.
    const added = sys.kevent(kq, &add, add.len, null, 0, null);
    try std.testing.expectEqual(0, added);

    const trigger = [_]sys.Kevent{.{
        .ident = 7,
        .filter = sys.USER.FILTER,
        .flags = 0,
        .fflags = sys.USER.TRIGGER,
        .data = 0,
        .udata = null,
    }};
    // null will block indefinitely
    const now: sys.Timespec = .{ .sec = 0, .nsec = 0 };
    var events: [1]sys.Kevent = undefined;
    // trigger User Event and then collect it in events.
    const ready = sys.kevent(kq, &trigger, trigger.len, &events, events.len, &now);
    try std.testing.expectEqual(1, ready);

    try std.testing.expectEqual(7, events[0].ident);
    try std.testing.expectEqual(sys.USER.FILTER, events[0].filter);
}

test "reports a socket readable after its peer writes" {
    var fds: [2]c_int = undefined;
    try std.testing.expectEqual(0, sys.socketpair(sys.AF.UNIX, sys.SOCK.STREAM, 0, &fds));
    defer _ = sys.close(fds[0]);
    defer _ = sys.close(fds[1]);

    const kq = sys.kqueue();
    defer _ = sys.close(kq);

    const add = [_]sys.Kevent{.{
        .ident = @intCast(fds[1]),
        .filter = sys.READ.FILTER,
        .flags = sys.EV.ADD,
        .fflags = 0,
        .data = 0,
        .udata = null,
    }};
    // watch fds[1] for incoming bytes.
    try std.testing.expectEqual(0, sys.kevent(kq, &add, add.len, null, 0, null));

    // send from the other end.
    try std.testing.expectEqual(2, sys.write(fds[0], "hi", 2));

    const now: sys.Timespec = .{ .sec = 0, .nsec = 0 };
    var events: [1]sys.Kevent = undefined;
    // collect readiness without blocking.
    const ready = sys.kevent(kq, null, 0, &events, events.len, &now);
    try std.testing.expectEqual(1, ready);

    try std.testing.expectEqual(@as(usize, @intCast(fds[1])), events[0].ident);
    try std.testing.expectEqual(sys.READ.FILTER, events[0].filter);
    // data holds the number of bytes waiting to be read.
    try std.testing.expectEqual(2, events[0].data);

    var buf: [2]u8 = undefined;
    try std.testing.expectEqual(2, sys.read(fds[1], &buf, buf.len));
    try std.testing.expectEqualStrings("hi", &buf);
}
