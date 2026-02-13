const std = @import("std");
const buildin = @import("builtin");
// todo: do something like this
// const Impl = switch (builtin.os.tag) {
//    .linux => @import("impl_linux.zig"),
//    .windows => @import("impl_windows.zig"),
//    else => @compileError("Unsupported OS"),
//};
const tcpServerKq = @import("tcp_server_kq.zig");

pub fn startRelay() !void {
    const bind = "127.0.0.1";
    const port = 19000;

    switch (buildin.os.tag) {
        .freebsd, .macos => try tcpServerKq.start(bind, port),
        else => std.log.warn("platform not available", .{}),
    }
}
