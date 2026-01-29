const std = @import("std");

test "e2e" {
    const exe_path = try std.process.getEnvVarOwned(std.testing.allocator, "RELAY_BIN");
    defer std.testing.allocator.free(exe_path);

    var child = std.process.Child.init(&.{exe_path}, std.testing.allocator);
    child.stdin_behavior = .Ignore;
    child.stdout_behavior = .Inherit;
    child.stderr_behavior = .Inherit;
    try child.spawn();
    defer {
        _ = child.kill() catch |err| {
            std.debug.print("e2e: kill failed: {s}\n", .{@errorName(err)});
        };
        _ = child.wait() catch |err| {
            std.debug.print("e2e: wait failed: {s}\n", .{@errorName(err)});
        };
    }

    std.time.sleep(100 * std.time.ns_per_ms);
}
