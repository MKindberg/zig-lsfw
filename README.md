# lsp-server
A framework for writing language servers in Zig. It allows you to
register callbacks that will be called when notifications to
requests are received. It will also keep track of and automatically
update the documents being edited.

# Usage
1. Create an object containing information about server capabilities and info.
```zig
    const server_data = lsp_types.ServerData{
        .capabilities = .{
            .hoverProvider = true,
            .codeActionProvider = true,
        },
        .serverInfo = .{
            .name = "test server",
            .version = "0.1.0",
        },
    };
```
2. Create a state object if the server needs to keep track of something other than the document.
```zig
var state = State.init();
```
3. Create an instance of the server that with an allocator and the server data. When creating the lsp type a state type is needed. An optional state will then be passed as part of the context object to all callbacks, it should be created in the openDocument callback and destroyed in the closeDocument callback.
```zig
const Lsp = lsp.Lsp(StateType);
var server = Lsp.init(allocator, server_data, &state);
defer server.deinit();
```
4. Create the relevant callbacks using lsp.writeResponse to send messages back to the client. All callbacks take at least two arguments: an arena allocator that will be freed after the callback and a context. The context contains the document and a document specific optional instance of state. Requests also get passed an id that can be used when responding to the requests and some callbacks, like hover, also take another parameter containing additional information that might be useful.
```zig
fn handleHover(allocator: std.mem.Allocator, context: *Lsp.Context, id: i32, position: lsp_types.Position) void {
    const text = context.state.hoverText();
    const response = lsp.types.Response.Hover.init(id, text);
    lsp.writeResponse(allocator, response) catch unreachable;
    }
}
```
5. Register the callbacks and start the server. It will run until the client is shut down or something goes wrong.
```zig
server.registerHoverCallback(handleHover);
return server.start();
```
