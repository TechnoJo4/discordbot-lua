-- CONFIG

local GUILD = "332665699455729665" -- tachiyomi "349436576037732353"
local ROLE = "800068353820852265" -- tachiyomi "842766939675033600"
local ADMIN_ROLE = "800068353820852265" -- tachiyomi "842824047855403008"

local SUGGESTION_PATTERN = "^https://anilist.co/manga/%d+/.-/"

local AUTOMATE = true
local INFO_CHANNEL = "456261147864203276" -- tachiyomi "842823870288363560"
local AUTO_PING = "<@&800068353820852265>" -- tachiyomi "<@&842766939675033600>"
local COOLDOWN_LENGTH = 4

math.randomseed(os.time())

-- END CONFIG

--[[ DOCUMENTATION

NOTES:
    Use the shutdown command to shutdown the bot to make sure teardown
    happens and results are saved properly.

COMMANDS:
    Use the `help` command


    `admin open` - Open voting
    `admin close` - Close voting
    `admin s_open` - Open suggestions
    `admin s_close` - Close suggestions
    `admin save` - Save json data
    `admin reload` - Reload json data
    `admin votes` - Show vote points for entries
    `admin suggestions` - Show all user suggestions
    `admin remove_suggestion <user id>` - Remove a user's suggestion
    `admin suggestions2choices` - Create vote entries from user suggestions
    `admin set_name <entry id> <name>` - Set an entry's name
    `admin set_link <entry id> <link>` - Set an entry's link
    `admin send_json <name>` - Sends internal json. Use `admin save` beforehand to get up-to-date data. `<name>` can be one of: `votes`, `voters`, `suggestions`, `genres`, `choices`.

INITIALIZATION:
    1. create a "backup" folder inside "vote"
    2. if needed, follow reset instructions below

HOW TO RESET:
    votes.json and voters.json:
        {}

    suggestions.json:
        {"running":true}

    choices.json format:
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
local data_genres

local l_guild
local info_channel
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

local function has(tbl, v)
    for _,tv in pairs(tbl) do
        if v == tv then
            return true
        end
    end
    return false
end

-- create hourly backups (use in case of rigged voting or bad teardown)
local clock = discordia.Clock()
local function automation()
    if AUTOMATE then
        local dt = os.date("!*t")

        info_channel = info_channel or client:getChannel(INFO_CHANNEL)

        -- automate suggestions open/close, alongside with genre randomization
        local suggestions_open = (dt.wday == 6 and dt.hour >= 4 and dt.hour < 16)
        if data_suggestions.running ~= suggestions_open then
            if suggestions_open then
                -- cooldown check
                local genre
                repeat
                    genre = data_genres.genres[math.random(1, #data_genres.genres)]
                until not has(data_genres.in_cooldown, genre)

                -- add to cooldown list
                if #data_genres.in_cooldown >= COOLDOWN_LENGTH then
                    -- pop oldest in cooldown
                    for i=2,COOLDOWN_LENGTH do
                        data_genres.in_cooldown[i-1] = data_genres.in_cooldown[i]
                    end
                    data_genres.in_cooldown[COOLDOWN_LENGTH] = nil
                end

                data_genres.in_cooldown[#data_genres.in_cooldown+1] = genre

                -- send message
                Embed()
                    :setColor(COLOR)
                    :setTitle("Genre of the Week")
                    :setDescription("The chosen genre was: **%s**.\nSuggestions are now open.", genre)
                    :send(info_channel, AUTO_PING)

                -- write genres.json to save cooldown
                write_json("../vote/backup/genres.json", data_genres)
            else
                Embed()
                    :setColor(ECOLOR)
                    :setDescription("Suggestions are now closed.")
                    :send(info_channel)
            end

            -- actually close suggestions
            data_suggestions.running = suggestions_open
        end

        -- automate vote open/close
        local vote_open = (dt.wday == 6 and dt.hour >= 18) or (dt.wday == 7 and dt.hour < 18)
        if data_choices.running ~= vote_open then
            if vote_open then
                Embed()
                    :setColor(COLOR)
                    :setTitle("Vote of the Week")
                    :setDescription("Voting is now open.")
                    :send(info_channel, AUTO_PING)
            else
                Embed()
                    :setColor(ECOLOR)
                    :setDescription("Voting is now closed. The winning entry will be announced shortly.")
                    :send(info_channel)

                -- TODO: choose winner?
            end

            -- actually close voting
            data_choices.running = vote_open
        end
    end

    local dt = os.date("%m-%d.%H")
    write_json("../vote/backup/votes."..dt..".json", data_vote)
    write_json("../vote/backup/voters."..dt..".json", data_voters)
    write_json("../vote/backup/suggestions."..dt..".json", data_suggestions)
end
clock:on("hour", automation)
clock:start(true)



local help_messages do
    local function topic(name)
        return Embed()
            :setColor(COLOR)
            :setTitle("Help - "..name)
    end

    help_messages = {
        base = topic("Commands")
            :setDescription([[
__How to suggest__

    `bc suggest <AniList Link>`

__How to vote__

    `bc choices`
    `bc vote 2 6 4`

    The above would vote for, in order of priority, entry `2`, followed by entry `6` and then entry `4`.

    You are __not__ limited to any specific amount of votes, but each entry after the first will receive half the amount of points of the previous.

__More Help__

    Send `bc help weighting` for more detailed information about how entries get points based on your votes.
    Send `bc help admin` to know about commands available to Book Club Leaders.
]]):build(),
        admin = topic("Leader Commands")
            :setDescription([[
TODO
]]):build(),
        weighting = topic("Vote Weigthing")
            :setDescription([[
TODO
]]):build(),
    }
end

local help_alias = {
    ["default"] = "base", ["commands"] = "base",
    ["leader"] = "admin",
    ["weight"] = "weighting", ["weights"] = "weighting",
    ["points"] = "weighting", ["formula"] = "weighting",
    ["borda"] = "weighting", ["count"] = "weighting", ["counting"] = "weighting",
}
for k,_ in pairs(help_messages) do
    help_alias[k] = k
end

return {
    name = "Vote",
    emoji = "🗳️",
    requires = { "json" },
    setup = function()
        local env = getfenv()
        setfenv(automation, env)
        setfenv(read_json, env)
        setfenv(write_json, env)

        data_vote = read_json("../vote/votes.json")
        data_voters = read_json("../vote/voters.json")
        data_genres = read_json("../vote/genres.json")
        data_choices = read_json("../vote/choices.json")
        data_suggestions = read_json("../vote/suggestions.json")
    end,
    teardown = function()
        write_json("../vote/votes.json", data_vote)
        write_json("../vote/voters.json", data_voters)
        write_json("../vote/genres.json", data_genres)
        write_json("../vote/choices.json", data_choices)
        write_json("../vote/suggestions.json", data_suggestions)
    end,
    commands = { {
        ["name"] = "choices",
        ["check"] = CHECK,
        ["aliases"] = { "entries" }, ["args"] = {},
        ["function"] = function()
            if not data_choices.running then
                Embed()
                    :setColor(ECOLOR)
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
        ["name"] = "help",
        ["check"] = CHECK,
        ["aliases"] = {}, ["args"] = {
            { name = "topic", type = "string?" }
        },
        ["function"] = function()
            local topic_name = help_alias[topic or "base"]
            if not topic_name then
                Embed()
                    :setColor(ECOLOR)
                    :setTitle("Error")
                    :setDescription("`%s` is not a help topic.\nSend `bc help` to get help.")
                    :send(m)
                return
            end

            reply(help_messages[topic_name])
        end
    }, {
        ["name"] = "suggest",
        ["check"] = CHECK,
        ["aliases"] = {}, ["args"] = {
            { name = "link", type = "+" }
        },
        ["function"] = function()
            if not data_suggestions.running then
                Embed()
                    :setColor(ECOLOR)
                    :setTitle("Error")
                    :setDescription("Suggestions are currently closed.")
                    :send(m)
                return
            end

            local old = data_suggestions[u.id]

            if #link >= 3 and link:sub(1,1) == "<" and link:sub(-1,-1) == ">" then
                link = link:sub(2,-2)
            end

            if not link:match(SUGGESTION_PATTERN) then
                Embed()
                    :setColor(ECOLOR)
                    :setTitle("Error")
                    :setDescription("Your suggestion must be a valid AniList link.\n"
                                .. "Format: `https://anilist.co/manga/[id]/[name]/`")
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
                    :setColor(ECOLOR)
                    :setTitle("Error")
                    :setDescription("Voting is currently closed.")
                    :send(m)
                return
            end

            if data_voters[u.id] then
                Embed()
                    :setColor(ECOLOR)
                    :setTitle("Error")
                    :setDescription("You have already voted this week.")
                    :send(m)
                return
            end

            if #choices < 1 then
                Embed()
                    :setColor(ECOLOR)
                    :setTitle("Error")
                    :setDescription("You must vote for at least one entries.")
                    :send(m)
                return
            end

            local dedup = {}
            for _,v in ipairs(choices) do
                if dedup[v] then
                    Embed()
                        :setColor(ECOLOR)
                        :setTitle("Error")
                        :setDescription("Duplicate choice `%d`.", v)
                        :send(m)
                    return
                end
                dedup[v] = true
            end

            for _,num in ipairs(choices) do
                if not data_vote[num] then
                    Embed()
                        :setColor(ECOLOR)
                        :setTitle("Error")
                        :setDescription("Invalid choice: entry `%d` does not exist.", num)
                        :send(m)
                    return
                end
            end

            data_voters[user.id] = true

            local str = {}
            for n,choice in ipairs(choices) do
                local value = (0.5 ^ (n - 5))
                data_vote[choice] = data_vote[choice] + value
                str[n] = (" - %s, giving it `%g points` \n"):format(data_choices.names[choice], value)
            end

            reply("Successfully voted for:\n%s", table.concat(str))
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
                    if k ~= "running" then
                        str[i] = "<"..v.."> (suggested by user `"..k.."`)"
                        i = i + 1
                    end
                end

                reply(table.concat(str, "\n"))
            end
        }, {
            ["name"] = "help",
            ["check"] = ADMIN_CHECK,
            ["aliases"] = {}, ["args"] = {},
            ["function"] = function()
                reply(help_messages.admin)
            end
        }, {
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
                    str[i] = ("<%s> (`%d %s`) - %.2f points"):format(data_choices.links[v.i], v.i, data_choices.names[v.i], v.votes)
                end

                reply(table.concat(str, "\n"))
            end
        }, {
            ["name"] = "top",
            ["check"] = ADMIN_CHECK,
            ["aliases"] = { "winner" }, ["args"] = {},
            ["function"] = function()
                local sorted = {}
                for i,v in pairs(data_vote) do
                    sorted[i] = { i = i, votes = v }
                end
                table.sort(sorted, function(a, b)
                    return a.votes > b.votes
                end)

                local diff = sorted[2].votes - sorted[1].votes
                if diff < 0.05 then
                    reply("Tie (or close). Top 2 are %f points apart.", diff)
                else
                    local v = sorted[1]
                    reply("<%s> (`%d %s`) is currently leading with %.2f points.", data_choices.links[v.i], v.i, data_choices.names[v.i], v.votes)
                end
            end
        }, {
            ["name"] = "remove_suggestion",
            ["check"] = ADMIN_CHECK,
            ["aliases"] = {}, ["args"] = {
                { name = "targets", type = "string+" }
            },
            ["function"] = function()
                for _,v in pairs(targets) do
                    data_suggestions[v] = nil
                end
                reply("Success.")
            end
        }, {
            ["name"] = "suggestions2choices",
            ["check"] = ADMIN_CHECK,
            ["aliases"] = {}, ["args"] = {},
            ["function"] = function()
                local names, links = {}, {}

                for k,link in pairs(data_suggestions) do
                    if k ~= "running" then
                        local dup = false
                        for _,v in ipairs(links) do
                            if link == v then
                                dup = true
                                break
                            end
                        end

                        if not dup then
                            local name = link:match("^https://anilist.co/manga/%d+/(.-)/")
                            links[#links+1] = link
                            names[#names+1] = name:gsub("-", " ")
                        end
                    end
                end

                reply("```json\n%s\n```", json.encode(data_choices))

                data_choices.names = names
                data_choices.links = links

                -- reset votes
                data_vote = {}
                for i=1,#names do
                    data_vote[i] = 0
                end

                data_voters = {}

                -- save
                write_json("../vote/votes.json", data_vote)
                write_json("../vote/voters.json", data_voters)
                write_json("../vote/choices.json", data_choices)
            end
        }, {
            ["name"] = "reset_votes",
            ["check"] = ADMIN_CHECK,
            ["aliases"] = {}, ["args"] = {},
            ["function"] = function()
                data_vote = {}
                for i=1,#data_choices.names do
                    data_vote[i] = 0
                end
                reply("Success.")
            end
        }, {
            ["name"] = "reset_suggestions",
            ["check"] = ADMIN_CHECK,
            ["aliases"] = {}, ["args"] = {},
            ["function"] = function()
                data_suggestions = {
                    running = data_suggestions.running
                }
                reply("Success.")
            end
        }, {
            ["name"] = "set_link",
            ["check"] = ADMIN_CHECK,
            ["aliases"] = {}, ["args"] = {
                { name = "idx", type = "int" },
                { name = "link", type = "string" }
            },
            ["function"] = function()
                data_choices.links[idx] = link
                reply("Success.")
            end
        }, {
            ["name"] = "set_name",
            ["check"] = ADMIN_CHECK,
            ["aliases"] = {}, ["args"] = {
                { name = "idx", type = "int" },
                { name = "name", type = "string" }
            },
            ["function"] = function()
                data_choices.names[idx] = name
                reply("Success.")
            end
        }, {
            ["name"] = "reload",
            ["check"] = ADMIN_CHECK,
            ["aliases"] = {}, ["args"] = {},
            ["function"] = function()
                data_vote = read_json("../vote/votes.json")
                data_voters = read_json("../vote/voters.json")
                data_genres = read_json("../vote/genres.json")
                data_choices = read_json("../vote/choices.json")
                data_suggestions = read_json("../vote/suggestions.json")
                reply("Success.")
            end
        }, {
            ["name"] = "save",
            ["check"] = ADMIN_CHECK,
            ["aliases"] = {}, ["args"] = {},
            ["function"] = function()
                write_json("../vote/votes.json", data_vote)
                write_json("../vote/voters.json", data_voters)
                write_json("../vote/genres.json", data_genres)
                write_json("../vote/choices.json", data_choices)
                write_json("../vote/suggestions.json", data_suggestions)
                reply("Success.")
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
            ["aliases"] = { "stop" }, ["args"] = {},
            ["function"] = function()
                data_choices.running = false
                reply("Voting now closed.")
            end
        }, {
            ["name"] = "s_open",
            ["check"] = ADMIN_CHECK,
            ["aliases"] = { "s_start" }, ["args"] = {},
            ["function"] = function()
                data_suggestions.running = true
                reply("Suggestions now open.")
            end
        }, {
            ["name"] = "s_close",
            ["check"] = ADMIN_CHECK,
            ["aliases"] = { "s_stop" }, ["args"] = {},
            ["function"] = function()
                data_suggestions.running = false
                reply("Suggestions now closed.")
            end
        }, {
            ["name"] = "send_json",
            ["check"] = ADMIN_CHECK,
            ["aliases"] = {}, ["args"] = {
                { name = "name", type = "string" }
            },
            ["function"] = function()
                reply("```json\n%s\n```", fs.readFileSync(("../vote/%s.json"):format(name)))
            end
        } }
    }
}
