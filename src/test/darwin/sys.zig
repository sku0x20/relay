const std = @import("std");
const sys = @import("../../main/darwin/sys.zig");

test "opens and closes a kqueue" {
    const fd = sys.kqueue();
    try std.testing.expect(fd >= 0);
    try std.testing.expectEqual(0, sys.close(fd));
}
