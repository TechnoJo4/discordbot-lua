return {
    name = "Base",
    emoji = "🧰",
    requires = {},
    commands = { {
        ["name"] = "shutdown",
        ["check"] = function()
            return (u == client.owner), "⁉️ This command can only be used by `"..client.owner.tag.."` ("..client.owner.id..")."
        end,
        ["aliases"] = {}, ["args"] = {},
        ["function"] = function()
            for _,mod in pairs(modules) do
                if mod.teardown then
                    mod.teardown()
                end
            end
            client:stop()
            os.exit()
        end
    } }
}
