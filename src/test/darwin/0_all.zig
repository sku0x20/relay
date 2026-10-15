//! Lists every test file in src/test/darwin. Imported only on Darwin.

comptime {
    _ = @import("sys_kqueue.zig");
    _ = @import("sys_socketpair.zig");
    _ = @import("sys_tcp.zig");
    _ = @import("sys_udp.zig");
    _ = @import("UdpServer.zig");
}
