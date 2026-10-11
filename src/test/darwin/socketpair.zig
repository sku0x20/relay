const std = @import("std");
const sys = @import("../../main/darwin/sys.zig");

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
    try std.testing.expectEqual(2, sys.send(fds[0], "hi", 2, 0));

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
    try std.testing.expectEqual(2, sys.recv(fds[1], &buf, buf.len, 0));
    try std.testing.expectEqualStrings("hi", &buf);
}

test "reports a full socket writable once its peer drains it" {
    var fds: [2]c_int = undefined;
    try std.testing.expectEqual(0, sys.socketpair(sys.AF.UNIX, sys.SOCK.STREAM, 0, &fds));
    defer _ = sys.close(fds[0]);
    defer _ = sys.close(fds[1]);

    // fail with EAGAIN instead of blocking, on both ends.
    for (fds) |fd| {
        const flags = sys.fcntl(fd, sys.F.GETFL);
        try std.testing.expectEqual(0, sys.fcntl(fd, sys.F.SETFL, flags | sys.O.NONBLOCK));
    }

    // fill fds[0]'s send buffer.
    const chunk = [_]u8{0} ** 4096;
    while (true) {
        const rc = sys.send(fds[0], &chunk, chunk.len, 0);
        if (rc == -1) {
            try std.testing.expectEqual(sys.E.AGAIN, sys.errno(rc));
            break;
        }
    }

    const kq = sys.kqueue();
    defer _ = sys.close(kq);

    const add = [_]sys.Kevent{.{
        .ident = @intCast(fds[0]),
        .filter = sys.WRITE.FILTER,
        .flags = sys.EV.ADD | sys.EV.CLEAR,
        .fflags = 0,
        .data = 0,
        .udata = null,
    }};
    // watch fds[0] for free space; CLEAR reports each change once.
    try std.testing.expectEqual(0, sys.kevent(kq, &add, add.len, null, 0, null));

    const now: sys.Timespec = .{ .sec = 0, .nsec = 0 };
    var events: [1]sys.Kevent = undefined;
    // full: not writable.
    try std.testing.expectEqual(0, sys.kevent(kq, null, 0, &events, events.len, &now));

    // drain from the other end.
    var buf: [4096]u8 = undefined;
    while (sys.recv(fds[1], &buf, buf.len, 0) > 0) {}

    // drained: writable.
    try std.testing.expectEqual(1, sys.kevent(kq, null, 0, &events, events.len, &now));
    try std.testing.expectEqual(@as(usize, @intCast(fds[0])), events[0].ident);
    try std.testing.expectEqual(sys.WRITE.FILTER, events[0].filter);
    // data holds the free space in the send buffer.
    try std.testing.expect(events[0].data > 0);

    // cleared: not reported again until the free space changes.
    try std.testing.expectEqual(0, sys.kevent(kq, null, 0, &events, events.len, &now));
}

test "reports EOF once its peer closes" {
    var fds: [2]c_int = undefined;
    try std.testing.expectEqual(0, sys.socketpair(sys.AF.UNIX, sys.SOCK.STREAM, 0, &fds));
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

    // hang up the other end.
    try std.testing.expectEqual(0, sys.close(fds[0]));

    const now: sys.Timespec = .{ .sec = 0, .nsec = 0 };
    var events: [1]sys.Kevent = undefined;
    // a hangup is reported as readable, flagged EOF.
    try std.testing.expectEqual(1, sys.kevent(kq, null, 0, &events, events.len, &now));
    try std.testing.expectEqual(@as(usize, @intCast(fds[1])), events[0].ident);
    try std.testing.expectEqual(sys.READ.FILTER, events[0].filter);
    try std.testing.expect(events[0].flags & sys.EV.EOF != 0);
    // nothing was sent, so nothing is left to read.
    try std.testing.expectEqual(0, events[0].data);

    // recv returns 0 at EOF.
    var buf: [1]u8 = undefined;
    try std.testing.expectEqual(0, sys.recv(fds[1], &buf, buf.len, 0));
}

test "forgets a socket once it is closed" {
    var fds: [2]c_int = undefined;
    try std.testing.expectEqual(0, sys.socketpair(sys.AF.UNIX, sys.SOCK.STREAM, 0, &fds));
    defer _ = sys.close(fds[0]);

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

    // make fds[1] readable, then close it before collecting.
    try std.testing.expectEqual(2, sys.send(fds[0], "hi", 2, 0));
    try std.testing.expectEqual(0, sys.close(fds[1]));

    const now: sys.Timespec = .{ .sec = 0, .nsec = 0 };
    var events: [1]sys.Kevent = undefined;
    // close removed the registration, pending event included.
    try std.testing.expectEqual(0, sys.kevent(kq, null, 0, &events, events.len, &now));
}

test "pauses reads while disabled" {
    var fds: [2]c_int = undefined;
    try std.testing.expectEqual(0, sys.socketpair(sys.AF.UNIX, sys.SOCK.STREAM, 0, &fds));
    defer _ = sys.close(fds[0]);
    defer _ = sys.close(fds[1]);

    const kq = sys.kqueue();
    defer _ = sys.close(kq);

    const add = [_]sys.Kevent{.{
        .ident = @intCast(fds[1]),
        .filter = sys.READ.FILTER,
        .flags = sys.EV.ADD | sys.EV.DISABLE,
        .fflags = 0,
        .data = 0,
        .udata = null,
    }};
    // watch fds[1] for incoming bytes, paused from the start.
    try std.testing.expectEqual(0, sys.kevent(kq, &add, add.len, null, 0, null));

    // send from the other end.
    try std.testing.expectEqual(2, sys.send(fds[0], "hi", 2, 0));

    const now: sys.Timespec = .{ .sec = 0, .nsec = 0 };
    var events: [1]sys.Kevent = undefined;
    // disabled: readable, but not reported.
    try std.testing.expectEqual(0, sys.kevent(kq, null, 0, &events, events.len, &now));

    const enable = [_]sys.Kevent{.{
        .ident = @intCast(fds[1]),
        .filter = sys.READ.FILTER,
        .flags = sys.EV.ENABLE,
        .fflags = 0,
        .data = 0,
        .udata = null,
    }};
    // resume, and collect what was held back.
    try std.testing.expectEqual(1, sys.kevent(kq, &enable, enable.len, &events, events.len, &now));
    try std.testing.expectEqual(@as(usize, @intCast(fds[1])), events[0].ident);
    try std.testing.expectEqual(sys.READ.FILTER, events[0].filter);
    try std.testing.expectEqual(2, events[0].data);
}
