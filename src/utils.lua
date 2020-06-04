local function format(s, ...)
    -- this'll be bigger, format discordia stuff, etc. later
    -- for now it's just string.format cause im lazy
    -- i wish __repr__ existed
    return string.format(s, ...)
end

local function printf(s, ...)
    print(format(s, ...))
end

---@param s string
local function errorf(s, ...)
    error(format(s, ...))
end

return {printf, errorf}
