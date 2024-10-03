const std = @import("std");

const generatePackageJson = @import("vscode/package_json.zig").generate;
const generateExtensionJs = @import("vscode/extension_js.zig").generate;
const generateReadmeMd = @import("vscode/readme_md.zig").generate;

const generatePluginLua = @import("nvim/plugin_lua.zig").generate;
const generateMason = @import("nvim/mason_registry.zig").generate;

pub const ServerInfo = struct {
    name: []const u8,
    languages: []const []const u8,
    displayName: ?[]const u8 = null,
    description: []const u8 = "",
    publisher: ?[]const u8 = null,
    repository: ?[]const u8 = null,
    homepage: ?[]const u8 = null,
    license: ?[]const u8 = null,
    version: ?[]const u8 = null,
    source_id: ?[]const u8 = null,
};

pub fn generate(allocator: std.mem.Allocator, info: ServerInfo) !void {
    try generateVSCode(allocator, info);
    try generateNvim(allocator, info);
    try generateMasonRegistry(allocator, info);
}

pub fn generateVSCode(allocator: std.mem.Allocator, info: ServerInfo) !void {
    std.fs.cwd().makeDir("editors") catch {};
    std.fs.cwd().makeDir("editors/vscode") catch {};

    try generatePackageJson(allocator, info);
    try generateExtensionJs(allocator, info);
    try generateReadmeMd(allocator, info);

    std.fs.cwd().copyFile("LICENSE", std.fs.cwd(), "editors/vscode/LICENSE", .{}) catch {};

    std.debug.print("Run 'npm install' in the vscode dir to install the needed dependency\n", .{});
    std.debug.print("Run 'vsce package' in the vscode dir to build the plugin\n", .{});
}

pub fn generateNvim(allocator: std.mem.Allocator, info: ServerInfo) !void {
    std.fs.cwd().makeDir("editors") catch {};
    std.fs.cwd().makeDir("editors/nvim") catch {};

    try generatePluginLua(allocator, info);
}

pub fn generateMasonRegistry(allocator: std.mem.Allocator, info: ServerInfo) !void {
    std.fs.cwd().makeDir("editors") catch {};
    std.fs.cwd().makeDir("editors/nvim") catch {};

    try generateMason(allocator, info);
}

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    const info = ServerInfo{
        .name = "my-server",
        .languages = &[_][]const u8{"rust"},
        .displayName = "My Server",
        .description = "My Language Server",
        .publisher = "my-publisher",
        .repository = ""
    };
    try generateVSCode(allocator, info);
}
