const std = @import("std");
const generatePackageJson = @import("vscode/package_json.zig").generate;
const generateExtensionJs = @import("vscode/extension_js.zig").generate;
const generateReadmeMd = @import("vscode/readme_md.zig").generate;

pub const ServerInfo = struct {
    name: []const u8,
    displayName: ?[]const u8 = null,
    description: []const u8 = "",
    publisher: ?[]const u8 = null,
    repository: ?[]const u8 = null,
    languages: []const []const u8,
};

pub fn generate(allocator: std.mem.Allocator, info: ServerInfo) !void {
    try generateVSCode(allocator, info);
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
