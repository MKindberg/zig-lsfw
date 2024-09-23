const std = @import("std");

const ServerInfo = @import("../plugins.zig").ServerInfo;

pub fn generate(allocator: std.mem.Allocator, info: ServerInfo) !void {
    const content = try std.fmt.allocPrint(allocator, readme_md, .{
        .name = info.name,
        .display = info.displayName orelse info.name,
        .description = info.description,
    });
    defer allocator.free(content);
    const filename = "editors/vscode/README.md";
    var file = try std.fs.cwd().createFile(filename, .{});
    defer file.close();
    try file.writeAll(content);
}

const readme_md =
    \\# {[display]s} README
    \\ {[description]s}
    \\
    \\## Features
    \\
    \\
    \\
    \\## Requirements
    \\
    \\ Put the {[name]s} binary in your path
;
