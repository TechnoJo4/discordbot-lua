return {
    name = "Debug",
    emoji = "🔧",
    commands = { {
            ["name"] = "ping",
            ["args"] = {
                [1] = { name = "long", type = "number" },
                [2] = { name = "numb", type = "int[]" },
                [3] = { name = "dick", type = "string" },
                [4] = { name = "bool", type = "boolean[]?" },
            },
            ["aliases"] = {},
            ["function"] = function()
                -- no args on the real function ^^
                local c = ""
                local function x(y)
                    if type(y) == "table" then
                        c = c .. "table:\n"
                        for k,v in pairs(y) do
                            c = c .. "\t" .. tostring(k) .. " = " .. tostring(v) .. " - type: " .. type(v) .. "\n"
                        end
                    else
                        c = c .. tostring(y) .. " - type: " .. type(y) .. "\n"
                    end
                end
                x(long)
                x(numb)
                x(dick)
                x(bool)
                m:reply("```\n"..c.."```")
            end
        }--, {
            -- ...
        --}
    }
}