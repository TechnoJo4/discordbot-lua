---@class env
---@field _env table
---@field _base table

---@param base table
---@param bpath string
---@return env
local function wrap(base, bpath)
    if base._env then base = base._env end
    local env = setmetatable({}, {__index = base})

    return setmetatable({}, {
        __newindex = function(_, k, v) env[k] = v end,
        __index = function(_, k)
            if k == "_env" then return env
            elseif k == "_base" then return base
            else return env[k] end
        end,
        __call = function(_, m)
            if type(m) == "string" then
                local mod, err = loadfile(bpath.."/"..m, "t", env)
                if err then return nil, err end
                return mod()
            elseif type(m) == "function" or type(m) == "number" then
                return setfenv(m, env)
            else
                error("tried to call env wrapper with invalid argument")
            end
        end
    })
end

return wrap
