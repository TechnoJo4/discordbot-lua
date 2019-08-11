-- local deps
local lwrap = require("loader")
local mload = lwrap(getfenv(), "modules")

local Embed = require("embed")
local parser = require("parser")
local printf, errorf = require("utils")

-- deps
local fs = require("fs")
local pathjoin = require("pathjoin").pathJoin
local discordia = require('discordia')

-- constants
local PREFIX = "~"
local LPREFIX = #PREFIX

local COLOR = 0x330077
local ECOLOR = 0xFF0000

-- setup
local parsers = {}
local modules = {}
local aliases = {}

---@type Client
local client = discordia.Client()
---@type Logger
local logger = discordia.Logger()
local function log(...) logger:log(0, ...) end

-- base env & module setup
do
    -- env setup stuff
    function setupenv(tbl, values, aliases)
        aliases = aliases or {}

        for k,v in pairs(values) do
            tbl[k] = v
        end

        for k,v in pairs(aliases) do
            local val = values[k]
            for _,alias in pairs(v) do
                tbl[alias] = val
            end
        end
    end

    setupenv(mload, {
        ["client"] = client,
        ["PREFIX"] = PREFIX,
        ["require"] = require,
        ["modules"] = modules,
        ["aliases"] = aliases,
        ["discordia"] = discordia,
    }, {["discordia"] = {"d", "disc", "discord"}})

    -- load modules
    local schema = {
        ["name"] = "string",
        ["emoji"] = "string",
    }

    for fname in fs.scandirSync("modules") do
        ---@type module
        local mod = mload(fname)

        for f, t in pairs(schema) do
            if not type(mod[f]) == t then
                errorf("Invalid module %q")
            end
        end

        modules[mod.name] = mod
        if mod.commands then
            ---@param c command
            for _,c in pairs(mod.commands) do
                aliases[c.name] = c
                for _,a in pairs(c.aliases) do
                    aliases[a] = c
                end

                -- optional and greedy check
                ---@param a argdef
                for _,a in pairs(c.args) do
                    local t = a.type

                    if a.optional == nil then
                        if t:sub(#t,#t) == "?" then
                            t = t:sub(1,#t-1)
                            a.optional = true
                        else
                            a.optional = false
                        end
                    end

                    if a.greedy == nil then
                        if t:sub(#t-1,#t) == "[]" then
                            t = t:sub(1,#t-2)
                            a.greedy = true
                        else
                            a.greedy = false
                        end
                    end

                    a.type = t
                end
            end
        end
    end
end

-- parser setup
do
    ---@param env env
    -- ---@vararg function
    function wrapall(env, tbl)
        local ret = {}
        for k,v in pairs(tbl) do
            ret[k] = env(v)
        end
        return ret
    end

    -- same env but diff base path
    local tload = lwrap(mload, "types")
    for fname in fs.scandirSync("types") do
        local name = fname:gsub("%.lua", "")
        parsers[name] = tload(fname)
    end
end

-- actually run
do
    ---@param m Message
    client:on("messageCreate", function(m)
        local c = m.content
        if c:sub(1, LPREFIX) ~= PREFIX then
            return
        end
        c = c:sub(1 + LPREFIX)

        local env = lwrap(mload)

        setupenv(env, {
            ["guild"] = m.guild,
            ["author"] = m.author,
            ["channel"] = m.channel,
            ["message"] = m,
        }, {
            ["guild"] = {"g", "server"},
            ["author"] = {"u", "user"},
            ["channel"] = {"c", "chan"},
            ["message"] = {"m", "msg"},
        })

        local wrappedp = wrapall(env, parsers)
        env["parsers"] = wrappedp

        local res, err = env(parser)(c)

        if err then
            Embed()
                :setDescription(err)
                :setColor(0xFF0000)
                :send(m)
            return
        end

        setupenv(env, res.args)
        local wrappedc = env(res.command["function"])
        res, err = pcall(wrappedc)
        if not res then
            m:reply("```\n"..err.."\n```")
        end
    end)

    coroutine.wrap(client.run)(client, "Bot "..os.getenv("token"))
end
