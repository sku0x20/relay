//! Lists every test file in src/test so they get compiled and run.

const builtin = @import("builtin");

comptime {
    _ = @import("main.zig");
    if (builtin.os.tag.isDarwin()) {
        _ = @import("darwin/0_all.zig");
    }
}
