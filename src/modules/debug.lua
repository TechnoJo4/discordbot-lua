local function swap(a, i, j)
    a[i], a[j] = a[j], a[i]
end

local function shuffle(arr)
    local new = {}
    for k,v in pairs(arr) do
        new[k] = v
    end
    for i = #new, 1, -1 do
        swap(new, i, math.random(i))
    end
    return new
end

return {
    name = "Debug",
    emoji = "🛠️",
    requires = {"http", "json", "xml"},
    check = function()
        return (u == client.owner), "⁉️ This command can only be used by `"..client.owner.tag.."` ("..client.owner.id..")."
    end,
    commands = { {
        ["name"] = "eval",
        ["aliases"] = {}, ["args"] = { { name = "src", type = "+" } },
        ["function"] = function()
            _env(load(src, tostring(m.id)))() -- probably broken
        end
    }, {
        ["name"] = "shufflenicks",
        ["aliases"] = {}, ["args"] = {},
        ["function"] = function()
            local mem = guild.members:toArray()
            local shf = shuffle(mem)
            for k,v1 in pairs(mem) do
                local v2 = shf[k]
                print(v1.user.username.." -> "..v2.user.username)
                v1:setNickname(v2.user.username)
            end
        end
    }, {
        ["name"] = "nickall",
        ["aliases"] = {}, ["args"] = { { name = "nick", type = "+" } },
        ["function"] = function()
            for v in guild.members:iter() do
                if #nick == 0 then
                    v:setNickname(nil)
                else
                    if v.nickname ~= nick then
                        v:setNickname(nick)
                    end
                end
            end
        end
    } }
}
