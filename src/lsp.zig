pub const types = @import("lsp_types.zig");
pub const document = @import("document.zig");

const std = @import("std");
const rpc = @import("rpc.zig");

const Reader = @import("reader.zig").Reader;

pub fn writeResponse(allocator: std.mem.Allocator, msg: anytype) !void {
    const response = try rpc.encodeMessage(allocator, msg);
    defer response.deinit();

    const writer = std.io.getStdOut().writer();
    _ = try writer.write(response.items);
    std.log.info("Sent response", .{});
}
pub fn Lsp(comptime StateType: type) type {
    return struct {
        fn NotificationCallback(comptime Type: type) type {
            return fn (allocator: std.mem.Allocator, state: *StateType, params: Type.Params) void;
        }
        fn RequestCallback(comptime Type: type) type {
            return fn (allocator: std.mem.Allocator, state: *StateType, params: Type.Params, id: i32) void;
        }

        callback_doc_open: ?*const NotificationCallback(types.Notification.DidOpenTextDocument) = null,
        callback_doc_change: ?*const NotificationCallback(types.Notification.DidChangeTextDocument) = null,
        callback_doc_close: ?*const NotificationCallback(types.Notification.DidCloseTextDocument) = null,
        callback_hover: ?*const RequestCallback(types.Request.Hover) = null,
        callback_codeAction: ?*const RequestCallback(types.Request.CodeAction) = null,

        state: *StateType,
        server_data: types.ServerData,
        allocator: std.mem.Allocator,

        const RunState = enum {
            Run,
            ShutdownOk,
            ShutdownErr,
        };

        const Self = @This();
        pub fn init(allocator: std.mem.Allocator, server_data: types.ServerData, state: *StateType) Self {
            return Self{ .allocator = allocator, .server_data = server_data, .state = state };
        }

        pub fn registerDocOpenCallback(self: *Self, callback: *const NotificationCallback(types.Notification.DidOpenTextDocument)) void {
            self.callback_doc_open = callback;
        }
        pub fn registerDocChangeCallback(self: *Self, callback: *const NotificationCallback(types.Notification.DidChangeTextDocument)) void {
            self.callback_doc_change = callback;
        }
        pub fn registerDocCloseCallback(self: *Self, callback: *const NotificationCallback(types.Notification.DidCloseTextDocument)) void {
            self.callback_doc_close = callback;
        }
        pub fn registerHoverCallback(self: *Self, callback: *const RequestCallback(types.Request.Hover)) void {
            self.callback_hover = callback;
        }
        pub fn registerCodeActionCallback(self: *Self, callback: *const RequestCallback(types.Request.CodeAction)) void {
            self.callback_codeAction = callback;
        }

        pub fn start(self: *Self) !u8 {
            const stdin = std.io.getStdIn().reader();
            var reader = Reader.init(self.allocator, stdin);
            defer reader.deinit();

            var header = std.ArrayList(u8).init(self.allocator);
            defer header.deinit();
            var content = std.ArrayList(u8).init(self.allocator);
            defer content.deinit();

            var run_state = RunState.Run;
            while (run_state == RunState.Run) {
                std.log.info("Waiting for header", .{});
                _ = try reader.readUntilDelimiterOrEof(header.writer(), "\r\n\r\n");

                const content_len_str = "Content-Length: ";
                const content_len = if (std.mem.indexOf(u8, header.items, content_len_str)) |idx|
                    try std.fmt.parseInt(usize, header.items[idx + content_len_str.len ..], 10)
                else {
                    _ = try std.io.getStdErr().write("Content-Length not found in header\n");
                    break;
                };
                header.clearRetainingCapacity();

                const bytes_read = try reader.readN(content.writer(), content_len);
                if (bytes_read != content_len) {
                    break;
                }
                defer content.clearRetainingCapacity();

                const decoded = rpc.decodeMessage(self.allocator, content.items) catch |e| {
                    std.log.info("Failed to decode message: {any}\n", .{e});
                    continue;
                };
                run_state = try self.handleMessage(self.allocator, decoded);
            }
            return @intFromBool(run_state == RunState.ShutdownOk);
        }

        fn handleMessage(self: *Self, allocator: std.mem.Allocator, msg: rpc.DecodedMessage) !RunState {
            const local_state = struct {
                var shutdown = false;
            };

            std.log.info("Received request: {s}", .{msg.method.toString()});

            if (local_state.shutdown and msg.method != rpc.MethodType.Exit) {
                return try handleShutingDown(allocator, msg.method, msg.content);
            }
            switch (msg.method) {
                rpc.MethodType.Initialize => {
                    try handleInitialize(allocator, msg.content, self.server_data);
                },
                rpc.MethodType.Initialized => {},
                rpc.MethodType.TextDocument_DidOpen => {
                    if (self.callback_doc_open) |callback| {
                        const parsed = try std.json.parseFromSlice(types.Notification.DidOpenTextDocument, allocator, msg.content, .{ .ignore_unknown_fields = true });
                        defer parsed.deinit();
                        callback(allocator, self.state, parsed.value.params);
                    }
                },
                rpc.MethodType.TextDocument_DidChange => {
                    if (self.callback_doc_change) |callback| {
                        const parsed = try std.json.parseFromSlice(types.Notification.DidChangeTextDocument, allocator, msg.content, .{ .ignore_unknown_fields = true });
                        defer parsed.deinit();
                        callback(allocator, self.state, parsed.value.params);
                    }
                },
                rpc.MethodType.TextDocument_DidClose => {
                    if (self.callback_doc_close) |callback| {
                        const parsed = try std.json.parseFromSlice(types.Notification.DidCloseTextDocument, allocator, msg.content, .{ .ignore_unknown_fields = true });
                        defer parsed.deinit();
                        callback(allocator, self.state, parsed.value.params);
                    }
                },
                rpc.MethodType.TextDocument_Hover => {
                    if (self.callback_hover) |callback| {
                        const parsed = try std.json.parseFromSlice(types.Request.Hover, allocator, msg.content, .{ .ignore_unknown_fields = true });
                        defer parsed.deinit();
                        callback(allocator, self.state, parsed.value.params, parsed.value.id);
                    }
                },
                rpc.MethodType.TextDocument_CodeAction => {
                    if (self.callback_codeAction) |callback| {
                        const parsed = try std.json.parseFromSlice(types.Request.CodeAction, allocator, msg.content, .{ .ignore_unknown_fields = true });
                        defer parsed.deinit();
                        callback(allocator, self.state, parsed.value.params, parsed.value.id);
                    }
                },
                rpc.MethodType.Shutdown => {
                    try handleShutdown(allocator, msg.content);
                    local_state.shutdown = true;
                },
                rpc.MethodType.Exit => {
                    return RunState.ShutdownErr;
                },
            }
            return RunState.Run;
        }

        fn handleShutdown(allocator: std.mem.Allocator, msg: []const u8) !void {
            const parsed = try std.json.parseFromSlice(types.Request.Shutdown, allocator, msg, .{ .ignore_unknown_fields = true });
            defer parsed.deinit();
            const response = types.Response.Shutdown.init(parsed.value);
            try writeResponse(allocator, response);
        }

        fn handleShutingDown(allocator: std.mem.Allocator, method_type: rpc.MethodType, msg: []const u8) !RunState {
            if (method_type == rpc.MethodType.Exit) {
                return RunState.ShutdownOk;
            }

            const parsed = std.json.parseFromSlice(types.Request.Request, allocator, msg, .{ .ignore_unknown_fields = true });

            if (parsed) |request| {
                const reply = types.Response.Error.init(request.value.id, types.ErrorCode.InvalidRequest, "Shutting down");
                try writeResponse(allocator, reply);
                request.deinit();
            } else |err| if (err == error.UnknownField) {
                const reply = types.Response.Error.init(0, types.ErrorCode.InvalidRequest, "Shutting down");
                try writeResponse(allocator, reply);
            }
            return RunState.Run;
        }

        fn handleInitialize(allocator: std.mem.Allocator, msg: []const u8, server_data: types.ServerData) !void {
            const parsed = try std.json.parseFromSlice(types.Request.Initialize, allocator, msg, .{ .ignore_unknown_fields = true });
            defer parsed.deinit();
            const request = parsed.value;

            const client_info = request.params.clientInfo.?;
            std.log.info("Connected to {s} {s}", .{ client_info.name, client_info.version });

            const response_msg = types.Response.Initialize.init(request.id, server_data);

            try writeResponse(allocator, response_msg);
        }
    };
}
