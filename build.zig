const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = addExecutable(b, target, optimize);
    b.installArtifact(exe);
    addRunStep(b, exe);

    const tests = addTests(b, "src/tests.zig", target, optimize);
    addTestRunStep(b, tests);

    const e2e_tests = addTests(b, "src/e2e.zig", target, optimize);
    e2e_tests.step.dependOn(b.getInstallStep());
    addE2eRunStep(b, e2e_tests);
}

fn addExecutable(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
) *std.Build.Step.Compile {
    return b.addExecutable(.{
        .name = "relay",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            // std.c bindings need libc on linux (always linked on darwin)
            .link_libc = true,
        }),
    });
}

fn addRunStep(b: *std.Build, exe: *std.Build.Step.Compile) void {
    const run_step = b.step("run", "Run the app");

    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
}

fn addTests(
    b: *std.Build,
    root: []const u8,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
) *std.Build.Step.Compile {
    return b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path(root),
            .target = target,
            .optimize = optimize,
            // std.c bindings need libc on linux (always linked on darwin)
            .link_libc = true,
        }),
    });
}

fn addTestRunStep(b: *std.Build, tests: *std.Build.Step.Compile) void {
    const run_tests = b.addRunArtifact(tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_tests.step);
}

fn addE2eRunStep(b: *std.Build, e2e_tests: *std.Build.Step.Compile) void {
    const run_e2e_tests = b.addRunArtifact(e2e_tests);
    const exe_path = b.getInstallPath(.bin, "relay");
    run_e2e_tests.setEnvironmentVariable("RELAY_BIN", exe_path);
    const e2e_step = b.step("e2e", "Run end to end tests");
    e2e_step.dependOn(&run_e2e_tests.step);
}
