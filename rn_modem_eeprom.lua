--component = require("component")
--computer = require("computer")

local ser = {}

crd = {}
ti = table.insert
mh = math.huge
local local_pairs = function(tbl)
  local mt = getmetatable(tbl)
  return (mt and mt.__pairs or pairs)(tbl)
end

function ser.serialize(value, pretty)
  local kw =  {["and"]=true, ["break"]=true, ["do"]=true, ["else"]=true,
               ["elseif"]=true, ["end"]=true, ["false"]=true, ["for"]=true,
               ["function"]=true, ["goto"]=true, ["if"]=true, ["in"]=true,
               ["local"]=true, ["nil"]=true, ["not"]=true, ["or"]=true,
               ["repeat"]=true, ["return"]=true, ["then"]=true, ["true"]=true,
               ["until"]=true, ["while"]=true}
  local id = "^[%a_][%w_]*$"
  local ts = {}
  local rp = {}
  local function recurse(cf, depth)
    local t = type(cf)
    if t == "number" then
      if cf ~= cf then
        ti(rp, "0/0")
      elseif cf == mh then
        ti(rp, "mh")
      elseif cf == -mh then
        ti(rp, "-mh")
      else
        ti(rp, tostring(cf))
      end
    elseif t == "string" then
      ti(rp, (string.format("%q", cf):gsub("\\\n","\\n")))
    elseif
      t == "nil" or
      t == "boolean" or
      pretty and (t ~= "table" or (getmetatable(cf) or {}).__tostring) then
      ti(rp, tostring(cf))
    elseif t == "table" then
      if ts[cf] then
        if pretty then
          ti(rp, "recursion")
          return
        else
          error("tables with cycles are not supported")
        end
      end
      ts[cf] = true
      local f
      if pretty then
        local ks, sks, oks = {}, {}, {}
        for k in local_pairs(cf) do
          if type(k) == "number" then
            ti(ks, k)
          elseif type(k) == "string" then
            ti(sks, k)
          else
            ti(oks, k)
          end
        end
        table.sort(ks)
        table.sort(sks)
        for _, k in ipairs(sks) do
          ti(ks, k)
        end
        for _, k in ipairs(oks) do
          ti(ks, k)
        end
        local n = 0
        f = table.pack(function()
          n = n + 1
          local k = ks[n]
          if k ~= nil then
            return k, cf[k]
          else
            return nil
          end
        end)
      else
        f = table.pack(local_pairs(cf))
      end
      local i = 1
      local first = true
      ti(rp, "{")
      for k, v in table.unpack(f) do
        if not first then
          ti(rp, ",")
          if pretty then
            ti(rp, "\n" .. string.rep(" ", depth))
          end
        end
        first = nil
        local tk = type(k)
        if tk == "number" and k == i then
          i = i + 1
          recurse(v, depth + 1)
        else
          if tk == "string" and not kw[k] and string.match(k, id) then
            ti(rp, k)
          else
            ti(rp, "[")
            recurse(k, depth + 1)
            ti(rp, "]")
          end
          ti(rp, "=")
          recurse(v, depth + 1)
        end
      end
      ts[cf] = nil
      ti(rp, "}")
    else
      error("unsupported type: " .. t)
    end
  end
  recurse(value, 1)
  local result = table.concat(rp)
  if pretty then
    local limit = type(pretty) == "number" and pretty or 10
    local truncate = 0
    while limit > 0 and truncate do
      truncate = string.find(result, "\n", truncate + 1, true)
      limit = limit - 1
    end
    if truncate then
      return result:sub(1, truncate) .. "..."
    end
  end
  return result
end

function ser.unserialize(data)
  checkArg(1, data, "string")
  local result, reason = load("return " .. data, "=data", nil, {math={huge=mh}})
  if not result then
    return nil, reason
  end
  local ok, output = pcall(result)
  if not ok then
    return nil, output
  end
  return output
end

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
    local mess = ""
	local ip = ""
    repeat
      ev = {computer.pullSignal(timeout)}
	  if ev[1] == "modem_message" and ev[2] == self.address then
	    local senderIP = ev[7]
	    local msg = ev[8]
	    if ip == "" then
	      ip = senderIP
		  mess = msg
	    elseif ip == senderIP then
	      mess = mess..msg
	    end
      end
    until ev[9] == "END" or not ev[1]
	eve = {ip, table.unpack(ser.unserialize(mess))}
    if not eve[1] then return nil end
	if eve[2]=="ping" then
	  self:send(eve[1], "pong" )
	  eve[1]=nil
	end
  return table.unpack(eve)
end

function card:sendrec(recIP, ... )
  local ok,err=self:send(recIP, ... )
  if ok then
    return self:receive(10)
  else
    return ok,err
  end
end

function card:init()
  local obj={}
  setmetatable(obj,self)
  obj.proxy = component.proxy(component.list("modem")())
  obj.address = obj.proxy.address
  obj.port = 1
  obj.shortaddr=obj.address:sub(1,3)
  obj.proxy.open(obj.port)
  local ok,err=obj.proxy.broadcast(obj.port,"", "", ser.serialize({"getip"}), "END")
  if not ok then  return ok, err  end
  while true do
    local ev, addr, rout,_,_, locip, routip, mess = computer.pullSignal(1) 
    if ev then
      if ev == "modem_message" and addr == obj.proxy.address and ser.unserialize(mess)[1] == "setip" then
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

i = 1

gpu = component.proxy(component.list("gpu")())
crd = card:init()
gpu.set(1, i, crd.ip)
i = i + 1
while true do
  a,b = crd:receive()
  gpu.set(1, i, a.." "..b)
  i = i + 1
end