local rn = require("racoonnet")
local racoon = require("racoon")
local component = require("component")
local io = require("io")
local filesystem = require("filesystem")
local card, err = rn.init(racoon.readconfig("racoonnet"))
local config = {}
config.directory = "/www/"--//Заменить на настройки
local clientip, request, path
local codes = {[302] = "Found", [400] = "Bad Request", [404] = "Not Found", [500] = "Internal Server Error"}

if not card then
  racoon.log("Ошибка подключения к сети: \""..err.."\"!", 4, "webserver")
  return
end
function senderror(code)
  local codestr = code.." "..codes[code]
  local html = "<html><body>"..codestr.."</body></html>"
  local str = "HTTP/1.1 "..codestr.."\nContent-type: text/html\nContent-Length:"..html:len().."\n\n"..html
  card:send(clientip, str)
end

function redirect(redirto)
  local resp = "HTTP/1.1 302 Found\nLocation: "..redirto.."\n\n";
  card:send(clientip, resp)
end

function response()
  clientip, request = card:receive()
  if request:sub(1,3) == "GET" then
    racoon.log("Получен запрос. IP: \""..clientip.."\".", 1, "webserver")
    path = request:match("GET .* HTTP/"):sub(5,request:match("GET .* HTTP/"):len()-6):gsub("[\n ]","")
    if path == nil then senderror(400) return end
    if path:match("%.%.") then senderror(400) return end
    local fpath = filesystem.concat(config.directory, path)
    if filesystem.exists(fpath) == false then senderror(404) return end
    if filesystem.isDirectory(fpath) then 
	  if path:sub(-1) ~= "/" then redirect(filesystem.concat(card.ip, path).."/") return end
      if filesystem.exists(filesystem.concat(fpath, "index.html")) then
	    fpath = filesystem.concat(fpath, "index.html")
	  else
	    local fcontent = "<html><body>Индекс \""..path.."\":<br><a href=\"../\">../</a><br>"
		for name in filesystem.list(fpath)do
		  fcontent = fcontent.."<a href=\"./"..name.."\">"..name.."</a><br>"
		end
		fcontent = fcontent.."</body></html>"
	    local resp = "HTTP/1.1 200 OK\nContent-Type: text/html\nContent-Length: "..fcontent:len().."\n\n"..fcontent;
        card:send(clientip, resp)
		return
	  end
	else
	  if path:sub(-1) == "/" then redirect(filesystem.concat(card.ip, path)) return end
	end
    local file = io.open(fpath, "r")
    local fcontent = file:read("*a")
    local resp = "HTTP/1.1 200 OK\nContent-Type: text/html\nContent-Length: "..fcontent:len().."\n\n"..fcontent;
    card:send(clientip, resp)
  end
end

racoon.log("Запущен WEB сервер. IP: \""..card.ip.."\".", 0, "webserver")
while true do
  response()
end