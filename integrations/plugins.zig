const std = @import("std");

const generatePackageJson = @import("vscode/package_json.zig").generate;
const generateExtensionJs = @import("vscode/extension_js.zig").generate;
const generateReadmeMd = @import("vscode/readme_md.zig").generate;

const generatePluginLua = @import("nvim/plugin_lua.zig").generate;
const generateMason = @import("nvim/mason_registry.zig").generate;

pub const ServerInfo = struct {
    /// Name of the server
    name: []const u8,
    /// List of languages for which the server should be started
    languages: []const []const u8,
    /// Optional display name to show in nvim and vscode, defaults to name.
    displayName: ?[]const u8 = null,
    /// Optional description.
    description: []const u8 = "",
    /// Publisher of the vscode plugin.
    publisher: ?[]const u8 = null,
    /// Repository to show in the vscode plugin and mason registry.
    repository: ?[]const u8 = null,
    /// Homepage to show in the mason registry, default to repository.
    homepage: ?[]const u8 = null,
    /// License to show in the mason registry.
    license: ?[]const u8 = null,
    /// Version to let Mason notify users on updates, can be autodetected from tags starting with v.
    version: ?[]const u8 = null,
    /// Source id where mason can download the file from
    source_id: ?[]const u8 = null,
};

/// Call all generation functions
pub fn generate(allocator: std.mem.Allocator, info: ServerInfo) !void {
    try generateVSCode(allocator, info);
    try generateNvim(allocator, info);
    try generateMasonRegistry(allocator, info);
}

/// Generate a minimal VSCode plugin. This will create (and overwrite existing) a package.json,
/// extension.js and README.md file in the editors/vscode directory. Install dependencies with
/// install dependencies with `npm install` and build the plugin with `vsce package` (vsce can
/// be found among the dependencies in the node_module directory).
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

/// Generate a nvim file under editors/nvim that can be imported in the lua config to start the server.
pub fn generateNvim(allocator: std.mem.Allocator, info: ServerInfo) !void {
    std.fs.cwd().makeDir("editors") catch {};
    std.fs.cwd().makeDir("editors/nvim") catch {};

    try generatePluginLua(allocator, info);
}

/// Generate a mason registry file under editors/nvim so the server can be managed with Mason.
/// To be used with Mason this file needs to be ziped and a checksum needs to be calculated
/// eg. `zip -r registry.json.zip editors/nvim/registry.json` and
/// `sha256sum editors/nvim/registry.json registry.json.zip > checksums.txt`.
pub fn generateMasonRegistry(allocator: std.mem.Allocator, info: ServerInfo) !void {
    std.fs.cwd().makeDir("editors") catch {};
    std.fs.cwd().makeDir("editors/nvim") catch {};

    try generateMason(allocator, info);
}
