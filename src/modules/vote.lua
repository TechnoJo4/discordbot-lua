-- CONFIG

local GUILD = "332665699455729665" -- tachiyomi "349436576037732353"
local ROLE = "800068353820852265" -- tachiyomi "842766939675033600"
local ADMIN_ROLE = "800068353820852265" -- tachiyomi "842824047855403008"

local SUGGESTION_PATTERN = "^https://anilist.co/manga/%d+/.-/"

-- END CONFIG

--[[ DOCUMENTATION

im too lazy to make a way to close the vote or whatever so just
shutdown the bot (use ~shutdown to make sure teardown happens
and results are saved) when you want to close voting for the week.
you can then read and process the results saved in votes.json

INITIALIZATION:
    1. create a "vote" folder alongside "src"
    2. create a "backup" folder inside "vote"
    3. create "votes.json", "voters.json", "suggestions.json" and "choices.json" inside
    4. follow reset instructions below

HOW TO RESET:
    resetting votes.json, voters.json, suggestions.json is just a matter
    of replacing the contents of the file with "{}" (an empty json object)


    choices.json has to be manually filled with contents in the format:
        {
            "running": true,
            "names": [
                "name1",
                "name2",
                "..."
            ],
            "links": [
                "https://anilist.co/for/name1",
                "https://anilist.co/for/name2",
                "..."
            ]
        }

    (the names and links arrays must be the same length)

POSSIBLE WEIGHTING ADJUSTEMENTS:

    Default: (0.5 ^ (n - 1))
    Result: 1, 0.5, 0.25, 0.125, ...

    To favor choices 3+ more, (1 / n) can be used.
    Result: 1, 0.5, 0.33333, 0.25, ...

    To give more weight to the first choice and less to everything
    afterwards, the default may be used with a lower value instead of 0.5

    Example: ((1/3) ^ (n - 1))
    Result: 1, 0.33333, 0.11111, 0.037037, ...

    Similarly, you can give more weight to choices 2+ by using a higher
    constant than 0.5 in the default formula.

    Example: (0.8 ^ (n - 1))
    Result: 1, 0.8, 0.64, 0.521, 0.4096, ...

--]]

local data_vote
local data_voters
local data_choices
local data_suggestions

local l_guild
local function CHECK()
    if guild then
        return false, "This command can only be used in DMs."
    end

    -- lazy load guild
    l_guild = l_guild or client:getGuild(GUILD)

    -- verify member/role
    local member = l_guild:getMember(user)
    if not member or not member:hasRole(ROLE) then
        return false, "This command is reserved to members of the Tachiyomi Book Club."
    end

    return true
end

local function ADMIN_CHECK()
    -- lazy load guild
    l_guild = l_guild or client:getGuild(GUILD)

    -- verify member/role
    local member = l_guild:getMember(user)
    if not member or not member:hasRole(ADMIN_ROLE) then
        return false, "This command is reserved to administators of the Tachiyomi Book Club."
    end

    return true
end

local fs = require("fs")

local function read_json(file)
    return json.parse(fs.readFileSync(file))
end
local function write_json(file, data)
    return fs.writeFileSync(file, json.encode(data))
end

local choices_text

-- create hourly backups (use in case of rigged voting or bad teardown)
local clock = discordia.Clock()
local function backup()
    local dt = os.date("%m-%d.%H")
    write_json("../vote/backup/votes."..dt..".json", data_vote)
    write_json("../vote/backup/voters."..dt..".json", data_voters)
    write_json("../vote/backup/suggestions."..dt..".json", data_suggestions)
end
clock:on("hour", backup)
clock:start(true)

