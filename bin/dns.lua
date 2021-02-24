rn = require("racoonnet")

DNS={}
FileName="dns.dat"
LogName ="dns.log"
function LoadFromFile()
  local Name, IPaddr, paswd, owner
  DNS={}
  file=io.open(FileName,"r")
  if file then
    for line in file:lines() do
      Name, IPaddr, paswd, owner = line:match("(%S+)%s+(%S+)%s+(%S+)%s+(%S+)")
      if Name then DNS[Name]={adr=IPaddr, pwd=paswd, own=owner} end
    end
    file:close()
  end
end

function SaveToFile()
  file=io.open(FileName,"w")
  for Name, dns in pairs(DNS) do
    file:write(Name,"  ",dns.adr,"  ",dns.pwd,"  ",dns.own,"\n")
  end
  file:close()
end

local myIP,err=on.getIP("dns")
if not myIP then
  print(err)
  return
end

local sendIP, command

commands={}
function commands.ping()
  return "pong"
end

function commands.ver()
  return "1.0"
end

function commands.setDNS(Name, IPaddr, paswd, newPwd)
  newPwd=newPwd or paswd
  if type(Name)~="string" or type(IPaddr)~="string" or type(newPwd)~="string" then
    return false, "DNS-имя, IP-адрес или пароль: недопустимый тип"
  end
  if Name:find(" ") or IPaddr:find(" ") or newPwd:find(" ") then
    return false, "DNS-имя, IP-адрес или пароль содержат пробелы"
  end
  if DNS[Name] and DNS[Name].pwd~=paswd then
    return false, "Несовпадение пароля"
  end
  if DNS[Name] and DNS[Name].adr==IPaddr and DNS[Name].pwd==newPwd then
    return true, "Данные не изменились"
  end
  DNS[Name]={adr=IPaddr, pwd=paswd, own=sendIP}
  SaveToFile()
  return true, Name, "Запись сохранена"
end

function commands.DNStoIP(Name)
  if DNS[Name] then
    return Name, DNS[Name].adr
  else
    return Name, false, "DNS-имя не зарегистрировано"
  end
end

function commands.IPtoDNS(IPaddr)
  local Names={}
  for Name,dns in pairs(DNS) do
    if dns.adr==IPaddr then Names[#Names+1]=Name end
  end
  return IPaddr, table.unpack(Names)
end

LoadFromFile()
while true do
  local dat = {on.receive()}
  sendIP, command = dat[1], dat[2]
  if command then
    print("-->",table.unpack(dat))
    if commands[command] then
      on.send(sendIP, command, commands[command](table.unpack(dat,3)) )
    else
      on.send(sendIP, false, command, "Недопустимая команда" )
	end
  end
end