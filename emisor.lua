#!/usr/bin/lua
-----------------------------------------------------------------------------
--  Server for UDP Streaming
-----------------------------------------------------------------------------
local socket = require("socket")
host = "127.0.0.1"
port =  7777
block = 1024 
tam_buffer = 250
tam_cabecera= 10
player_port = 27703

if arg then
    host = arg[1] or host
    port = tonumber(arg[2]) or port
    block = tonumber(arg[3]) or block
end
--host = socket.dns.toip(host)

--Abre el video desde una fuente de video en localhost en un puerto determinado
os.execute('vlc conejo.ogv --sout "#duplicate{dst=standard{mux=ogg,dst=,access=http}}"'..
             '--http-host=localhost --http-port='..player_port..' &')
os.execute("sleep 1")
player=socket.connect("localhost", player_port)
if not player then print("El player no esta reproduciendo") os.exit() end
assert(player:send("GET / HTTP/1.0\r\n Host: localhost:"..player_port.."\r\n\r\n"))
repeat  l=player:receive() until l==""

--Guarda la cabecera para cuando se conecten varios receptores
cabecera = {}
for i=1, tam_cabecera, 1 do
    table.insert(cabecera,(player:receive(1024))) --La cabecera "minima"
end


function crea_receptor(host, port)
    local rutina = coroutine.create(function ()
        --Crea el socket de receptor
        local receptor = assert(socket.udp())
        receptor:settimeout(0.5) -- 500 s
        receptor:setpeername(host, port)

        print("Esperando solicitud de cabecera desde "..host..":"..port)
        repeat --Espera a que se conecte el receptor y pida la cabecera
            receptor:send("ping") 
            datos = receptor:receive()
            if datos and datos=="cabecera" then
                for i, v in ipairs(cabecera) do
                    receptor:send(i.."-"..(socket.gettime()*1000).."-"..v)  
                end
            else
                coroutine.yield() --Pierde timeout*sinCabeceras*nChunks sg
            end
            datos = receptor:receive() --Recibe el ok
        until datos and datos == "ok"
        print("Cabecera enviada a "..host..":"..port)
        coroutine.yield()

        local buffer = 0
        while 1 do
            buffer=buffer+1
            if(buffer == tam_buffer) then 
                print("BufferLLeno en "..host..":"..port)
            end
            assert(receptor:send(buffer.."-"..(socket.gettime()*1000).."-"..chunk))
            if buffer == tam_buffer then buffer=0 end
            local chunk=coroutine.yield()
        end
    end)
    table.insert(receptores,rutina)
    coroutine.resume(rutina)
end

receptores = {}
crea_receptor(host,port)
--Otros receptores...
crea_receptor(host,4444)
--crea_receptor(localhost,6666)

while 1 do --Envia cada paquete que recibe a los receptores
    chunk=assert(player:receive(block))
    for _, receptor in ipairs(receptores) do
        coroutine.resume(receptor, chunk)
    end
end
