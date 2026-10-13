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

// pub fn apply(self: Kqueue, changes: []const Change) !void {
//     // TODO
// }

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
