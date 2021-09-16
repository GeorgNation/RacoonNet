local component = require('component')
local event = require('event')
local m = component.modem
local gpu = component.gpu
local term = require('term')

-- Listening and replying port
local dnsport = 42069

-- DNS Table
-- ['dns name'] = 'network card address'
dnsdb = {
  ['pdc.pix', '8e9.af1'] = '8e9.af1',
  ['pixelsk.today', '8e9.c1a'] = '8e9.c1a',
  ['ast.life', '8e9.3d9'] = '8e9.3d9'
}

local localAddress = ''
for address, _ in component.list("modem", false) do
  localAddress = address
  break
end

m.open(dnsport)
gpu.setBackground(0x000000)
gpu.setForeground(0x00ff00)
term.clear()

print('Started DNS Server.')
gpu.setForeground(0xff00ff)
print('Listening and replying to requests on port '..dnsport)
term.write('Address: ')
gpu.setForeground(0xffffff)
term.write(localAddress)

while true do
  local _, _, from, port, _, command, param = event.pull('modem_message')
  local command = string.lower(tostring(command))
  local param = string.gsub(tostring(param), '\n', '')
  gpu.setForeground(0xffff00)
  print('Request from '..from)
  if command == 'lookup' then
    addr = tostring(dnsdb[param])
    gpu.setForeground(0xffffff)
    print('DNS Lookup: '.. param .. ' -> ' .. addr)
    m.send(from, port, addr)
  end
end
