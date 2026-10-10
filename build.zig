const std = @import("std");

pub fn build(b: *std.Build) void {
    // --- Options ---
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // --- Executable ---
    const exe = b.addExecutable(.{
        .name = "relay",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    b.installArtifact(exe);

    // --- Run ---
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| run_cmd.addArgs(args);

    const run_step = b.step("run", "Run relay");
    run_step.dependOn(&run_cmd.step);

    // --- unit tests ---
    const unit_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/test.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    const run_unit = b.addRunArtifact(unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_unit.step);

    // --- e2e tests ---
    const e2e_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/e2e.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    const e2e_options = b.addOptions();
    e2e_options.addOptionPath("relay_exe", exe.getEmittedBin());
    e2e_tests.root_module.addOptions("build_options", e2e_options);

    const run_e2e = b.addRunArtifact(e2e_tests);

    const e2e_step = b.step("e2e", "Run end-to-end tests");
    e2e_step.dependOn(&run_e2e.step);
}
