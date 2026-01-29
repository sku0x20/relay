const std = @import("std");

pub fn spawnRelay(exe_path: []const u8) !std.process.Child {
    var child = std.process.Child.init(&.{exe_path}, std.testing.allocator);
    child.stdin_behavior = .Ignore;
    child.stdout_behavior = .Inherit;
    child.stderr_behavior = .Inherit;
    try child.spawn();
    return child;
}

pub fn cleanup(child: *std.process.Child) void {
    _ = child.kill() catch |err| {
        std.debug.print("e2e: kill failed: {s}\n", .{@errorName(err)});
    };
    _ = child.wait() catch |err| {
        std.debug.print("e2e: wait failed: {s}\n", .{@errorName(err)});
    };
}
