const Kqueue = @import("../../main/darwin/Kqueue.zig");

test "opens and closes" {
    const kq = try Kqueue.init();
    kq.deinit();
}
