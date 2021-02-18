local component=require("component")
local racoon=require("racoon")
local rconf = {}
local address
local port
rconf.wan = {}
rconf.lan ={}
local cardlist = {}
local i = 0

for address in pairs(component.list("modem")) do
i = i + 1
cardlist[i] = address
end
for address in pairs(component.list("tunnel")) do
i = i + 1
cardlist[i] = address
end

function selcard()
i = 0

for number, address in pairs(cardlist) do
print(number..") "..address)
i = i + 1
end
answ = tonumber(io.read())

if cardlist[answ] then
  cardaddr = cardlist[answ]
  if component.type(cardaddr) == "tunnel" then
    port = 0
  else
	print("Enter port: ")
    port = io.read()
  end
  if tonumber(port) == nil then
  print("Incorrect port")
  return nil, nil
  end
  table.remove(cardlist, answ)
  i = i - 1
  return cardaddr, tonumber(port)
else
return nil, nil
end
end

print("Select WAN card. Type \"N\" if you dont have WAN card.")
rconf.wan.address, rconf.wan.port = selcard()

while true do
if i == 0 then break end
print("Select LAN card. Type \"N\" to end.")
address, port = selcard()
if address then
rconf.lan[cardaddr:sub(1,3)] = {}
rconf.lan[cardaddr:sub(1,3)].address = address
rconf.lan[cardaddr:sub(1,3)].port = port
else
break
end
end
racoon.writeconfig("router", rconf)