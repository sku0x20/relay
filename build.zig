const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const rootModule = addRootModule(b, target);
    const exe = addExecutable(b, rootModule, target, optimize);
    b.installArtifact(exe);
    addRunStep(b, exe);
    const e2e_tests = addE2eTests(b, target, optimize);
    addE2eRunStep(b, e2e_tests);

    const testStep = addTestStep(b);
    addTests(b, testStep);
}

fn addTestStep(b: *std.Build) *std.Build.Step {
    const testStep = b.step("test", "Run tests in test");
    return testStep;
}

fn addTests(
    b: *std.Build,
    step: *std.Build.Step,
) void {
    var dir = b.build_root.handle.openDir("test", .{
        .iterate = true,
        .no_follow = true,
    }) catch |err| {
        std.debug.print("Failed to open 'test': {} \n", .{err});
        return;
    };
    defer dir.close();

    var walker = dir.walk(b.allocator) catch |err| {
        std.debug.print("Failed walker for 'test': {} \n", .{err});
        return;
    };
    defer walker.deinit();

    while (walker.next() catch null) |entry| {
        createTest(b, step, &entry);
    }
}

fn createTest(
    b: *std.Build,
    step: *std.Build.Step,
    entry: *const std.fs.Dir.Walker.Entry,
) void {
    if (entry.kind != .file and !std.mem.endsWith(u8, entry.path, ".test.zig")) {
        return;
    }

    const path = b.pathJoin(&.{ "test", entry.path });
    const t = b.addTest(.{
        .name = entry.basename,
        .root_module = b.createModule(.{
            .root_source_file = b.path(path),
            .target = b.graph.host,
            .optimize = .Debug,
        }),
    });

    const runT = b.addRunArtifact(t);
    step.dependOn(&runT.step);
}

fn addExecutable(
    b: *std.Build,
    rootModule: *std.Build.Module,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
) *std.Build.Step.Compile {
    return b.addExecutable(.{
        .name = "relay",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "relay", .module = rootModule },
            },
        }),
    });
}

fn addRootModule(b: *std.Build, target: std.Build.ResolvedTarget) *std.Build.Module {
    return b.addModule("relay", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
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

fn addE2eTests(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
) *std.Build.Step.Compile {
    const e2e_mod = b.createModule(.{
        .root_source_file = b.path("e2e/e2e.test.zig"),
        .target = target,
        .optimize = optimize,
    });

    const e2e_tests = b.addTest(.{
        .root_module = e2e_mod,
    });
    e2e_tests.step.dependOn(b.getInstallStep());
    return e2e_tests;
}

fn addE2eRunStep(b: *std.Build, e2e_tests: *std.Build.Step.Compile) void {
    const run_e2e_tests = b.addRunArtifact(e2e_tests);
    const exe_path = b.getInstallPath(.bin, "relay");
    run_e2e_tests.setEnvironmentVariable("RELAY_BIN", exe_path);
    const e2e_step = b.step("e2e", "Run end to end tests");
    e2e_step.dependOn(&run_e2e_tests.step);
}
