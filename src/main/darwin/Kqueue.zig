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

pub fn close(self: Kqueue) !void {
    const rc = sys.close(self.fd);
    try check(rc);
}

pub fn deinit(self: Kqueue) void {
    self.close() catch {};
}

fn check(rc: c_int) Error!void {
    if (rc >= 0) return;
    return switch (sys.errno(rc)) {
        .BADF => error.BadFd,
        .NOENT => error.NotFound,
        else => error.Unexpected,
    };
}

pub const Filter = i16;
pub const Flags = u16;
pub const FilterFlags = u32;
pub const Data = isize;
pub const UserData = anyopaque;

pub const Event = struct {
    fd: Fd,
    flags: Flags,
    filter: Filter,
    fflags: FilterFlags,
    data: Data,
    userData: ?*UserData,
};

pub const Change = Event;

/// Applies changes in order, one kevent call each, stopping at the first failure.
/// No eventlist, so a failed change returns -1/errno instead of an EV_ERROR event.
pub fn apply(self: Kqueue, changes: []const Change) !void {
    for (changes) |change| {
        const kevent = [_]sys.Kevent{.{
            .ident = @intCast(change.fd),
            .filter = change.filter,
            .flags = change.flags,
            .fflags = change.fflags,
            .data = change.data,
            .udata = change.userData,
        }};
        const rc = sys.kevent(self.fd, &kevent, kevent.len, null, 0, null);
        try check(rc);
    }
}
