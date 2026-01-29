const std = @import("std");

pub fn build(b: *std.Build) !void {
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

    const e2e_mod = b.createModule(.{
        .root_source_file = b.path("e2e/e2e.test.zig"),
        .target = target,
        .optimize = optimize,
    });

    const e2e_tests = b.addTest(.{
        .root_module = e2e_mod,
    });

    const run_e2e_tests = b.addRunArtifact(e2e_tests);
    const e2e_step = b.step("e2e", "Run end to end tests");
    e2e_step.dependOn(&run_e2e_tests.step);
}
