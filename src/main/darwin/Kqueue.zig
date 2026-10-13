const sys = @import("sys.zig");

pub const Fd = c_int;
pub const Error = error{ BadFd, NotFound, Unexpected };

const Kqueue = @This();

fd: Fd,

pub fn init() !Kqueue {
    const rc = sys.kqueue();
    try check(rc);
    return .{ .fd = rc };
}

pub fn deinit(self: Kqueue) !void {
    const rc = sys.close(self.fd);
    try check(rc);
}

fn check(rc: c_int) Error!void {
    if (rc >= 0) return;
    return switch (sys.errno(rc)) {
        .BADF => error.BadFd,
        .NOENT => error.NotFound,
        else => error.Unexpected,
    };
}
