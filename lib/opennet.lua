local rn=require("racoonnet")
local component=require("component")
local racoon=require("racoon")

local opennet = {}
local card = {}
local err

function opennet.ver()
  return rn.ver()
end

function opennet.getIP()
  local config = racoon.readconfig("racoonnet")
  if config.address then
    card, err = rn.card:init(config.address, config.port)
    if card then
      return card.ip, 0
    else
      return nil, err
    end
  else
    return nil, "Отсутствует конфигурация RacoonNet. Запустите rnconfig."
  end
end

function opennet.send(recIP, ... )
  return card:send(recIP, ... )
end

function opennet.receive(timeout)
  return card:receive(timeout)
end

function opennet.sendrec(recIP, ... )
  return card:sendrec(recIP, ... )
end

return opennet