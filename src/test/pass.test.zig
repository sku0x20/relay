const std = @import("std");

test "pass" {
    try std.testing.expect(1 == 1);
}
