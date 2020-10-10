local users = {}
local games = {}
local cache = {}
local currencies = {}

local ctime = os.clock

-- yahoo finance API
local base_url = "https://query1.finance.yahoo.com/v7/finance/quote"

local function req(symbols, fields)
    local res, body = http.GET(base_url, { format = "json", fields = fields, symbols = symbols })
    return json.parse(body).quoteResponse
end

local function equity(ticker)
    ticker = ticker:upper()
    if ticker:gsub(".", function(c)
        return ((c >= 'A' and c <= 'Z') or (c >= '0' and c <= '9') or (c == '.')) and "" or c
    end) ~= "" then return nil, "Please only enter valid alphanumeric characters." end
    if cache[ticker] then
        if cache[ticker].error then
            return nil, "Not a valid stock ticker."
        elseif cache[ticker].ctime > ctime()-300 then
            return cache[ticker]
        end
    end

    local res = req(ticker, "symbol,regularMarketPrice,shortName,longName,marketState,currency")
    if res.error or not res.result then
        return nil, "Internal bot or API error."
    end

    local r = res.result[1]
    if #res.result == 0 or res.result[1].quoteType ~= "EQUITY" then
        cache[ticker] = { error = true }
        return nil, "Not a valid stock ticker."
    end
    r.ctime = ctime()
    cache[ticker] = r

    return r
end

