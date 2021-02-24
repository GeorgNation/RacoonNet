local event = require("event")
local rn ={}

function rn.ver()
  return "RacoonNet v0.2"
end

function rn.receiveall(timeout)
  local ev
  ev = {event.pull(timeout,"racoonnet_message")}
  for k,v in pairs(ev) do
  print("!"..v)
  end
  return ev, ev[2], ev[3], table.unpack(ev, 6)
end

function rn.init(data)
  if not data.type then return nil, "Отсутствует конфигурация RacoonNet. Запустите rnconfig."end
  local mod = require("rn_"..data.type)
  return mod:init(data)
end

return rn