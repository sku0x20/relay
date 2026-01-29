const std = @import("std");

pub fn startRelay() !void {
    const address = try std.net.Address.parseIp("127.0.0.1", 19000);
    var server = try std.net.Address.listen(address, .{});
    defer server.deinit();

    const connection = try server.accept();
    defer connection.stream.close();

    var reader = connection.stream.reader(&.{});
    var buf: [4]u8 = undefined;
    try reader.interface().readSliceAll(&buf);
    if (!std.mem.eql(u8, &buf, "ping")) return error.InvalidPing;

    var stream_writer = connection.stream.writer(&.{});
    try stream_writer.interface.writeAll("pong");
}
