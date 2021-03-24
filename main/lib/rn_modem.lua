local event = require("event")
local component = require("component")
local ser = require("serialization")
local card ={}
local max_packet_size = 8000

card.__index=card

function card:directsend(recAddr, recIP, sendIP , ... )
  local msg = ser.serialize({...})
  while msg:len() > max_packet_size do
    self.proxy.send(recAddr, self.port, recIP, sendIP, msg:sub(1,max_packet_size), "TBC")
	msg = msg:sub(max_packet_size+1)
  end
  return self.proxy.send(recAddr, self.port, recIP, sendIP, msg, "END")
end

function card:send(recIP, ... )
  if not self.proxy or not self.router then
    return nil, "Сетевая карта не инициализирована"
  end
  return self:directsend(self.router, recIP, self.ip, ...)
end

function card:receive(timeout)
  local ev
  repeat
    ev = {event.pull(timeout,"racoonnet_message")}
    if not ev[1] then return nil end
	  if ev[2] == self.proxy.address and ev[6]=="ping" then
	    self:send(ev[5], "pong" )
	    ev[2]=nil
	  end
  until ev[2] == self.proxy.address and ev[4] == self.ip
  return table.unpack(ev, 5)
end

function card:sendrec(recIP, ... )
  local ok,err=self:send(recIP, ... )
  if ok then
    return self:receive(10)
  else
    return ok,err
  end
end

function card:init(data)
  local obj={}
  setmetatable(obj,self)
  obj.address = data.address
  obj.port = data.port
  obj.master = data.master
  obj.recmess = {}
  obj.recmess.ip = ""
  obj.recmess.mess = ""
  if component.type(obj.address) ~= "modem" then return nil, "Сетевая карта не обнаружена!" end
  obj.proxy = component.proxy(obj.address)
  obj.shortaddr=obj.address:sub(1,3)
  obj.proxy.open(obj.port)
  event.listen("modem_message", function (...) 
    local ev = {...}
	if ev[2] == obj.address then
	  local senderIP = ev[7]
	  local msg = ev[8]
	  if obj.recmess.ip == "" then
	    obj.recmess.ip = senderIP
		obj.recmess.mess = msg
	  elseif obj.recmess.ip == senderIP then
	    obj.recmess.mess = obj.recmess.mess..msg
	  end
	  if ev[9] == "END" then
	    event.push("racoonnet_message", ev[2], ev[3], ev[6], senderIP, table.unpack(ser.unserialize(obj.recmess.mess)))
		obj.recmess.mess = ""
		obj.recmess.ip = ""
	  end
	end 
  end)
  if obj.master then
    obj.ip = obj.master
	obj.routerip = obj.master
	obj.router = obj.address
	return obj 
  end
  local ok,err=obj.proxy.broadcast(obj.port,"", "", ser.serialize({"getip"}), "END")
  if not ok then  return ok, err  end
  while true do
    local ev, addr, rout, locip, routip, mess = event.pull(1,"racoonnet_message") 
    if ev then
      if addr == obj.proxy.address and mess == "setip" then
  	    obj.ip=locip
		obj.router=rout
		obj.routerip = routip
        return obj
	  end
    else
      return nil, "Нет ответа от роутера" 
    end
  end
end

return card