const std = @import("std");

test "passing" {
    try std.testing.expect(1 == 1);
}
