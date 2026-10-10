const std = @import("std");

test {
    _ = @import("e2e/0_all.test.zig");
}

test "e2e" {
    try std.testing.expect(false);
}
