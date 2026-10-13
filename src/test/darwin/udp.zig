const std = @import("std");
const sys = @import("../../main/darwin/sys.zig");

test "datagrams read one per recv" {
    const receiver = sys.socket(sys.AF.INET, sys.SOCK.DGRAM, 0);
    try std.testing.expect(receiver >= 0);
    defer _ = sys.close(receiver);

    // port 0: the kernel picks a free one. No listen or accept.
    var addr: sys.SockaddrIn = .{
        .port = 0,
        .addr = std.mem.nativeToBig(u32, sys.INADDR.LOOPBACK),
    };
    var len: u32 = @sizeOf(sys.SockaddrIn);
    try std.testing.expectEqual(0, sys.bind(receiver, &addr, len));
    // read back which port it picked.
    try std.testing.expectEqual(0, sys.getsockname(receiver, &addr, &len));

    const kq = sys.kqueue();
    defer _ = sys.close(kq);

    // CLEAR: report again only when another datagram lands.
    const add = [_]sys.Kevent{.{
        .ident = @intCast(receiver),
        .filter = sys.READ.FILTER,
        .flags = sys.EV.ADD | sys.EV.CLEAR,
        .fflags = 0,
        .data = 0,
        .udata = null,
    }};
    try std.testing.expectEqual(0, sys.kevent(kq, &add, add.len, null, 0, null));

    const sender = sys.socket(sys.AF.INET, sys.SOCK.DGRAM, 0);
    try std.testing.expect(sender >= 0);
    defer _ = sys.close(sender);

    // loopback delivers asynchronously, after sendto returns, so wait.
    const second: sys.Timespec = .{ .sec = 1, .nsec = 0 };
    var events: [1]sys.Kevent = undefined;

    // no connection: each datagram carries its destination.
    try std.testing.expectEqual(2, sys.sendto(sender, "hi", 2, 0, &addr, len));
    try std.testing.expectEqual(1, sys.kevent(kq, null, 0, &events, events.len, &second));
    try std.testing.expectEqual(2, events[0].data);

    // fires only once "there" lands, so both are queued.
    try std.testing.expectEqual(5, sys.sendto(sender, "there", 5, 0, &addr, len));
    try std.testing.expectEqual(1, sys.kevent(kq, null, 0, &events, events.len, &second));
    // data counts bytes across all queued datagrams, not the next one's size.
    try std.testing.expectEqual(7, events[0].data);

    // room for both, but each recv returns a single datagram.
    var buf: [16]u8 = undefined;
    try std.testing.expectEqual(2, sys.recv(receiver, &buf, buf.len, 0));
    try std.testing.expectEqualStrings("hi", buf[0..2]);
    try std.testing.expectEqual(5, sys.recv(receiver, &buf, buf.len, 0));
    try std.testing.expectEqualStrings("there", buf[0..5]);
}
