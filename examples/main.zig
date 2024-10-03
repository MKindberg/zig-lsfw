const std = @import("std");
const lsp = @import("lsp");
const builtin = @import("builtin");

// Set the global log function to lsp.log in order to use the lsp protocol
// for logging
pub const std_options = .{ .log_level = if (builtin.mode == .Debug) .debug else .info, .logFn = lsp.log };

// File specific state
const State = struct {
    fn init() State {
        return .{};
    }
};
// Create an alias for the server type. An instance of State will be available
// in each callback.
const Lsp = lsp.Lsp(State);

pub fn main() !u8 {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    // Information about the server that will be passed to the client.
    const server_data = lsp.types.ServerData{
        .serverInfo = .{ .name = "server_name", .version = "0.1.0" },
    };

    var server = Lsp.init(allocator, server_data);
    defer server.deinit();

    // Register wanted callbacks. They need to be registered before the server starts.
    server.registerDocOpenCallback(handleOpenDoc);
    server.registerDocCloseCallback(handleCloseDoc);
    server.registerDocChangeCallback(handleChangeDoc);
    server.registerHoverCallback(handleHover);

    // Start the server, it will run until it gets a shutdown signal from the client.
    const res = server.start();

    return res;
}

// All callbacks takes at least two parameters, an arena allocator that will
// be freed after the callback has finished (and the reply has been sent) and
// a context struct containing the user provided state and the document.
fn handleOpenDoc(arena: std.mem.Allocator, context: *Lsp.Context) void {
    _ = arena;
    std.log.info("Opened {s}", .{context.document.uri});
    // The file local state should be initialized when a document is opened.
    context.state = State.init();
}

// Most resources related to the document will be freed automatically, but the
// user provided state needs to be handled manually.
fn handleCloseDoc(_: std.mem.Allocator, context: *Lsp.Context) void {
    // Deinitialize the state when the file is closed.
    context.state.deinit();
}

// Most callbacks take additional arguments that might be useful, like the
// changes that triggered a change notification.
fn handleChangeDoc(_: std.mem.Allocator, _: *Lsp.Context, changes: []lsp.types.ChangeEvent) void {
    for (changes) |change| {
        std.log.info("New text: {s}", .{change.text});
    }
}

// Callbacks handling requests will have a non-void return value that will
// be sent back to the client after the callback returns.
fn handleHover(_: std.mem.Allocator, context: *Lsp.Context, position: lsp.types.Position) ?[]const u8 {
    // A document provides some helper function that can be useful.
    std.log.info("Hovering the word {s} at {d}:{d}", .{ context.document.getWord(position, "\n .,"), position.line, position.character });
}
