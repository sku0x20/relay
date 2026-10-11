const std = @import("std");
const sys = @import("../../main/darwin/sys.zig");

test "socket readable after peer write" {
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

test "socket writable again after peer drains" {
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

test "unread bytes before eof" {
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

    // send, then hang up the other end.
    try std.testing.expectEqual(2, sys.send(fds[0], "hi", 2, 0));
    try std.testing.expectEqual(0, sys.close(fds[0]));

    const now: sys.Timespec = .{ .sec = 0, .nsec = 0 };
    var events: [1]sys.Kevent = undefined;
    // EOF means the peer stopped sending, not that the buffer is empty:
    // data counts bytes still unread.
    try std.testing.expectEqual(1, sys.kevent(kq, null, 0, &events, events.len, &now));
    try std.testing.expect(events[0].flags & sys.EV.EOF != 0);
    try std.testing.expectEqual(2, events[0].data);

    // read what was sent before the hangup.
    var buf: [2]u8 = undefined;
    try std.testing.expectEqual(2, sys.recv(fds[1], &buf, buf.len, 0));
    try std.testing.expectEqualStrings("hi", &buf);

    // drained: now the real end.
    try std.testing.expectEqual(0, sys.recv(fds[1], &buf, buf.len, 0));
}

test "close removes registration" {
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

// Backpressure: when the far side can't keep up and its send buffer fills,
// stop reading from this side instead of buffering without bound; resume
// once the far side drains.
test "no reads while disabled" {
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

// Half-close: a client sends its request, then shutdown(SHUT_WR) to say
// "that's all", and waits for the reply (`nc -N`, scripts piping a file).
// EOF on read only ends that direction; forward it and keep relaying replies.
test "replies after peer half-close" {
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

    // fds[0] is done sending, but still listening.
    try std.testing.expectEqual(0, sys.shutdown(fds[0], sys.SHUT.WR));

    const now: sys.Timespec = .{ .sec = 0, .nsec = 0 };
    var events: [1]sys.Kevent = undefined;
    // a half-close looks like any hangup: readable, flagged EOF.
    try std.testing.expectEqual(1, sys.kevent(kq, null, 0, &events, events.len, &now));
    try std.testing.expect(events[0].flags & sys.EV.EOF != 0);

    // the reverse direction still works.
    try std.testing.expectEqual(2, sys.send(fds[1], "hi", 2, 0));
    var buf: [2]u8 = undefined;
    try std.testing.expectEqual(2, sys.recv(fds[0], &buf, buf.len, 0));
    try std.testing.expectEqualStrings("hi", &buf);
}

test "EPIPE, not SIGPIPE, after peer close" {
    // Zig's Io installs a no-op SIGPIPE handler; restore the default, which kills.
    const old = sys.signal(sys.SIG.PIPE, sys.SIG.DFL);
    defer _ = sys.signal(sys.SIG.PIPE, old);

    var fds: [2]c_int = undefined;
    try std.testing.expectEqual(0, sys.socketpair(sys.AF.UNIX, sys.SOCK.STREAM, 0, &fds));
    defer _ = sys.close(fds[0]);

    // hang up the other end.
    try std.testing.expectEqual(0, sys.close(fds[1]));

    // NOSIGNAL turns the would-be SIGPIPE into a plain error.
    const rc = sys.send(fds[0], "hi", 2, sys.MSG.NOSIGNAL);
    try std.testing.expectEqual(-1, rc);
    try std.testing.expectEqual(sys.E.PIPE, sys.errno(rc));
}
