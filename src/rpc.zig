const std = @import("std");

pub fn encodeMessage(allocator: std.mem.Allocator, msg: anytype) !std.ArrayList(u8) {
    var res = std.ArrayList(u8).init(allocator);
    errdefer res.deinit();
    try std.json.stringify(msg, .{}, res.writer());

    const length = res.items.len;
    var buf: [32]u8 = undefined;
    const content_len = try std.fmt.bufPrint(&buf, "Content-Length: {any}\r\n\r\n", .{length});

    try res.insertSlice(0, content_len);
    return res;
}

const BaseMessage = struct {
    method: []const u8,
};

pub const MethodType = enum {
    Initialize,
    Initialized,
    TextDocument_DidOpen,
    TextDocument_DidChange,
    TextDocument_DidClose,
    TextDocument_Hover,
    TextDocument_CodeAction,
    Shutdown,
    Exit,

    pub fn toString(self: MethodType) []const u8 {
        switch (self) {
            .Initialize => return "initialize",
            .Initialized => return "initialized",
            .TextDocument_DidOpen => return "textDocument/didOpen",
            .TextDocument_DidChange => return "textDocument/didChange",
            .TextDocument_DidClose => return "textDocument/didClose",
            .TextDocument_Hover => return "textDocument/hover",
            .TextDocument_CodeAction => return "textDocument/codeAction",
            .Shutdown => return "shutdown",
            .Exit => return "exit",
        }
    }
    pub fn fromString(s: []const u8) !MethodType {
        if (std.mem.eql(u8, s, "initialize")) {
            return MethodType.Initialize;
        } else if (std.mem.eql(u8, s, "initialized")) {
            return MethodType.Initialized;
        } else if (std.mem.eql(u8, s, "textDocument/didOpen")) {
            return MethodType.TextDocument_DidOpen;
        } else if (std.mem.eql(u8, s, "textDocument/didChange")) {
            return MethodType.TextDocument_DidChange;
        } else if (std.mem.eql(u8, s, "textDocument/hover")) {
            return MethodType.TextDocument_Hover;
        } else if (std.mem.eql(u8, s, "textDocument/codeAction")) {
            return MethodType.TextDocument_CodeAction;
        } else if (std.mem.eql(u8, s, "textDocument/didClose")) {
            return MethodType.TextDocument_DidClose;
        } else if (std.mem.eql(u8, s, "shutdown")) {
            return MethodType.Shutdown;
        } else if (std.mem.eql(u8, s, "exit")) {
            return MethodType.Exit;
        }
        return DecodeError.UnknownMethod;
    }
};

const DecodeError = error{
    InvalidMessage,
    UnknownMethod,
};

pub const DecodedMessage = struct {
    method: MethodType,
    content: []const u8,
};

pub fn decodeMessage(allocator: std.mem.Allocator, msg: []const u8) !DecodedMessage {
    const parsed = try std.json.parseFromSlice(BaseMessage, allocator, msg, .{ .ignore_unknown_fields = true });
    defer parsed.deinit();
    std.log.info("{s}", .{parsed.value.method});
    const method_type = try MethodType.fromString(parsed.value.method);
    return .{ .method = method_type, .content = msg };
}

test "encodeMessage" {
    const Foo = struct {
        x: u32,
        y: u32,
    };
    const foo = Foo{ .x = 42, .y = 37 };
    const encoded = try encodeMessage(std.testing.allocator, foo);
    defer encoded.deinit();
    try std.testing.expect(std.mem.eql(u8, "Content-Length: 15\r\n\r\n{\"x\":42,\"y\":37}", encoded.items));
}

test "decodeMessage" {
    const msg = "{\"method\":\"initialize\",\"y\":37}";
    const message = try decodeMessage(std.testing.allocator, msg[0..]);
    try std.testing.expectEqual(message.method, MethodType.Initialize);
}
