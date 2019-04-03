
local tableutils = {}

-- ordered table shit from http://lua-users.org/wiki/OrderedTable --
--[[ usage:
tabl = orderedTable {}
tabl.asdf = object1 -- insert stuff normally
tabl.ghjkl = object2
for i,v in ordered(tabl) do ...tabl[i]... end -- object1 will always be first. also can do print(v)
]]--

function tableutils.orderedTable(t)
  local currentIndex = 1
  local metaTable = {}
    
  function metaTable:__newindex(key,value)
    rawset(self, key, value)
    rawset(self, currentIndex, key)
    currentIndex = currentIndex + 1
  end
  return setmetatable(t or {}, metaTable)
end

function tableutils.ordered(t)
  local currentIndex = 0
  local function iter(t)
    currentIndex = currentIndex + 1
    local key = t[currentIndex]
    if key then return key, t[key] end
  end
  return iter, t
end

-- ordered table shit end

function tableutils.tableContains(tabl, element)
  for _, value in pairs(tabl) do
    if value == element then
      return true
    end
  end
  return false
end

return tableutils
