local function ctor(f, name, ...)
    return {
        ["name"] = name,
        ["aliases"] = {...},
        ["args"] = { { name = "tags", type = "+" } },
        ["function"] = f
    }
end

local function gelbooru(base, ...)
    return ctor(function()
        -- TODO
    end, ...)
end

local function moebooru(base, ...)
    return ctor(function()
        -- TODO
    end, ...)
end

return {
    name = "NSFW",
    emoji = "🔞",
    requires = {"http", "json", "xml"},
    commands = {
        gelbooru("https://rule34.xxx/index.php", "rule34", "r34"),
        gelbooru("https://realbooru.com/index.php", "realbooru", "real"),
        gelbooru("https://xbooru.com/index.php", "xbooru"),
        gelbooru("https://gelbooru.com/index.php", "gelbooru", "gel"),

        moebooru("https://yande.re", "yandere"),
        moebooru("https://konachan.com", "konachan"),
    }
}
