-- deps
local fs = require("coro-fs")
local pathjoin = require("pathjoin").pathJoin
local discordia = require('discordia')

-- local deps
local lwrap = require("loader")
local mload = lwrap(getfenv(), "modules")

local parser = require("parser")

-- constants
local PREFIX = "~"
local LPREFIX = #PREFIX

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
    local fol = pathjoin(".", "modules")
    for fname, ftype in fs.scandir() do
        mload("")
    end
end

-- actually run
do
    ---@type Client
    local client = discordia.Client()

    client:on("message", function(m)
        local c = m.content
        if c:sub(1, LPREFIX) ~= PREFIX then
            return
        end

    end)

    coroutine.wrap(client.run)(client, os.getenv("token"))
end
