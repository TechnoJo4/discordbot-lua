local fs = require("fs")

local categories

return {
    name = "Download",
    emoji = "💧",
    requires = { "http", "json" },
    setup = function()
        categories = json.parse(fs.readFileSync("../data/download.json"))
    end,
    commands = { {
        ["name"] = "download",
        ["aliases"] = { "dl" },
        ["args"] = { { name = "category", type = "string" }, { name = "url", type = "string" } },
        ["function"] = function()
            local cat = categories[category]
            if not cat then
                Embed()
                    :setColor(ECOLOR)
                    :setTitle("Error")
                    :setDescription("Category `"..category.."` does not exist")
                    :send(m)
                return
            end

            if not url:match("^https?://") then
                Embed()
                    :setColor(ECOLOR)
                    :setTitle("Error")
                    :setDescription("Invalid URL")
                    :send(m)
                return
            end

            local torrent
            for pat,out in pairs(cat) do
                local m = { string.match(url, pat) }
                if m[1] then
                    torrent = string.gsub(out, "$(%d+)", function(n)
                        return m[tonumber(n)]
                    end)
                    break
                end
            end

            if not torrent then
                Embed()
                    :setColor(ECOLOR)
                    :setTitle("Error")
                    :setDescription("URL did not match any of the patterns for `"..category.."`")
                    :send(m)
                return
            end

            local res, body = GET(torrent)
            if res.code >= 300 then
                Embed()
                    :setColor(ECOLOR)
                    :setTitle("Error")
                    :setDescription("Failed to download (HTTP "..tostring(res.code)..")")
                    :send(m)
                return
            end

            fs.writeFileSync("../downloads/"..cat.folder.."/"..os.time()..".torrent", body)
            Embed()
                :setColor(COLOR)
                :setDescription("Downloaded <"..torrent..">")
                :send(m)
        end
    } }
}
