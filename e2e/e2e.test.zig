const std = @import("std");
test "e2e" {
    const exe_path = try std.process.getEnvVarOwned(std.testing.allocator, "RELAY_BIN");
    defer std.testing.allocator.free(exe_path);

    var child = std.process.Child.init(&.{ exe_path }, std.testing.allocator);
    child.stdin_behavior = .Ignore;
    child.stdout_behavior = .Inherit;
    child.stderr_behavior = .Inherit;
    try child.spawn();
    defer {
        _ = try child.kill();
        _ = try child.wait();
    }

    std.time.sleep(100 * std.time.ns_per_ms);
}
