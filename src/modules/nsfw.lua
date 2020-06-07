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
    return tags:match("()loli")
        or tags:match("()shota")
        or tags:match("()scat")
        or tags:match("()guro")
        or tags:match("()gore")
end

local function post_embed(post, show_base, c)
    if show_base then
        Embed()
            :setColor(COLOR)
            :setDescription(
                --  "Rating: `%s`\nScore: %s\nTags: `%s`\n[View Post](%s%s)\n[Goto Source](%s)",
                    "Rating: `%s`\nScore: %s\nTags: `%s`\nView Post: %s%s\nSource: %s",
                    post.rating, post.score, post.tags, show_base, post.id, post.source)
            :setImage(post.url)
            :send(c)
    else
        Embed()
            :setColor(COLOR)
            :setDescription("Rating: `%s`\nScore: %s\nTags: `%s`", post.rating, post.score, post.tags)
            :setImage(post.url)
            :send(c)
    end
end

local function gelbooru(base, ...)
    local show_base = base.."?page=post&s=view&id="
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

        post_embed(data[math.random(1,amm)], show_base, c)
    end, ...)
end

local function moebooru(base, ...)
    local show_base = base.."/post/show/"
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

        post_embed(data[math.random(1,amm)], show_base, c)
    end, ...)
end


local clocks = {}
local function __open(api, media)
    local _, data = GET(api)
    local x = json.parse(data)[1]

    local url = media .. x["preview"]:gsub("_preview", "")

    Embed()
        :setColor(COLOR)
        :setImage(url)
        :send(c)
end

local function __from_cache()
    if cache.n == 0 then return end
    local a, i = math.random(1, cache.n-1), 1

    for k,v in pairs(cache) do
        if k ~= "n" then
            if i >= a and #v > 0 then
                post_embed(v[math.random(1, #v)], nil, c)
            return end
            i = i + 1
        end
    end
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

        {
            ["name"] = "auto_test",
            ["args"] = {}, ["aliases"] = {},
            ["function"] = function()
                local cid = c.id
                if clocks[cid] then
                    clocks[cid]:stop()
                    clocks[cid] = nil
                return end

                local clock = d.Clock()
                clocks[cid] = clock

                local i = 1
                local yes = {
                    { "http://api.oboobs.ru/boobs/0/1/random/", "http://media.oboobs.ru/", __open },
                    { "http://api.obutts.ru/butts/0/1/random/", "http://media.obutts.ru/", __open },
                    { __from_cache }
                }

                clock:on("min", function()
                    _env(yes[i][#yes[i]])(unpack(yes[i]))
                    i = ((i >= #yes) and 1 or (i + 1))
                end)

                clock:start()
            end
        }
    }
}
