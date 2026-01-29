const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const mod = b.addModule("relay", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
    });

    const exe = b.addExecutable(.{
        .name = "relay",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "relay", .module = mod },
            },
        }),
    });

    b.installArtifact(exe);

    const run_step = b.step("run", "Run the app");

    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
    const e2e_step = b.step("e2e", "Run e2e tests");

    var e2e_dir = b.build_root.handle.openDir("e2e", .{ .iterate = true }) catch |err| {
        if (err == error.FileNotFound) {
            return;
        }
        @panic(@errorName(err));
    };
    defer e2e_dir.close();

    var walker = e2e_dir.walk(b.allocator) catch |err| {
        @panic(@errorName(err));
    };
    defer walker.deinit();

    while (walker.next() catch |err| {
        @panic(@errorName(err));
    }) |entry| {
        if (entry.kind != .file) continue;
        if (!std.mem.endsWith(u8, entry.path, ".tests.zig")) continue;

        const full_path = std.fs.path.join(b.allocator, &.{ "e2e", entry.path }) catch |err| {
            @panic(@errorName(err));
        };
        defer b.allocator.free(full_path);

        const e2e_mod = b.createModule(.{
            .root_source_file = b.path(full_path),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "relay", .module = mod },
            },
        });

        const e2e_test = b.addTest(.{
            .root_module = e2e_mod,
        });

        const run_e2e_test = b.addRunArtifact(e2e_test);
        e2e_step.dependOn(&run_e2e_test.step);
    }
}
