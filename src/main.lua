-- local deps
local lwrap = require("loader")
local mload = lwrap(getfenv(), "modules")

local Embed = require("embed")
local parser = require("parser")
local printf, errorf = unpack(require("./utils"))

-- deps
local fs = require("fs")
local json = require("json")
local pathjoin = require("pathjoin").pathJoin
local discordia = require("discordia")

-- load config
local config = assert(json.parse(assert(fs.readFileSync("../data/config.json"))))

local PREFIX = assert(config.prefix)
local LPREFIX = #PREFIX
local CASE_INSENSITIVE = PREFIX:upper() ~= PREFIX:lower()

local COLOR = tonumber("0x" .. config.color)
local ECOLOR = tonumber("0x" .. config.error_color)

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
        ["_lwrap"] = lwrap,
        ["_setupenv"] = setupenv,
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
    }, { ["discordia"] = {"disc", "discord"} })

    local uload = lwrap(mload, "utils")
    for fname in fs.scandirSync("utils") do
        local mod, err = uload(fname)
        if not mod then errorf("Error loading %q:\n\t%s", fname, err) end
        utils[mod.id] = mod
    end

    -- load modules
    for _,v in pairs(config.modules) do
        ---@type module
        local mod = assert(mload(v..".lua"))

        if mod then
            local function _cmd(c, m, g, at)
                c.module = m
                c.parent = g
                at[c.name] = c
                for _,a in pairs(c.aliases) do at[a] = c end

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
                    else
                        a.optional = false; a.greedy = false
                    end

                    if a.optional or a.greedy then
                        t = t:sub(1, #t-1)
                    end

                    a.type = t
                end
            end

            local function _grp(g, m, p, at, name)
                local _at = {}
                for k,v in pairs(g) do
                    if k == "aliases" then
                        for _,alias in pairs(v) do
                            (at or aliases)[alias] = _at
                        end
                    else
                        (type(k) == "string" and _grp or _cmd)(v, m, g, _at, k)
                    end
                end
                _at.group = true
                (at or aliases)[name] = _at
                g.name = name
                g.module = m
                g.parent = p
            end

            modules[mod.name] = mod
            if mod.commands then
                ---@param c command
                for _,c in pairs(mod.commands) do _cmd(c, mod, nil, aliases) end
            end

            if mod.groups then
                for k,g in pairs(mod.groups) do
                    _grp(g, mod, nil, nil, k)
                end
            end

            if mod.setup or mod.teardown then
                local senv = lwrap(mload)
                for _,u in pairs(mod.requires or {}) do
                    local util = utils[u]
                    senv[u] = util
                    for _,v in pairs(util.g or {}) do
                        senv[v] = util[v]
                    end
                end

                if mod.setup then senv(mod.setup)() end
                if mod.teardown then mod.teardown = senv(mod.teardown) end
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

-- in case any modules need randomness
math.randomseed(os.time())

-- setup signal handler to catch ctrl+c shutdown
do
    local uv = require("uv")
    local sig = uv.new_signal()
    uv.signal_start(sig, "sigint", function()
        print("Got SIGINT, shutting down...")
        for _,mod in pairs(modules) do
            if mod.teardown then
                print(mod.name .. " Module - Teardown...")
                mod.teardown()
            else
                print(mod.name .. " Module has no teardown.")
            end
        end
        os.exit()
    end)
end

-- actually run
do
    ---@param m Message
    client:on("messageCreate", function(m)
        local c = m.content
        if CASE_INSENSITIVE then
            if c:sub(1, LPREFIX):lower() ~= PREFIX:lower() then
                return
            end
        else
            if c:sub(1, LPREFIX) ~= PREFIX then
                return
            end
        end
        if c:sub(1, 2) == "~~" then return end
        c = c:sub(1 + LPREFIX)

        local env = lwrap(mload)

        setupenv(env, {
            ["_env"] = env,
            ["guild"] = m.guild,
            ["author"] = m.author,
            ["channel"] = m.channel,
            ["message"] = m,
            ["reply"] = function(v, ...)
                if select('#', ...) > 0 then
                    m:reply(string.format(v, ...))
                else
                    m:reply(v)
                end
            end
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
                :setColor(ECOLOR)
                :send(m)
        end

        if res.command.check then
            local v, err_msg = env(res.command.check)()
            if not v then
                Embed()
                    :setColor(ECOLOR)
                    :setTitle("Error")
                    :setDescription(err_msg)
                    :send(m)
                return
            end
        end

        if res.command.module.check then
            local v, err_msg = env(res.command.module.check)()
            if not v then
                Embed()
                    :setColor(ECOLOR)
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

    client:run("Bot "..config.token)
end
