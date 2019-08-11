return function(s)
    local n = tonumber(s)

    if not n then return nil end
    if math.floor(n) ~= n then return nil end

    return n
end