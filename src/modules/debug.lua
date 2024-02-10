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
    } }
}
