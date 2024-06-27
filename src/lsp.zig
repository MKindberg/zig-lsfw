pub const types = @import("types.zig");
pub const Document = @import("document.zig").Document;

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
        const OpenDocumentCallback = fn (allocator: std.mem.Allocator, context: *Context) void;
        const ChangeDocumentCallback = fn (allocator: std.mem.Allocator, context: *Context, changes: []types.ChangeEvent) void;
        const SaveDocumentCallback = fn (allocator: std.mem.Allocator, context: *Context) void;
        const CloseDocumentCallback = fn (allocator: std.mem.Allocator, context: *Context) void;
        const HoverCallback = fn (allocator: std.mem.Allocator, context: *Context, id: i32, position: types.Position) void;
        const CodeActionCallback = fn (allocator: std.mem.Allocator, context: *Context, id: i32, range: types.Range) void;

        callback_doc_open: ?*const OpenDocumentCallback = null,
        callback_doc_change: ?*const ChangeDocumentCallback = null,
        callback_doc_save: ?*const SaveDocumentCallback = null,
        callback_doc_close: ?*const CloseDocumentCallback = null,
        callback_hover: ?*const HoverCallback = null,
        callback_codeAction: ?*const CodeActionCallback = null,

        contexts: std.StringHashMap(Context),
        server_data: types.ServerData,
        allocator: std.mem.Allocator,

        pub const Context = struct {
            document: Document,
            state: ?StateType,
        };

        const RunState = enum {
            Run,
            ShutdownOk,
            ShutdownErr,
        };

        const Self = @This();
        pub fn init(allocator: std.mem.Allocator, server_data: types.ServerData) Self {
            return Self{ .allocator = allocator, .server_data = server_data, .contexts = std.StringHashMap(Context).init(allocator) };
        }

        pub fn deinit(self: *Self) void {
            var it = self.contexts.iterator();
            while (it.next()) |i| {
                i.value_ptr.document.deinit();
            }
            self.contexts.deinit();
        }

        pub fn registerDocOpenCallback(self: *Self, callback: *const OpenDocumentCallback) void {
            self.callback_doc_open = callback;
        }
        pub fn registerDocChangeCallback(self: *Self, callback: *const ChangeDocumentCallback) void {
            self.callback_doc_change = callback;
        }
        pub fn registerDocSaveCallback(self: *Self, callback: *const SaveDocumentCallback) void {
            self.callback_doc_save = callback;
        }
        pub fn registerDocCloseCallback(self: *Self, callback: *const CloseDocumentCallback) void {
            self.callback_doc_close = callback;
        }
        pub fn registerHoverCallback(self: *Self, callback: *const HoverCallback) void {
            self.callback_hover = callback;
        }
        pub fn registerCodeActionCallback(self: *Self, callback: *const CodeActionCallback) void {
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
                    const parsed = try std.json.parseFromSlice(types.Notification.DidOpenTextDocument, allocator, msg.content, .{ .ignore_unknown_fields = true });
                    defer parsed.deinit();

                    const params = parsed.value.params;
                    try openDocument(self, params.textDocument.uri, params.textDocument.languageId, params.textDocument.text);

                    if (self.callback_doc_open) |callback| {
                        var arena = std.heap.ArenaAllocator.init(self.allocator);
                        defer arena.deinit();
                        const context = self.contexts.getPtr(params.textDocument.uri).?;
                        callback(arena.allocator(), context);
                    }
                },
                rpc.MethodType.TextDocument_DidChange => {
                    const parsed = try std.json.parseFromSlice(types.Notification.DidChangeTextDocument, allocator, msg.content, .{ .ignore_unknown_fields = true });
                    defer parsed.deinit();

                    const params = parsed.value.params;
                    for (params.contentChanges) |change| {
                        try updateDocument(self, params.textDocument.uri, change.text, change.range);
                    }

                    if (self.callback_doc_change) |callback| {
                        var arena = std.heap.ArenaAllocator.init(self.allocator);
                        defer arena.deinit();
                        const context = self.contexts.getPtr(params.textDocument.uri).?;
                        callback(arena.allocator(), context, params.contentChanges);
                    }
                },
                rpc.MethodType.TextDocument_DidSave => {
                    const parsed = try std.json.parseFromSlice(types.Notification.DidSaveTextDocument, allocator, msg.content, .{ .ignore_unknown_fields = true });
                    defer parsed.deinit();

                    const params = parsed.value.params;
                    if (self.callback_doc_save) |callback| {
                        var arena = std.heap.ArenaAllocator.init(self.allocator);
                        defer arena.deinit();
                        const context = self.contexts.getPtr(params.textDocument.uri).?;
                        callback(arena.allocator(), context);
                    }
                },
                rpc.MethodType.TextDocument_DidClose => {
                    const parsed = try std.json.parseFromSlice(types.Notification.DidCloseTextDocument, allocator, msg.content, .{ .ignore_unknown_fields = true });
                    defer parsed.deinit();

                    const params = parsed.value.params;

                    if (self.callback_doc_close) |callback| {
                        var arena = std.heap.ArenaAllocator.init(self.allocator);
                        defer arena.deinit();
                        const context = self.contexts.getPtr(params.textDocument.uri).?;
                        callback(arena.allocator(), context);
                    }

                    closeDocument(self, params.textDocument.uri);
                },
                rpc.MethodType.TextDocument_Hover => {
                    if (self.callback_hover) |callback| {
                        var arena = std.heap.ArenaAllocator.init(self.allocator);
                        defer arena.deinit();
                        const parsed = try std.json.parseFromSlice(types.Request.Hover, allocator, msg.content, .{ .ignore_unknown_fields = true });
                        defer parsed.deinit();

                        const params = parsed.value.params;
                        const context = self.contexts.getPtr(params.textDocument.uri).?;

                        callback(arena.allocator(), context, parsed.value.id, params.position);
                    }
                },
                rpc.MethodType.TextDocument_CodeAction => {
                    if (self.callback_codeAction) |callback| {
                        var arena = std.heap.ArenaAllocator.init(self.allocator);
                        defer arena.deinit();
                        const parsed = try std.json.parseFromSlice(types.Request.CodeAction, allocator, msg.content, .{ .ignore_unknown_fields = true });
                        defer parsed.deinit();

                        const params = parsed.value.params;
                        const context = self.contexts.getPtr(params.textDocument.uri).?;

                        callback(arena.allocator(), context, parsed.value.id, params.range);
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

        pub fn openDocument(self: *Self, name: []const u8, language: []const u8, content: []const u8) !void {
            const context = Context{ .document = try Document.init(self.allocator, name, language, content), .state = null };

            try self.contexts.put(context.document.uri, context);
        }

        pub fn closeDocument(self: *Self, name: []const u8) void {
            const entry = self.contexts.fetchRemove(name);
            entry.?.value.document.deinit();
        }

        pub fn updateDocument(self: *Self, name: []const u8, text: []const u8, range: types.Range) !void {
            var context = self.contexts.getPtr(name).?;
            try context.document.update(text, range);
        }
    };
}
