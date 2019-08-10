-- deps
local fs = require("coro-fs")
local pathjoin = require("pathjoin").pathJoin
local discordia = require('discordia')

-- local deps
local lwrap = require("loader")
local mload = lwrap(getfenv(), "modules")

local Embed = require("embed")
local parser = require("parser")
local printf, errorf = require("utils")

-- constants
local PREFIX = "~"
local LPREFIX = #PREFIX

local COLOR = 0x330077
local ECOLOR = 0xFF0000

-- setup
local modules = {}
local aliases = {}

do
    -- env setup stuff
    function setupenv(tbl, values, aliases)
        aliases = aliases or {}

        for k,v in pairs(values) do
            tbl[k] = v
        end

        for k,v in pairs(aliases) do
            local val = values[k]
            for _,alias in v do
                tbl[alias] = val
            end
        end
    end

    setupenv(mload, {
        ["PREFIX"] = PREFIX,
        ["modules"] = modules,
        ["aliases"] = aliases,
        ["discordia"] = discordia,
    }, {["discordia"] = {"d", "disc", "discord"}})

    -- load modules
    local co = coroutine.running()
    coroutine.wrap(function()
        local fol = pathjoin(".", "modules")
        local req = {
            ["name"] = "string",
            ["emoji"] = "string",
        }

        for fname in fs.scandir("modules") do
            local mod = mload(fname)
            for f, t in pairs(req) do
                if not type(mod[f]) == t then
                    errorf("Invalid module %q")
                end
            end
        end
        coroutine.resume(co)
    end)()
    coroutine.yield()
end

-- actually run
do
    ---@type Client
    local client = discordia.Client()

    ---@param m Message
    client:on("message", function(m)
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

        local res, err = env(parser)(c)

        if err then
            m:reply(Embed()
                :setDescription("Invalid %s.", err)
                :setColor(0xFF0000)
                :build())
        end
    end)

    coroutine.wrap(client.run)(client, os.getenv("token"))
end
