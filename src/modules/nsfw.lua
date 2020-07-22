local function ctor(f, name, ...)
    return {
        ["name"] = name,
        ["aliases"] = {...},
        ["args"] = { { name = "tags", type = "+" } },
        ["function"] = f
    }
end

local cache = { n = 0 }
local function cc()
    -- clear cache if it gets too big
    local i = 0
    for _,_ in pairs(cache) do i = i + 1 end; cache.n = i
    if i > 128 then cache = { n = 0 } end
end

local illegal_tags = {}
local function illegal(tags)
    -- TODO: add more?
    return tags:match("()loli")
        or tags:match("()shota")
        or tags:match("()scat")
        or tags:match("()guro")
        or tags:match("()gore")
        or tags:match("()child")
end

local function f(fstr, n, ...)
    if #({...}) ~= n then return "" end
    return string.format(fstr, ...)
end

local function post_embed(post, post_base, c)
    Embed()
        :setColor(COLOR)
        :setDescription(table.concat({
                f("Rating: `%s`\n", 1, post.rating),
                f("Score: %s\n", 1, post.score),
                f("Tags: `%s`\n", 1, post.tags),
                f("[View Post](%s%s)", 2, post_base, post.id),
                f("[Goto Source](%s)", 1, post.source)
            }))
        :setImage(post.url)
        :send(c)
end

-- i should probably split the similar code from gelbooru/moebooru into its own function
local function gelbooru(base, ...)
    local post_base = base.."?page=post&s=view&id="
    return ctor(function()
        local data
        do
            local tbl = { page = "dapi", s = "post", q = "index" }
            if tags then tbl.tags = tags end

            local url = http.qstr(tbl, base)
            data = cache[url]
            if not data then
                local _, d = GET(url)
                _x = { xml.parse(d) }
                d, err = unpack(_x)
                if err or not d then
                    Embed()
                        :setColor(0xFF0000)
                        :setTitle("Error")
                        :setDescription("XML parser error:\n%s", err or d.err)
                        :send(c)
                    return
                end
                data = d.children[1]

                cc()

                -- preprocess + remove illegals
                local a = 0
                local new = {}
                for k,v in pairs(data.children) do
                    local att = v.attrs
                    if illegal(att.tags) then
                        a = a + 1
                    else
                        new[k-a] = {
                            id = att.id,
                            tags = att.tags,
                            score = att.score,
                            rating = att.rating,
                            url = att.file_url,
                            source = att.source
                        }
                    end
                end

                data = new; cache[url] = new
            end
        end

        local amm = #data
        if amm < 1 then
            Embed()
                :setColor(0xFF0000)
                :setDescription("No valid posts found.")
                :send(c)
            return
        end

        post_embed(data[math.random(1,amm)], post_base, c)
    end, ...)
end

local function moebooru(base, ...)
    local post_base = base.."/post/show/"
    local base = base.."/post.json"
    return ctor(function()
        local data do
            local url = tags and http.qstr({tags=tags}, base) or base
            data = cache[url]
            if not data then
                local _, d = GET(url)
                data = json.parse(d)

                local a = 0
                local new = {}
                for k,v in pairs(data) do
                    if illegal(v.tags) then
                        a = a + 1
                    else
                        new[k-a] = {
                            id = v.id,
                            tags = v.tags,
                            score = v.score,
                            rating = v.rating,
                            url = v.file_url,
                            source = v.source
                        }
                    end
                end

                cc()
                data = new; cache[url] = new
            end
        end

        local amm = #data
        if amm < 1 then
            Embed()
                :setColor(0xFF0000)
                :setDescription("No valid posts found.")
                :send(c)
            return
        end

        post_embed(data[math.random(1,amm)], post_base, c)
    end, ...)
end

local function open(api, media, name, ...)
    return {
        ["name"] = name,
        ["args"] = {},
        ["aliases"] = { ... },
        ["function"] = function()
            local _, data = GET(api)
            local x = json.parse(data)[1]

            local url = media .. x["preview"]:gsub("_preview", "")

            Embed()
                :setColor(COLOR)
                :setImage(url)
                :send(c)
        end
    }
end

local function nlife(api, name, ...)
    return {
        ["name"] = name,
        ["args"] = {},
        ["aliases"] = { ... },
        ["function"] = function()
            local _, data = GET("https://nekos.life/api/v2/img/" .. api)
            local url = json.parse(data).url

            Embed()
                :setColor(COLOR)
                :setImage(url)
                :send(c)
        end
    }
end


return {
    name = "NSFW",
    emoji = "🔞",
    requires = {"http", "json", "xml"},
    check = function()
        return (c.guild and c.nsfw) or not c.guild, "🔞 This command can only be used in NSFW channels and in DMs."
    end,
    commands = {
        gelbooru("https://rule34.xxx/index.php", "rule34", "r34"),
        gelbooru("https://realbooru.com/index.php", "realbooru", "real"),
        gelbooru("https://xbooru.com/index.php", "xbooru"),
        gelbooru("https://gelbooru.com/index.php", "gelbooru", "gel"),

        moebooru("https://yande.re", "yandere"),
        moebooru("https://konachan.com", "konachan"),

        open("http://api.oboobs.ru/boobs/0/1/random/", "http://media.oboobs.ru/", "oboobs", "boobs", "tits"),
        open("http://api.obutts.ru/butts/0/1/random/", "http://media.obutts.ru/", "obutts", "butt", "ass"),

        nlife("hentai", "hentai"),
        nlife("futanari", "futanari", "hfuta"),
        nlife("trap", "hentai_trap", "htrap"),
        nlife("Random_hentai_gif", "hentai_gif", "hgif"),
    }
}
