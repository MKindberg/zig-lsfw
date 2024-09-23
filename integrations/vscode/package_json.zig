const std = @import("std");

const ServerInfo = @import("../plugins.zig").ServerInfo;

pub fn generate(allocator: std.mem.Allocator, info: ServerInfo) !void {
    var activation_events = std.ArrayList(u8).init(allocator);
    defer activation_events.deinit();
    for (info.languages) |l| {
        try activation_events.writer().print("    \"onLanguage:{s}\",\n", .{l});
    }
    _ = activation_events.pop(); // \n
    _ = activation_events.pop(); // ,
    const repo = std.fmt.allocPrint(allocator, "\"repository\": \"{s}\",", .{info.repository orelse ""}) catch unreachable;
    defer allocator.free(repo);
    const content = try std.fmt.allocPrint(allocator, package_json, .{
        .name = info.name,
        .display = info.displayName orelse info.name,
        .description = info.description,
        .repo = if (info.repository != null) repo else "",
        .publisher = info.publisher orelse std.posix.getenv("USER").?,
        .activation = activation_events.items,
    });
    defer allocator.free(content);
    const filename = "editors/vscode/package.json";
    var file = try std.fs.cwd().createFile(filename, .{});
    defer file.close();
    try file.writeAll(content);
}

const package_json =
    \\{{
    \\  "name": "{[name]s}",
    \\  "displayName": "{[display]s}",
    \\  "description": "{[description]s}",
    \\  {[repo]s}
    \\  "version": "0.0.1",
    \\  "publisher": "{[publisher]s}",
    \\  "engines": {{
    \\    "vscode": "^1.90.0"
    \\  }},
    \\  "categories": [
    \\    "Language Server"
    \\  ],
    \\  "activationEvents": [
    \\{[activation]s}
    \\  ],
    \\  "main": "./extension.js",
    \\  "dependencies": {{
    \\    "vscode-languageclient": "^9.0.1"
    \\  }}
    \\}}
;
