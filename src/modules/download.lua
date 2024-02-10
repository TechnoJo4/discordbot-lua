local fs = require("fs")

return {
    name = "Download",
    emoji = "💧",
    requires = {"http"},
    commands = {},
    groups = {
        dl = { {
            ["name"] = "manga",
            ["aliases"] = {},
            ["args"] = { { name = "url", type = "+" } },
            ["function"] = function()
                local name = url:match("/(%w-%.torrent)$")
                if not name then
                    print(url)
                    Embed()
                        :setColor(ECOLOR)
                        :setTitle("Error")
                        :setDescription("URL must end with `.torrent`")
                        :send(m)
                    return
                end

                local res, body = GET(url)
                if res.code >= 300 then
                    Embed()
                        :setColor(ECOLOR)
                        :setTitle("Error")
                        :setDescription("Failed to download (HTTP "..tostring(res.code)..")")
                        :send(m)
                    return
                end

                fs.writeFileSync("../downloads/manga/"..name, body)
                Embed()
                    :setColor(COLOR)
                    :setDescription("ok")
                    :send(m)
            end
        } }
    }
}
