-- CONFIG

local GUILD = "332665699455729665" -- tachiyomi "349436576037732353"
local ROLE = "800068353820852265" -- tachiyomi "842766939675033600"

local SUGGESTION_PATTERN = "^https://anilist.co/manga/%d+/.-/"

-- END CONFIG

--[[ DOCUMENTATION

im too lazy to make a way to close the vote or whatever so just
shutdown the bot (use ~shutdown to make sure teardown happens
and results are saved) when you want to close voting for the week.
you can then read and process the results saved in votes.json

INITIALIZATION:
    1. create a "vote" folder alongside "src"
    2. create "votes.json", "voters.json", "suggestions.json" and "choices.json" inside
    3. follow reset instructions below

HOW TO RESET:
    resetting votes.json, voters.json, suggestions.json is just a matter
    of replacing the contents of the file with "{}" (an empty json object)


    choices.json has to be manually filled with contents in the format:
        {
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
        return false, "This command is reserved to members of the tachiyomi book club."
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
    local dt = os.date("!%m.%d.%H")
    write_json("../vote/votes.backup."..dt..".json", data_vote)
    write_json("../vote/voters.backup."..dt..".json", data_voters)
    write_json("../vote/suggestions.backup."..dt..".json", data_suggestions)
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
                data_vote[choice] = (data_vote[choice] or 0) + (1 / n)
            end

            reply("Successfully voted.")
        end
    } }
}
