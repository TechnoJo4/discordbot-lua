---@param str string
return function(str)
    -- just split spaces for now
    args = {}
    for c in str:gmatch("[^ ]+") do
        table.insert(args, c)
    end

    local c = aliases[args[1]]
    if not c then
        return nil, "command"
    end

    return args
end