local component=require("component")
local event = require("event")
local rn ={}
rn.card = {}
rn.card.__index=rn.card

rn.cardlist = {}

function rn.ver()
  return "RacoonNet v0.1"
end

function rn.card:directsend(recAddr, recIP, ... )
  if component.type(self.address) == "tunnel" then
    return self.proxy.send(recIP, ...)
  else
    return self.proxy.send(recAddr, self.port, recIP, ...)
  end
end

function rn.card:send(recIP, ... )
  if not self.proxy or not self.router then
    return nil, "Сетевая карта не инициализирована"
  end
  if component.type(self.address) == "tunnel" then
    return self.proxy.send(recIP, self.ip, ...)
  else
    return self.proxy.send(self.router, self.port, recIP, self.ip, ...)
  end
end

function rn.card:receive(timeout)
  local ev
  repeat
    ev = {event.pull(timeout,"modem_message")}
    if not ev[1] then return nil end
	  if ev[2] == self.proxy.address and ev[8]=="ping" then
	    self:send(ev[7], "pong" )
	    ev[2]=nil
	  end
  until ev[2] == self.proxy.address and ev[6] == self.ip
  return table.unpack(ev,7)
end

function rn.receiveall(timeout)
  local ev
  repeat
    ev = {event.pull(timeout,"modem_message")}
  until rn.cardlist[ev[2]]
  return ev, ev[2], ev[3], table.unpack(ev, 6)
end

function rn.card:sendrec(recIP, ... )
  local ok,err=self:send(recIP, ... )
  if ok then
    return self:receive(10)
  else
    return ok,err
  end
end

function rn.card:new(_Name)
  local obj={Name = _Name}
  setmetatable(obj,self)
  return obj
end

function rn.card:init(cardaddr, port, forceip, forcerouter)
  local obj={cardaddr = cardaddr, port = port, forceip = forceip, forcerouter = forcerouter}
  setmetatable(obj,self)
  obj.proxy = component.proxy(cardaddr)
  obj.address=cardaddr
  obj.shortaddr=cardaddr:sub(1,3)
  if component.type(obj.address) == "tunnel" then
    obj.port = 0
  else
    obj.port = port
    obj.proxy.open(obj.port)
  end
  if forceip or forcerouter then
    obj.ip = forceip
	obj.routerip = obj.ip
	obj.router = forcerouter
	rn.cardlist[obj.address] = obj
	return obj 
  end
  if component.type(obj.address) == "tunnel" then
    local ok,err=obj.proxy.send("", "", "getip")
  else
	local ok,err=obj.proxy.broadcast(obj.port,"", "", "getip")
	if not ok then  return ok, err  end
  end
  rn.cardlist[obj.address] = obj
  while true do
    local ev, addr, rout, locip, routip, mess
    if component.type(obj.address) == "tunnel" then
      ev, addr, rout, _, _, locip, routip, mess = event.pull(1,"modem_message")
    else
      ev, addr, rout, _, _, locip, routip, mess = event.pull(1,"modem_message")
    end	  
    if ev then
      if addr == obj.proxy.address and mess == "setip" then
  	    obj.ip=locip obj.router=rout obj.routerip = routip
        return obj
	  end
    else
      return nil, "Нет ответа от роутера" 
    end
  end
end


return rn