-- this assumes all input is valid & alive stock tickers
local function batch_equity(tickers)
    if #tickers == 0 then return {} end

    local get = {}
    local data = {}

    -- get what we can from cache
    for _,ticker in pairs(tickers) do
        if not data[ticker] then
            if cache[ticker] and cache[ticker].ctime > ctime()-300 then
                data[ticker] = cache[ticker]
            else
                get[#get+1] = ticker
                data[ticker] = true -- placeholder value for deduplication
            end
        end
    end

    if #get == 0 then return data end

    -- request the others
    local res = req(table.concat(get, ","), "symbol,regularMarketPrice,shortName,longName,marketState,currency")
    if res.error or not res.result then
        return nil, "Internal bot or API error."
    end

    -- data thing & cache the requested tickers
    for _, v in pairs(res.result) do
        v.ctime = ctime()
        data[v.symbol] = v
        cache[v.symbol] = v
    end

    -- remove errors
    for k, v in pairs(data) do
        if v == true then
            data[k] = nil
        end
    end

    return data
end

local function currency(symbol)
    symbol = symbol:upper()
    if symbol:gsub(".", function(c)
        return ((c >= 'A' and c <= 'Z') or (c >= '0' and c <= '9') or (c == '.')) and "" or c
    end) ~= "" then return nil, "Please only enter valid alphanumeric characters." end
    if currencies[symbol] then
        if currencies[symbol].error then
            return nil, "Not a valid currency."
        elseif currencies[symbol].ctime > ctime()-300 then
            return currencies[symbol]
        end
    end

    local res = req(symbol.."=X", "bid,ask,shortName")
    if res.error or not res.result then
        return nil, "Internal bot or API error."
    end

    local r = res.result[1]
    if #res.result == 0 or r.quoteType ~= "CURRENCY" then
        currencies[symbol] = { error = true }
        return nil, "Not a valid currency."
    end
    r.ctime = ctime()
    currencies[symbol] = r

    return r
end

-- create backups
local clock = discordia.Clock()
local function backup()
    db.tofile("../db/stock.users.bak.db", users)
    db.tofile("../db/stock.games.bak.db", games)
end
clock:on("hour", backup)
clock:start(true)


return {
    name = "Stocks Game",
    emoji = "📈",
    requires = { "http", "json", "db" },
    setup = function()
        users = db.fromfile("../db/stock.users.db")
        games = db.fromfile("../db/stock.games.db")

        local env = getfenv()
        setfenv(req, env)
        setfenv(backup, env)
    end,
    teardown = function()
        db.tofile("../db/stock.users.db", users)
        db.tofile("../db/stock.games.db", games)
    end,
    groups = {
        stocks = { {
            ["name"] = "new_game",
            ["aliases"] = {}, ["args"] = {
                { name = "name", type = "string" },
                { name = "join_key", type = "string" },
                { name = "start_bal", type = "number" },
                { name = "privacy", type = "boolean" },
            },
            ["check"] = function()
                return (u == client.owner), "⁉️ This command can only be used by `"..client.owner.tag.."` ("..client.owner.id..")."
            end,
            ["function"] = function()
                games[name] = {
                    join_key = join_key,
                    start_bal = start_bal,
                    privacy = privacy,
                    users = {}
                }

                reply("Successfully created/reset game.")
            end
        }, {
            ["name"] = "join_game",
            ["aliases"] = { "join" }, ["args"] = { { name = "key", type = "string" } },
            ["function"] = function()
                local id = author.id
                for name,game in pairs(games) do
                    if game.join_key == key then
                        if game.users[id] then
                            reply(("You've already joined game *%s*!"):format(name))
                        else
                            game.users[id] = {
                                stocks = {},
                                history = {},
                                balance = game.start_bal
                            }

                            if users[id] then
                                local u = users[id]
                                u[#u+1] = name
                            else
                                users[id] = { name, current = name }
                            end

                            reply(("Successfully joined game *%s*."):format(name))
                        end
                    return end
                end

                reply("Could not find a game with that join code.")
            end
        }, {
            ["name"] = "force_join",
            ["aliases"] = {}, ["args"] = {
                { name = "name", type = "string" },
                { name = "fuser", type = "user" }
            },
            ["check"] = function()
                return (u == client.owner), "⁉️ This command can only be used by `"..client.owner.tag.."` ("..client.owner.id..")."
            end,
            ["function"] = function()
                local id = fuser.id

                local game = games[name]
                game.users[id] = {
                    stocks = {},
                    history = {},
                    balance = game.start_bal
                }

                if users[id] then
                    local u = users[id]
                    u[#u+1] = name
                else
                    users[id] = { name, current = name }
                end

                reply("Success.")
            end
        }, {
            ["name"] = "set_game",
            ["aliases"] = { "game", "g" }, ["args"] = { { name = "name", type = "string" } },
            ["function"] = function()
                for _,v in ipairs(users[author.id] or {}) do
                    if v:lower() == name:lower() then
                        users[author.id].current = name
                        reply(("Successfully set your current game to *%s*."):format(name))
                    return end
                end
                reply(("Could not find game *%s*."):format(name))
            end
        }, {
            ["name"] = "buy",
            ["aliases"] = { "b" }, ["args"] = { { name = "ticker", type = "string" }, { name = "amount", type = "int" } },
            ["function"] = function()
                if not users[author.id] or not users[author.id].current then
                    reply("You aren't playing in a stocks games.\nJoin a game or, "
                        .."if you already have, try using the `set_game` command.")
                return end

                local user = users[author.id]
                local game = games[user.current]
                local guser = game.users[author.id]
                if not game then
                    reply("Invalid context game. Try using the `set_game` command.")
                return end

                -- i doubt it's reasonable to ever want to buy a billion stocks anyways,
                -- and this prevents a smart person from entering 1e309 and breaking the whole bot or something
                if amount < 1 or amount > 1e11 then
                    reply("Please enter a valid amount of stocks.")
                return end

                local stock, err = equity(ticker)
                if err then reply(("Error: %s"):format(err)) return end

                local cur
                local price = stock.regularMarketPrice
                local usd_price = price
                if stock.currency ~= "USD" then
                    cur = currency(stock.currency)
                    usd_price = price / cur.bid
                end
                local total = price * amount
                local usd_total = usd_price * amount

                local symbol = stock.symbol

                -- check if user can buy
                if guser.balance < usd_total then
                    reply(("You don't have enough money to buy __%d__ stocks of **%s** (%s: %s)\n"
                        .. "It would cost %.2f USD, which is %.2f USD more than your current balance.")
                            :format(amount, stock.longName, stock.exchange, symbol, usd_total, usd_total - guser.balance))
                return else
                    guser.stocks[symbol] = (guser.stocks[symbol] or 0) + amount
                    guser.balance = guser.balance - usd_total
                end

                local price_str = ("%.2f %s"):format(price, stock.currency)
                if cur then
                    price_str = price_str .. (" / %.2f USD"):format(usd_price)
                end

                local total_str = amount == 1 and "" or (
                    stock.currency == "USD" and ("; Total: %.2f USD"):format(usd_total)
                    or ("; Total: %.2f %s / %.2f USD"):format(total, stock.currency, usd_total)
                )

                reply(("Bought __%d__ stocks of **%s** (%s: %s) @ %s%s")
                        :format(amount, stock.longName, stock.exchange, symbol, price_str, total_str))
            end
        }, {
            ["name"] = "sell",
            ["aliases"] = { "s" }, ["args"] = { { name = "ticker", type = "string" }, { name = "amount", type = "int" } },
            ["function"] = function()
                if not users[author.id] or not users[author.id].current then
                    reply("You aren't playing in a stocks games.\nJoin a game or, "
                        .."if you already have, try using the `set_game` command.")
                return end

                local user = users[author.id]
                local game = games[user.current]
                local guser = game.users[author.id]
                if not game then
                    reply("Invalid context game. Try using the `set_game` command.")
                return end

                if amount < 1 or amount > 1e11 then
                    reply("Please enter a valid amount of stocks.")
                return end

                ticker = ticker:upper()
                if not guser.stocks[ticker] then
                    reply(("You don't have any **%s** stocks to sell."):format(ticker))
                elseif guser.stocks[ticker] < amount then
                    reply(("You don't have enough **%s** stocks to sell %d. You only have %d.")
                            :format(ticker, amount, guser.stocks[ticker]))
                end

                local stock, err = equity(ticker)
                if err then reply(("Error: %s"):format(err)) end

                local cur
                local price = stock.regularMarketPrice
                local usd_price = price
                if stock.currency ~= "USD" then
                    cur = currency(stock.currency)
                    usd_price = price / cur.ask
                end
                local total = price * amount
                local usd_total = usd_price * amount

                local symbol = stock.symbol

                -- remove stocks and add money to balance
                guser.balance = guser.balance + usd_total
                guser.stocks[symbol] = guser.stocks[symbol] - amount
                if guser.stocks[symbol] < 1 then guser.stocks[symbol] = nil end

                local price_str = ("%.2f %s"):format(price, stock.currency)
                if cur then
                    price_str = price_str .. (" / %.2f USD"):format(usd_price)
                end

                local total_str = amount == 1 and "" or (
                    stock.currency == "USD" and ("; Total: %.2f USD"):format(usd_total)
                    or ("; Total: %.2f %s / %.2f USD"):format(total, stock.currency, usd_total)
                )

                reply(("Sold __%d__ stocks of **%s** (%s: %s) @ %s%s")
                        :format(amount, stock.longName, stock.exchange, symbol, price_str, total_str))
            end
        }, {
            ["name"] = "balance",
            ["aliases"] = { "bal" }, ["args"] = { { name = "buser", type = "user?" } },
            ["function"] = function()
                buser = buser or author
                local id = buser.id
                if not users[id] or #users[id] == 0 then
                    reply(("User %s is not currently playing the stocks game."):format(buser.name))
                return end
                local user = users[id]
                local tickers = {}
                local ugames = {}

                for _,v in ipairs(user) do
                    if not games[v].privacy then
                        local u = games[v].users[id]
                        ugames[v] = u
                        for stock,_ in pairs(u.stocks) do
                            tickers[stock] = true
                        end
                    end
                end

                do
                    local t = {}
                    for k,_ in pairs(tickers) do t[#t+1] = k end
                    tickers = t
                end

                tickers = batch_equity(tickers)

                local strs = { ("Inventory for user %s:"):format(buser.name) }
                for name,game in pairs(ugames) do
                    local str = ("\n__Game: **%s**__\n"):format(name)
                    local total = {}
                    local s = {}
                    local k = {}
                    for stock,amount in pairs(game.stocks) do
                        local t = tickers[stock]
                        local p = t.regularMarketPrice
                        local curr = t.currency
                        total[curr] = (total[curr] or 0) + p * amount
                        k[#k+1] = t.symbol
                        s[t.symbol] = ("`%s` (%s) %dx @ %.2f %s (Total: %.2f %s)\n")
                                :format(t.symbol, t.longName, amount, p, curr, p * amount, curr)
                    end
                    table.sort(k, function(a, b)
                        return tickers[a].regularMarketPrice * game.stocks[a] > tickers[b].regularMarketPrice * game.stocks[b]
                    end)
                    for _,key in ipairs(k) do str = str .. s[key] end

                    local total2 = {}
                    for curr, t in pairs(total) do
                        total2[#total2+1] = ("%.2f %s"):format(t, curr)
                    end
                    str = str..("\nMonetary balance: %.2f USD\nTotal stocks value: %s\n")
                                :format(game.balance, table.concat(total2, "; "))
                    strs[#strs+1] = str
                end

                local str = table.concat(strs, "\n")
                if #str < 2000 then
                    reply(str)
                else
                    reply("Your balance is too big to show. Try selling some of the stocks you remember.")
                end
            end
        }, {
            ["name"] = "log",
            ["aliases"] = { "history", "l", "h" }, ["args"] = { { name = "luser", type = "user?" } },
            ["function"] = function()
                -- TODO
                reply("Not yet implemented! Try again later.")
            end
        }, aliases = { "s" } }
    }
}
