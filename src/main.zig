const relay = @import("main/root.zig");

pub fn main() !void {
    try relay.startRelay();
}
