# lsp-server
A framework for writing language servers in Zig. It allows you to
register callbacks that will be called when notifications to
requests are received. It will also keep track of and automatically
update the documents being edited.

# Usage
1. Create an object containing information about server capabilities and info.
```
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
```
var state = State.init();
```
3. Create an instance of the server that with an allocator, the server data and the initial state.
```
var server = lsp.Lsp(*StateType).init(allocator, server_data, &state);
defer server.deinit();
```
4. Create the relevant callbacks using lsp.writeResponse to send messages back to the client. The callbacks should take three or four arguments: an allocator, a context object containing the state and the document being edited, the message sent by the client and an id if the message was a request.
```
fn handleHover(allocator: std.mem.Allocator, context: lsp.Lsp(*State).Context, request: lsp_types.Request.Hover.Params, id: i32) void {
    const text = context.state.hoverText();
    const response = lsp.types.Response.Hover.init(id, text);
    lsp.writeResponse(allocator, response) catch unreachable;
    }
}
```
5. Register the callbacks and start the server. It will run until the client is shut down or something goes wrong.
```
server.registerHoverCallback(handleHover);
return server.start();
```
