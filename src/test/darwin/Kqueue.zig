const std = @import("std");
const sys = @import("../../main/darwin/sys.zig");
const Kqueue = @import("../../main/darwin/Kqueue.zig");

test "opens and closes" {
    const kq = try Kqueue.init();
    try std.testing.expect(kq.fd >= 0);
    kq.deinit();

    // closing again fails: deinit already released it.
    const rc = sys.close(kq.fd);
    try std.testing.expectEqual(-1, rc);
    try std.testing.expectEqual(sys.E.BADF, sys.errno(rc));
}
