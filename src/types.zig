const std = @import("std");

pub const Request = struct {
    pub const Request = struct {
        jsonrpc: []const u8 = "2.0",
        id: i32,
        method: []u8,
    };
    pub const Initialize = struct {
        jsonrpc: []const u8 = "2.0",
        id: i32,
        method: []u8,
        params: Params,

        const Params = struct {
            clientInfo: ?ClientInfo,

            const ClientInfo = struct {
                name: []u8,
                version: []u8,
            };
        };
    };

    pub const Hover = struct {
        jsonrpc: []const u8 = "2.0",
        id: i32,
        method: []u8,
        params: Params,

        pub const Params = struct {
            textDocument: TextDocumentIdentifier,
            position: Position,
        };
    };
    pub const CodeAction = struct {
        jsonrpc: []const u8 = "2.0",
        id: i32,
        method: []u8,
        params: Params,

        pub const Params = struct {
            textDocument: TextDocumentIdentifier,
            range: Range,
            context: CodeActionContext,

            const CodeActionContext = struct {};
        };
    };

    pub const Shutdown = struct {
        jsonrpc: []const u8 = "2.0",
        id: i32,
        method: []u8,
    };
};

pub const Response = struct {
    pub const Initialize = struct {
        jsonrpc: []const u8 = "2.0",
        id: i32,
        result: ServerData,

        const Self = @This();

        pub fn init(id: i32, server_data: ServerData) Self {
            return Self{
                .jsonrpc = "2.0",
                .id = id,
                .result = server_data,
            };
        }
    };

    pub const Hover = struct {
        jsonrpc: []const u8 = "2.0",
        id: i32,
        result: Result,

        const Result = struct {
            contents: []const u8,
        };

        const Self = @This();
        pub fn init(id: i32, contents: []const u8) Self {
            return Self{
                .jsonrpc = "2.0",
                .id = id,
                .result = .{
                    .contents = contents,
                },
            };
        }
    };
    pub const CodeAction = struct {
        jsonrpc: []const u8 = "2.0",
        id: i32,
        result: []const Result,

        pub const Result = struct {
            title: []const u8,
            edit: ?WorkspaceEdit,
            const WorkspaceEdit = struct {
                changes: std.json.ArrayHashMap([]const TextEdit),
            };
        };
    };

    pub const Shutdown = struct {
        jsonrpc: []const u8 = "2.0",
        id: i32,
        result: void,

        const Self = @This();
        pub fn init(request: Request.Shutdown) Self {
            return Self{
                .jsonrpc = "2.0",
                .id = request.id,
                .result = {},
            };
        }
    };

    pub const Error = struct {
        jsonrpc: []const u8 = "2.0",
        id: i32,
        @"error": ErrorData,

        const Self = @This();
        pub fn init(id: i32, code: ErrorCode, message: []const u8) Self {
            return Self{
                .jsonrpc = "2.0",
                .id = id,
                .@"error" = .{
                    .code = @intFromEnum(code),
                    .message = message,
                },
            };
        }
    };
};

pub const Notification = struct {
    pub const DidOpenTextDocument = struct {
        jsonrpc: []const u8 = "2.0",
        method: []u8,
        params: Params,

        pub const Params = struct {
            textDocument: TextDocumentItem,
        };
    };

    pub const DidChangeTextDocument = struct {
        jsonrpc: []const u8 = "2.0",
        method: []u8,
        params: Params,

        pub const Params = struct {
            textDocument: VersionedTextDocumentIdentifier,
            contentChanges: []ChangeEvent,

            const VersionedTextDocumentIdentifier = struct {
                uri: []u8,
                version: i32,
            };
        };

        const ChangeEvent = struct {
            range: Range,
            text: []u8,
        };
    };

    pub const DidCloseTextDocument = struct {
        jsonrpc: []const u8 = "2.0",
        method: []u8,
        params: Params,
        pub const Params = struct {
            textDocument: TextDocumentIdentifier,
        };
    };

    pub const PublishDiagnostics = struct {
        jsonrpc: []const u8 = "2.0",
        method: []const u8,
        params: Params,
        pub const Params = struct {
            uri: []const u8,
            diagnostics: []const Diagnostic,
        };
    };

    pub const Exit = struct {
        jsonrpc: []const u8 = "2.0",
        method: []u8,
    };
};

const TextDocumentItem = struct {
    uri: []u8,
    languageId: []u8,
    version: i32,
    text: []u8,
};

const TextDocumentIdentifier = struct {
    uri: []u8,
};

pub const ServerData = struct {
    capabilities: ServerCapabilities = .{},
    serverInfo: ServerInfo,

    const ServerCapabilities = struct {
        textDocumentSync: i32 = 1,
        hoverProvider: bool = false,
        codeActionProvider: bool = false,
    };
    const ServerInfo = struct { name: []const u8, version: []const u8 };
};

pub const Range = struct {
    start: Position,
    end: Position,
};
pub const Position = struct {
    line: usize,
    character: usize,
};

pub const TextEdit = struct {
    range: Range,
    newText: []const u8,
};

pub const Diagnostic = struct {
    range: Range,
    severity: i32,
    source: ?[]const u8,
    message: []const u8,
};

pub const ErrorData = struct {
    code: i32,
    message: []const u8,
};

pub const ErrorCode = enum(i32) {
    ParseError = -32700,
    InvalidRequest = -32600,
    MethodNotFound = -32601,
    InvalidParams = -32602,
    InternalError = -32603,
};
