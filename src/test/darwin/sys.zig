const std = @import("std");
const sys = @import("../../main/darwin/sys.zig");

test "opens a kqueue" {
    const fd = sys.kqueue();
    defer _ = sys.close(fd);
    try std.testing.expect(fd >= 0);
}

test "closes a descriptor" {
    const fd = sys.kqueue();
    try std.testing.expectEqual(0, sys.close(fd));
}
