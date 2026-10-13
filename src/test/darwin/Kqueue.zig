const std = @import("std");
const Kqueue = @import("../../main/darwin/Kqueue.zig");

test "opens and closes" {
    const kq = try Kqueue.init();
    try kq.close();
}

test "closing invalid kqueue" {
    const kq = Kqueue{
        .fd = -1,
    };
    try std.testing.expectError(error.BadFd, kq.close());
}
