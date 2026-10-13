const std = @import("std");
const sys = @import("../../main/darwin/sys.zig");

test "listener readable once client connects" {
    const listener = sys.socket(sys.AF.INET, sys.SOCK.STREAM, 0);
    try std.testing.expect(listener >= 0);
    defer _ = sys.close(listener);

    // port 0: the kernel picks a free one.
    var addr: sys.SockaddrIn = .{
        .port = 0,
        .addr = std.mem.nativeToBig(u32, sys.INADDR.LOOPBACK),
    };
    var len: u32 = @sizeOf(sys.SockaddrIn);
    try std.testing.expectEqual(0, sys.bind(listener, &addr, len));
    try std.testing.expectEqual(0, sys.listen(listener, 16));
    // read back which port it picked.
    try std.testing.expectEqual(0, sys.getsockname(listener, &addr, &len));

    const kq = sys.kqueue();
    defer _ = sys.close(kq);

    const add = [_]sys.Kevent{.{
        .ident = @intCast(listener),
        .filter = sys.READ.FILTER,
        .flags = sys.EV.ADD,
        .fflags = 0,
        .data = 0,
        .udata = null,
    }};
    // watch the listener for incoming connections.
    try std.testing.expectEqual(0, sys.kevent(kq, &add, add.len, null, 0, null));

    const now: sys.Timespec = .{ .sec = 0, .nsec = 0 };
    var events: [1]sys.Kevent = undefined;
    // nobody connected yet.
    try std.testing.expectEqual(0, sys.kevent(kq, null, 0, &events, events.len, &now));

    const client = sys.socket(sys.AF.INET, sys.SOCK.STREAM, 0);
    try std.testing.expect(client >= 0);
    defer _ = sys.close(client);
    // the kernel completes the handshake and queues it; no accept needed.
    try std.testing.expectEqual(0, sys.connect(client, &addr, len));

    // readable: data holds the number of connections waiting.
    try std.testing.expectEqual(1, sys.kevent(kq, null, 0, &events, events.len, &now));
    try std.testing.expectEqual(@as(usize, @intCast(listener)), events[0].ident);
    try std.testing.expectEqual(1, events[0].data);

    const conn = sys.accept(listener, null, null);
    try std.testing.expect(conn >= 0);
    defer _ = sys.close(conn);

    // accepted: queue empty, no longer reported.
    try std.testing.expectEqual(0, sys.kevent(kq, null, 0, &events, events.len, &now));

    // a plain connected socket, like either end of a socketpair.
    try std.testing.expectEqual(2, sys.send(client, "hi", 2, 0));
    var buf: [2]u8 = undefined;
    try std.testing.expectEqual(2, sys.recv(conn, &buf, buf.len, 0));
    try std.testing.expectEqualStrings("hi", &buf);
}
