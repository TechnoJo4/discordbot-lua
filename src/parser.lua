-- state "enum"
local CMD = 0 -- command
local NRM = 1 -- normal
local QTE = 2 -- quoted
local ESC = 3 -- escape
local REM = 4 -- remainder

---@param str string
return function(str)
    local s = 0
    local i = 0

    ---@type command
    local cmd

    ---@type argdef[]
    local defs

    local cur = ""
    local args = {}
    local money = 0

    local function stop(c, islast)
        if s == CMD then
            cmd = (cmd or aliases)[cur] -- cmd is non-nil if in group
            if not cmd then return nil, "Invalid command." end
            cur = ""
            if not cmd.group then
                defs = cmd.args
                i = 1
                s = NRM

                if defs[i] and defs[i].type == "+" then s = REM end
            end
        elseif s == QTE then
            if islast then
                return nil, "Unfinished quote."
            end
            cur = cur .. c
        else
            local function x()
                ---@type argdef
                local def = defs[i]
                if not def then
                    p(i, defs[i])
                    return def, nil, "Too many arguments."
                end
                if def.greedy and money == 0 then
                    args[def.name] = {}
                end

                local conv = parsers[def.type]
                if not conv then
                    return def, nil, ("Internal error (no converter for type `%s`)."):format(def.type)
                end
                return def, conv(cur)
            end

            local def, val, err = x()
            if err then return nil, err end
            if val == nil then
                if def.optional or (def.greedy and money ~= 0) then
                    money = 0
                    i = i + 1
                    def, val, err = x()
                    if err then return nil, err end
                else
                    return nil, ("Failed to parse `%s` as a `%s`."):format(cur, def.type)
                end
            end

            if def.greedy then
                money = money + 1
                args[def.name][money] = val
            else
                args[def.name] = val
                i = i + 1
            end
            cur = ""
        end

        if islast then
            local lastreq = 0
            for di,def in pairs(defs) do
                if not def.optional then
                    lastreq = di
                end
            end
            if i < lastreq then
                return nil, "Not enough arguments."
            end
        end
    end

    for c in str:gmatch(".") do
        if s == REM then
            cur = cur .. c
        elseif s == ESC then
            if c == "n" then c = "\n" end
            cur = cur .. c
        elseif c == " " then
            local _, err = stop(c, false)
            if err then return nil, err end
        elseif c == "\"" then
            if s == QTE then
                s = NRM
            elseif s == CMD then
                return nil, "Invalid command."
            else
                s = QTE
            end
        elseif c == "\\" then
            s = ESC
        else
            cur = cur .. c
        end
    end

    if s == REM then
        args[defs[i].name] = cur
    else
        local _, err = stop("", true)
        if err then return nil, err end
    end

    return {
        command = cmd,
        args = args
    }
end