return {
    name = "Vote",
    emoji = "🗳️",
    requires = { "json" },
    setup = function()
        local env = getfenv()
        setfenv(backup, env)
        setfenv(read_json, env)
        setfenv(write_json, env)
        data_vote = read_json("../vote/votes.json")
        data_voters = read_json("../vote/voters.json")
        data_choices = read_json("../vote/choices.json")
        data_suggestions = read_json("../vote/suggestions.json")
    end,
    teardown = function()
        write_json("../vote/votes.json", data_vote)
        write_json("../vote/voters.json", data_voters)
        write_json("../vote/suggestions.json", data_suggestions)
    end,
    commands = { {
        ["name"] = "choices",
        ["check"] = CHECK,
        ["aliases"] = { "entries" }, ["args"] = {},
        ["function"] = function()
            if not data_choices.running then
                Embed()
                    :setColor(0xFF0000)
                    :setTitle("Error")
                    :setDescription("Voting is currently closed.")
                    :send(m)
                return
            end

            if not choices_text then
                local amm = #data_choices.names
                local len = #tostring(amm) + 1

                local str = {}
                for i=1,amm do
                    local s = tostring(i)
                    local n = data_choices.names[i]
                    str[i] = "`" .. s .. (" "):rep(len - #s) .. n .. "` <" .. data_choices.links[i] .. ">"
                end

                choices_text = table.concat(str, "\n")
            end

            reply(choices_text)
        end
    }, {
        ["name"] = "suggest",
        ["check"] = CHECK,
        ["aliases"] = {}, ["args"] = {
            { name = "link", type = "+" }
        },
        ["function"] = function()
            local old = data_suggestions[u.id]

            if not link:match(SUGGESTION_PATTERN) then
                Embed()
                    :setColor(0xFF0000)
                    :setTitle("Error")
                    :setDescription("You suggestion must be a valid AniList link.")
                    :send(m)
                return
            end

            data_suggestions[u.id] = link
            if old then
                reply("Modified your suggestion from <%s> to <%s>.", old, link)
            else
                reply("Added suggestion <%s>.", link)
            end
        end
    }, {
        ["name"] = "vote",
        ["check"] = CHECK,
        ["aliases"] = {}, ["args"] = {
            { name = "choices", type = "int+" },
        },
        ["function"] = function()
            if not data_choices.running then
                Embed()
                    :setColor(0xFF0000)
                    :setTitle("Error")
                    :setDescription("Voting is currently closed.")
                    :send(m)
                return
            end

            if data_voters[u.id] then
                Embed()
                    :setColor(0xFF0000)
                    :setTitle("Error")
                    :setDescription("You have already voted this week.")
                    :send(m)
                return
            end

            if #choices < 1 then
                Embed()
                    :setColor(0xFF0000)
                    :setTitle("Error")
                    :setDescription("You must vote for at least one entries.")
                    :send(m)
                return
            end

            local dedup = {}
            for _,v in ipairs(choices) do
                if dedup[v] then
                    Embed()
                        :setColor(0xFF0000)
                        :setTitle("Error")
                        :setDescription("Duplicate choice `%d`.", v)
                        :send(m)
                    return
                end
                dedup[v] = true
            end

            for _,num in ipairs(choices) do
                if not data_choices.names[num] then
                    Embed()
                        :setColor(0xFF0000)
                        :setTitle("Error")
                        :setDescription("Invalid choice: entry `%d` does not exist.", num)
                        :send(m)
                    return
                end
            end

            data_voters[user.id] = true

            for n,choice in ipairs(choices) do
                data_vote[choice] = (data_vote[choice] or 0) + (0.5 ^ (n - 1))
            end

            reply("Successfully voted.")
        end
    } },
    groups = {
        admin = { {
            ["name"] = "suggestions",
            ["check"] = ADMIN_CHECK,
            ["aliases"] = {}, ["args"] = {},
            ["function"] = function()
                local i = 1
                local str = {}
                for k,v in pairs(data_suggestions) do
                    str[i] = "<"..v.."> (suggested by user `"..k.."`)"
                    i = i + 1
                end

                reply(table.concat(str, "\n"))
            end
        },{
            ["name"] = "votes",
            ["check"] = ADMIN_CHECK,
            ["aliases"] = { "show" }, ["args"] = {},
            ["function"] = function()
                local sorted = {}
                for i,v in pairs(data_vote) do
                    sorted[i] = { i = i, votes = v }
                end
                table.sort(sorted, function(a, b)
                    return a.votes > b.votes
                end)

                local str = {}
                for i,v in pairs(sorted) do
                    str[i] = ("<%s> (`%d %s`) - %d points"):format(data_choices.links[v.i], v.i, data_choices.names[v.i], v.votes)
                end

                reply(table.concat(str, "\n"))
            end
        }, {
            ["name"] = "open",
            ["check"] = ADMIN_CHECK,
            ["aliases"] = { "start" }, ["args"] = {},
            ["function"] = function()
                data_choices.running = true
                reply("Voting now open.")
            end
        }, {
            ["name"] = "close",
            ["check"] = ADMIN_CHECK,
            ["aliases"] = { "end" }, ["args"] = {},
            ["function"] = function()
                data_choices.running = false
                reply("Voting now closed.")
            end
        } }
    }
}
