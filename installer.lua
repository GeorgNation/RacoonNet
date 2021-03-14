local shell = require("shell")
local fs = require("filesystem")
local comp = require("computer")
local prefix = "https://raw.githubusercontent.com/AlexCatze/RacoonNet/indev/main/"
local files = {"/bin/chat.lua","/bin/chat_server.lua","/bin/ping.lua","/bin/rnconfig.lua","/bin/routconf.lua","/bin/router.lua","/bin/webserver.lua","/bin/wr.lua","/etc/config/sys.cfg","/etc/lang/ru.router.lang","/lib/opennet.lua","/lib/racoonnet.lua","/lib/rn_modem.lua","/lib/rn_stem.lua","/lib/rn_tunnel.lua",}



for _,v in pairs(files) do
  if not fs.exists(v:match(".*/")) then fs.makeDirectory(v:match(".*/")) end
  shell.execute("wget -f "..prefix..v.." "..v)
end
comp.shutdown("true")
