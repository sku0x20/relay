const std = @import("std");
const sys = @import("../../main/darwin/sys.zig");

test "opens a kqueue" {
    const fd = sys.kqueue();
    try std.testing.expect(fd >= 0);
}
