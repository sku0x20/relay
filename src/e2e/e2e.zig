const std = @import("std");
const relay_exe = @import("build_options").relay_exe;

test "greets" {
    const gpa = std.testing.allocator;
    const result = try std.process.run(gpa, std.testing.io, .{
        .argv = &.{relay_exe},
    });
    defer gpa.free(result.stdout);
    defer gpa.free(result.stderr);

    try std.testing.expectEqual(std.process.Child.Term{ .exited = 0 }, result.term);
    try std.testing.expectEqualStrings("info: hello world\n", result.stderr);
}
