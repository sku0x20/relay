const std = @import("std");
const Kqueue = @import("../../main/darwin/Kqueue.zig");

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
