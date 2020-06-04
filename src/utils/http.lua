local http = require("coro-http")
local gsub, format, byte, char = string.gsub, string.format, string.byte, string.char

-- mostly stolen from luvit source
do version = "a" end
---@class http
local mod = { id = "http", headers = {
    {"User-Agent", -- Luvit is the only one i haven't found how to not hardcode. Make a PR if you find an easy way.
            "discordbot-lua/"..version.." (+https://github.com/TechnoJo4/discordbot-lua) "..
            "coro-http/3.1.0 (Luvit/2.16.0; "..jit.version:gsub(" ", "/").."; ".._VERSION:gsub(" ", "/")..")"}
}, g = {"GET", "POST"} }

---@return string
---@param str string
function mod.decode(str)
    str = gsub(str, '+', ' ')
    str = gsub(str, '%%(%x%x)', function(h)
        return char(tonumber(h, 16))
    end)
    str = gsub(str, '\r\n', '\n')
    return str
end

---@return string
---@param str string
function mod.encode(str)
    if str then
        str = gsub(str, '\n', '\r\n')
        str = gsub(str, '([^%w-_.~])', function(c)
            return format('%%%02X', byte(c))
        end)
    end
    return str
end

---@param tbl table<string, string>
---@param url string | nil
function mod.qstr(tbl, url)
    local fields = {}
    for key, value in pairs(tbl) do
        local keyString = mod.encode(tostring(key)) .. "="
        if type(value) == "table" then
            for _, v in ipairs(value) do
                table.insert(fields, keyString .. mod.encode(tostring(v)))
            end
        else
            table.insert(fields, keyString .. mod.encode(tostring(value)))
        end
    end
    return (url and url.."?" or "")..table.concat(fields, "&")
end

---@param url string
---@param qstr table<string, string> | nil
---@param headers table<string, string> | nil
function mod.GET(url, qstr, headers)
    if qstr then
        url = (type(qstr) == "table") and mod.qstr() or (url.."?"..tostring(qstr))
    end
    return http.request("GET", url, headers or mod.headers)
end

---@param url string
---@param body string
---@param headers table<string, string> | nil
function mod.POST(url, body, headers)
    return http.request("POST", url, headers or mod.headers, body)
end

return mod