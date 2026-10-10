//! Lists every test file in src/main so they get compiled and run.

comptime {
    _ = @import("main.test.zig");
}
