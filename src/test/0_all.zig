//! Lists every test file in src/test so they get compiled and run.

const builtin = @import("builtin");

comptime {
    _ = @import("main.zig");
    if (builtin.os.tag == .macos) {
        _ = @import("darwin/sys.zig");
    }
}
