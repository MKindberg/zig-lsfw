# lsp-server
A framework for writing language servers in Zig. It allows you to
register callbacks that will be called when notifications to
requests are received. It will also keep track of and automatically
update the documents being edited.

# Usage
1. Create an object containing information about the server.
```zig
    const server_data = lsp_types.ServerData{
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
4. Create the relevant callbacks using lsp.writeResponse to send messages back to the client. All callbacks take at least two arguments: an arena allocator that will be freed after the callback and a context. The context contains the document and a document specific optional instance of state. Notifications callback shouldn't have a return value and requests should return optional data that will be sent in the reply to the client. Hover, for example, returns the string that will be printed in the hover window.
```zig
fn handleHover(allocator: std.mem.Allocator, context: *Lsp.Context, position: lsp_types.Position) ?[]const u8 {
    const text = context.state.hoverText();
    return text;
    }
}
```
5. Register the callbacks and start the server. It will run until the client is shut down or something goes wrong.
```zig
server.registerHoverCallback(handleHover);
return server.start();
```
