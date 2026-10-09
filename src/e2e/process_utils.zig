const std = @import("std");
const c = std.c;

// declared here since std.c only exposes posix_spawn on darwin
extern "c" fn posix_spawn(
    pid: *c.pid_t,
    path: [*:0]const u8,
    file_actions: ?*const anyopaque,
    attrp: ?*const anyopaque,
    argv: [*:null]const ?[*:0]const u8,
    envp: [*:null]const ?[*:0]const u8,
) c_int;

/// child inherits stdin/stdout/stderr and the environment
pub fn spawnRelay(exe_path: [:0]const u8) !c.pid_t {
    var pid: c.pid_t = undefined;
    const argv = [_:null]?[*:0]const u8{exe_path.ptr};
    const rc = posix_spawn(&pid, exe_path.ptr, null, null, &argv, @ptrCast(c.environ));
    if (rc != 0) {
        std.debug.print("e2e: posix_spawn failed: errno {d}\n", .{rc});
        return error.SpawnFailed;
    }
    return pid;
}

pub fn cleanup(pid: c.pid_t) void {
    if (c.kill(pid, c.SIG.TERM) == -1) {
        std.debug.print("e2e: kill failed: {any}\n", .{c.errno(@as(c_int, -1))});
    }
    if (c.waitpid(pid, null, 0) == -1) {
        std.debug.print("e2e: wait failed: {any}\n", .{c.errno(@as(c_int, -1))});
    }
}
