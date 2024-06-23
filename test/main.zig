const std = @import("std");
const lsp = @import("lsp");

const Lsp = lsp.Lsp(std.fs.File);

const builtin = @import("builtin");

pub fn log(
    comptime message_level: std.log.Level,
    comptime scope: @Type(.EnumLiteral),
    comptime format: []const u8,
    args: anytype,
) void {
    _ = message_level;
    _ = scope;
    std.debug.print(format, args);
}

pub const std_options = .{ .log_level = if (builtin.mode == .Debug) .debug else .info, .logFn = log };

pub fn main() !u8 {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    const server_data = lsp.types.ServerData{
        .capabilities = .{
            .hoverProvider = true,
            .codeActionProvider = true,
        },
        .serverInfo = .{
            .name = "tester",
            .version = "0.1.0",
        },
    };

    var file = try std.fs.cwd().createFile("output.txt", .{ .truncate = true });
    defer file.close();

    var server = Lsp.init(allocator, server_data);
    defer server.deinit();

    server.registerDocOpenCallback(handleOpenDoc);
    server.registerDocChangeCallback(handleChangeDoc);
    server.registerDocSaveCallback(handleSaveDoc);
    server.registerDocCloseCallback(handleCloseDoc);
    server.registerHoverCallback(handleHover);
    server.registerCodeActionCallback(handleCodeAction);

    return try server.start();
}

fn handleOpenDoc(_: std.mem.Allocator, context: *Lsp.Context, _: lsp.types.Notification.DidOpenTextDocument.Params) void {
    const file = std.fs.cwd().createFile("output.txt", .{ .truncate = true }) catch unreachable;
    context.state = file;
    _ = context.state.?.write("Opened document\n") catch unreachable;
}
fn handleCloseDoc(_: std.mem.Allocator, context: Lsp.Context, _: lsp.types.Notification.DidCloseTextDocument.Params) void {
    _ = context.state.?.write("Closed document\n") catch unreachable;
    context.state.?.close();
}
fn handleChangeDoc(_: std.mem.Allocator, context: Lsp.Context, _: lsp.types.Notification.DidChangeTextDocument.Params) void {
    _ = context.state.?.write("Changed document\n") catch unreachable;
}
fn handleSaveDoc(_: std.mem.Allocator, context: Lsp.Context, _: lsp.types.Notification.DidSaveTextDocument.Params) void {
    _ = context.state.?.write("Saved document\n") catch unreachable;
}
fn handleHover(_: std.mem.Allocator, context: Lsp.Context, _: lsp.types.Request.Hover.Params, _: i32) void {
    _ = context.state.?.write("Hover\n") catch unreachable;
}
fn handleCodeAction(_: std.mem.Allocator, context: Lsp.Context, _: lsp.types.Request.CodeAction.Params, _: i32) void {
    _ = context.state.?.write("Code action\n") catch unreachable;
}

test "Run nvim" {
    const nvim_config =
        \\local start_tester = function()
        \\    local client = vim.lsp.start_client { name = "tester", cmd = { "zig-out/bin/test" }, }
        \\
        \\    if not client then
        \\        vim.notify("Failed to start tester")
        \\    else
        \\        vim.api.nvim_create_autocmd("FileType",
        \\            { pattern = "text", callback = function() vim.lsp.buf_attach_client(0, client) end }
        \\        )
        \\    end
        \\end
        \\start_tester()
    ;
    std.fs.cwd().writeFile(.{ .sub_path = "nvim_config.lua", .data = nvim_config }) catch unreachable;
    defer std.fs.cwd().deleteFile("nvim_config.lua") catch {};
    const argv = [_][]const u8{
        "nvim",
        "--headless",
        "-u",
        "nvim_config.lua",
        "test.txt",
        "-c",
        "sleep 1", // ls doesn't start properly without this sleep
        "-c",
        ":norm itext",
        "-c",
        ":lua vim.lsp.buf.hover()",
        "-c",
        ":norm itext",
        "-c",
        ":lua vim.lsp.buf.code_action()",
        "-c",
        ":wq",
    };
    var child = std.process.Child.init(&argv, std.testing.allocator);

    try child.spawn();
    const term = try child.wait();
    defer std.fs.cwd().deleteFile("output.txt") catch {};
    defer std.fs.cwd().deleteFile("test.txt") catch {};

    try std.testing.expectEqual(term.Exited, 0);

    const expected =
        \\Opened document
        \\Changed document
        \\Hover
        \\Changed document
        \\Code action
        \\Saved document
        \\
    ;
    const actual = try std.fs.cwd().readFileAlloc(std.testing.allocator, "output.txt", 1000000);
    defer std.testing.allocator.free(actual);

    try std.testing.expectEqualStrings(expected, actual);
}
