-- values here copied straight from discord.py
local _trues = {"yes", "y", "true", "t", "1", "enable", "on"}
local _falses = {"no", "n", "false", "f", "0", "disable", "off"}
local trues = {}
local falses = {}

for k,v in pairs(_trues) do trues[v] = true end
for k,v in pairs(_falses) do falses[v] = true end

_trues = nil
_falses = nil

---@param s string
return function(s)
    s = s:lower()

    if trues[s] then
        return true
    end
    if falses[s] then
        return false
    end

    return nil
end