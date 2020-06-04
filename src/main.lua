-- local deps
local lwrap = require("loader")
local mload = lwrap(getfenv(), "modules")

local Embed = require("embed")
local parser = require("parser")
local printf, errorf = unpack(require("./utils"))

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
local utils = {}
local parsers = {}
local modules = {}
local aliases = {}

---@type Client
local client = discordia.Client()

-- base env, util & module setup
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
        ["Embed"] = Embed,
        ["COLOR"] = COLOR,
        ["ECOLOR"] = ECOLOR,
        ["PREFIX"] = PREFIX,
        ["client"] = client,
        ["require"] = require,
        ["modules"] = modules,
        ["aliases"] = aliases,
        ["discordia"] = discordia,
        ["version"] = require("../package").version,
    }, {["discordia"] = {"d", "disc", "discord"}})

    local uload = lwrap(mload, "utils")
    for fname in fs.scandirSync("utils") do
        local mod, err = uload(fname)
        if not mod then errorf("Error loading %q:\n\t%s", fname, err) end
        utils[mod.id] = mod
    end

    -- load modules
    local schema = {
        ["name"] = "string",
        ["emoji"] = "string",
        -- TODO: COMPLETE THIS
    }

    for fname in fs.scandirSync("modules") do
        ---@type module
        local mod = mload(fname)

        for f, t in pairs(schema) do
            -- TODO: ALONG WITH THIS
            if not type(mod[f]) == t then
                errorf("Invalid module %q", mod.name)
            end
        end

        modules[mod.name] = mod
        if mod.commands then
            ---@param c command
            for _,c in pairs(mod.commands) do
                c.module = mod
                aliases[c.name] = c
                for _,a in pairs(c.aliases) do
                    aliases[a] = c
                end

                -- optional and greedy check
                ---@param a argdef
                for _,a in pairs(c.args or {}) do
                    local t = a.type

                    if t:sub(#t,#t) == "?" then
                        a.optional = true; a.greedy = false
                    elseif t ~= "+" and t:sub(#t,#t) == "+" then
                        a.optional = false; a.greedy = true
                    elseif t:sub(#t,#t) == "*" then
                        a.optional = true; a.greedy = true
                    else a.optional = false; a.greedy = false end

                    if a.optional or a.greedy then
                        t = t:sub(1, #t-1)
                    end

                    a.type = t
                end
            end
        end
    end
end

-- parser setup
local wrapall do
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
            ["reply"] = function(v)m:reply(v)end
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
            return Embed()
                :setDescription(err)
                :setColor(0xFF0000)
                :send(m)
        end

        if res.command.module.check then
            local v, err_msg = env(res.command.module.check)()
            if not v then
                Embed()
                    :setColor(0xFF0000)
                    :setTitle("Error")
                    :setDescription(err_msg)
                    :send(m)
                return
            end
        end

        for _,u in pairs(res.command.module.requires or {}) do
            local util = utils[u]
            env[u] = util
            for _,v in pairs(util.g or {}) do
                env[v] = util[v]
            end
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
