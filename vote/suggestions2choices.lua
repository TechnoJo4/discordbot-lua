-- luvit ./suggestions2choices.lua

local fs = require("fs")
local json = require("json")

local suggestions = json.parse(fs.readFileSync("./suggestions.json"))
local names, links = {}, {}

for _,link in pairs(suggestions) do
    local name = link:match("^https://anilist.co/manga/%d+/(.-)/")
    links[#links+1] = link
    names[#names+1] = name:gsub("-", " ")
end

fs.writeFileSync("choices.json", json.encode({ running = true, names = names, links = links }))
