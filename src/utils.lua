
local function format(s, ...)
    return string.format(s, ...)
end

local function printf(s, ...)
    print(format(s, ...))
end

local function errorf(s, ...)
    error(format(s, ...))
end

return printf, errorf