
### Info

It's a client/server for UDP streaming using lua coroutines and vlc as video source, grabs the latency to a local file.

Nothing special just lua niceness as usual.

### Use

On the "server"
./emisor.lua

On a client
./receptor.lua

On another client
./receptor4444.lua

### Dependencies

Needs lua and lua-socket, vlc and a local video as [Big Buck Bunny](https://peach.blender.org/download/) .

### TODO

- [ ] Client and server negotiate the port dynamically


