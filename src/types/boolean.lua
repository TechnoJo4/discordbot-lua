local trues = {"yes", "y", "true", "t", "1", "enable", "on"}
local falses = {"no", "n", "false", "f", "0", "disable", "off"}

for k,v in pairs(trues) do trues[v] = true trues[k] = nil end
for k,v in pairs(falses) do falses[v] = true falses[k] = nil end

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