local racoon = require("racoon")
local shell = require("shell")
local event = require("event")
local term = require("term")
local args = ...
term.clear()
racoon.log("Загрузка "..args..", для отмены нажмите любую клавишу в течении трех секунд.", 1, "loader")
local ev = event.pull(3,"key_down")
if ev then
  return
end  
while true do
  racoon.log("Попытка запуска "..args..".", 1, "loader")
  local state, err = pcall(shell.execute, args)
  if state == nil then
    racoon.log("Произошла ошибка: \""..err.."\".", 4, "loader")
  end
end