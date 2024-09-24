const std = @import("std");

const ServerInfo = @import("../plugins.zig").ServerInfo;

pub fn generate(allocator: std.mem.Allocator, info: ServerInfo) !void {
    var languages = std.ArrayList(u8).init(allocator);
    defer languages.deinit();
    for (info.languages) |l| {
        try languages.writer().print("\"{s}\", ", .{l});
    }
    const content = try std.fmt.allocPrint(allocator, plugin_lua, .{
        .name = info.name,
        .display = info.displayName orelse info.name,
        .languages = languages.items,
    });
    defer allocator.free(content);
    const filename = "editors/nvim/plugin.lua";
    var file = try std.fs.cwd().createFile(filename, .{});
    defer file.close();
    try file.writeAll(content);
}

const plugin_lua =
    \\local start_ls = function()
    \\    local client = vim.lsp.start_client {{ name = "{[display]s}", cmd = {{ "{[name]s}" }}, }}
    \\
    \\    if not client then
    \\        vim.notify("Failed to start {[display]s}")
    \\    else
    \\        vim.api.nvim_create_autocmd("FileType",
    \\            {{ pattern = "{[languages]s}", callback = function() vim.lsp.buf_attach_client(0, client) end }}
    \\        )
    \\    end
    \\end
    \\start_ls()
;
