const std = @import("std");
const types = @import("types.zig");
const writeResponse = @import("lsp.zig").writeResponse;

pub fn log(
    comptime level: std.log.Level,
    comptime scope: @TypeOf(.EnumLiteral),
    comptime format: []const u8,
    args: anytype,
) void {
    _ = scope;

    const prefix = "[[" ++ comptime level.asText() ++ "]] ";

    const message_type = switch (level) {
        .err => types.MessageType.Error,
        .warn => types.MessageType.Warning,
        .info => types.MessageType.Info,
        .debug => types.MessageType.Debug,
    };

    var message_buf: [1024]u8 = undefined;

    const message = std.fmt.bufPrint(&message_buf, prefix ++ format, args) catch return;

    const notification = types.Notification.LogMessage{ .params = .{
        .type = message_type,
        .message = message,
    } };

    var response_buf: [1024]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&response_buf);
    writeResponse(fba.allocator(), notification) catch return;
}
