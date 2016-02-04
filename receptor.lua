#!/usr/bin/lua
-----------------------------------------------------------------------------
-- Client
-----------------------------------------------------------------------------
socket = require("socket")
latencia = io.open("latencia.txt", "w")

host = "0.0.0.0"
port = tonumber(7777)
player_port = tonumber(9999)
tam_buffer = 250
tam_cabecera = 10
buffer = {}

if arg then
    player_port = tonumber(arg[1]) or player_port
end

function cierra() print("Emisor cerrado.") os.execute("killall vlc") os.exit() end

function lanza_player()
    local con = assert(socket.bind(host, player_port))
    local saludo="HTTP/1.0 200 OK\r\n DameVideo: Si!\r\n\r\n"
    os.execute("vlc http://"..host..":"..player_port.." &")
    --os.execute("mplayer http://"..host..":"..player_port.." -cache-min 45 -cache 1024 &")
    player = assert(con:accept())
    repeat  l=player:receive() until l==""
    assert(player:send(saludo)) 
end

function ordena(buffer)
    print("BufferLLeno.")
    table.sort(buffer, function(a,b) return a.orden < b.orden end)
    for i,n in ipairs(buffer) do 
        latencia:write(n.orden.." "..n.latencia) 
        assert(player:send(n.datos))
        buffer[i]=nill
    end
end
function rellena_buffer(chunk, tam)
    if not chunk then cierra() end --2 sg
    local orden,time,datos = string.match(chunk, '(%d+)-(%d+%.?%d?)-(.*)')
    local latencia=string.format("%9.3f ms\n",(socket.gettime()*1000)-time)
    table.insert(buffer,{ orden=tonumber(orden), latencia=latencia, datos=datos })
    if #buffer==tam then ordena(buffer)  end
end

lanza_player()

--Crea el socket
emisor = assert(socket.udp())
--Realiza el bind
assert(emisor:setsockname(host, port))
--Si recibimos en ese puerto se trata de un emisor
chunk , host ,port  = assert(emisor:receivefrom())  --Recibe "ping"
assert(emisor:setpeername(host,port))
emisor:send("cabecera")  --Le pide la cabecera


for i=1, tam_cabecera, 1 do
    chunk = emisor:receive()
    if chunk=="ping" then print("ping: Fallo de sincronización") os.exit() end
    rellena_buffer(chunk, tam_cabecera)
end
emisor:send("ok") 
print("Cabecera recibida desde "..host..":"..port..".\nReproduciendo video.")

emisor:settimeout(2) -- 2 sg sino desconecta
while 1 do
    chunk , s = emisor:receive()
    if s=="timeout" then cierra() end
    rellena_buffer(chunk, tam_buffer)

end

