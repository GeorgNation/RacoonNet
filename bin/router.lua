component = require("component")
event = require("event")
rn = require("racoonnet")
computer = require('computer')
racoon = require("racoon")

local clients = {}
local clientscard = {}
local wan
local lan = {}
local ip
local err
local config = racoon.readconfig("router")

--//Функция отправки пакета по ip получателя
function route(recieverip, senderip, ... )
  local m
  local cl
  for client in pairs(clients) do
    m = recieverip:find(client)
    if m then cl = client break end
  end
  if m then
    lan[clientscard[cl]:sub(1,3)]:directsend(clients[cl], recieverip, senderip, ...)
	racoon.log("Отправлен пакет через LAN. IP получателя: \""..recieverip.."\". IP отправителя: \""..senderip.."\". Адресс получателя: \""..clients[cl].."\". Интерфейс: \""..clientscard[cl]:sub(1,3).."\".", 1, "router")
  else
    if wan then
	  wan:directsend(wan.router, recieverip, senderip, ...)
	  racoon.log("Отправлен пакет через WAN. IP получателя: \""..recieverip.."\". IP отправителя: \""..senderip.."\". Адресс получателя: \""..wan.router.."\".", 1, "router")
	else
	  racoon.log("Не удалось доставить пакет. IP получателя: \""..recieverip.."\".",2, "router")
    end
  end
end

--//Список комманд роутера
commands={}

--//Пинг
function commands.ping()
  racoon.log("Получен ping от: "..sendIP, 1, "router")
  route(sendIP, recIP, "pong" )
  return 
end

--//Версия
function commands.ver()
  racoon.log("Получен ver от: "..sendIP, 1, "router")
  route(sendIP, recIP, "WiFi router ver 1.0" )
  return 
end

--//Выдача ip
function commands.getip()
  if lan[acceptedAdr:sub(1,3)] then
    local adr=ip.."."..senderAdr:sub(1,3)
	clients[adr]=senderAdr
	clientscard[adr]=acceptedAdr
    lan[acceptedAdr:sub(1,3)]:directsend(senderAdr, adr, acceptedAdr:sub(1,3), "setip" )
	racoon.log("Выдан IP: "..adr, 1, "router")
    return 
  else
    return
  end
end
racoon.log("Запуск роутера", 1, "router")
if not config.lan then
  racoon.log("Не удалось загрузить конфигурацию", 4, "router")
  return
end

--//Инициализируем WAN карту
if config.wan.address then
  wan, err = rn.card:init(config.wan.address,config.wan.port)
  if wan then
    racoon.log("Инициализированна WAN карта: \""..wan.address:sub(1,3).."\". Порт: \""..wan.port.."\". Шлюз: \""..wan.routerip.."\".", 0, "router")
  else
    racoon.log("Ошибка инициализации WAN карты: \""..err.."\"!", 3, "router")
  end
else
  racoon.log("Невозможно инициализировать WAN карту, не указан ID", 2, "router")
end
if wan then
  ip = wan.ip
else
  ip = computer.address():sub(1,3)
end
racoon.log("IP: \""..ip.."\"", 1, "router")

--//Инициализируе LAN карты
for saddr, obj in pairs(config.lan) do
  lan[saddr], err = rn.card:init(obj.address,obj.port, ip, obj.address)
  if lan[saddr] then
    racoon.log("Инициализирована LAN карта: \""..lan[saddr].address:sub(1,3).."\". Порт: \""..lan[saddr].port.."\".", 0, "router")
  else 
    racoon.log("Ошибка инициализации LAN карты: \""..err.."\"!", 3, "router")
  end
end

--//Основной цикл
while true do
    packet, acceptedAdr, senderAdr, recIP, sendIP, command = rn.receiveall()
	if recIP == ip or recIP == "" then
	  if commands[command] then
	      commands[command](table.unpack(packet,9))
	  end  
	else
	  route(recIP,sendIP,table.unpack(packet,8))
	end
end
