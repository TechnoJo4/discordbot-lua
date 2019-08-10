-- DO:
-- luvit ./emmy/gen.lua
-- DON'T:
-- cd emmy & luvit ./gen.lua

-- basically modified docgen copied straight from discordia source
-- i don't know if i have to say i didn't make this and give credit or whatever
-- i don't annotate THIS cause it would interfere with real code, but i could've

local fs = require('fs')
local pathjoin = require('pathjoin')

local insert, sort, concat = table.insert, table.sort, table.concat
local format = string.format
local pathJoin = pathjoin.pathJoin

local function scan(dir)
	for fileName, fileType in fs.scandirSync(dir) do
		local path = pathJoin(dir, fileName)
		if fileType == "file" then
			coroutine.yield(path)
		else
			scan(path)
		end
	end
end

local function checkType(docstring, token)
	return docstring:find(token) == 1
end

local function match(s, pattern) -- only useful for one return value
	return assert(s:match(pattern), s)
end

local docs = {}

for f in coroutine.wrap(function() scan("./deps/discordia/libs") end) do
	local d = assert(fs.readFileSync(f))

	local class = {
		methods = {},
		statics = {},
		properties = {},
		parents = {},
	}

	for s in d:gmatch('--%[=%[%s*(.-)%s*%]=%]') do
        if checkType(s, '@i?c') then

			class.name = match(s, '@i?c (%w+)')
			class.userInitialized = checkType(s, '@ic')
			for parent in s:gmatch('x (%w+)') do
				insert(class.parents, parent)
			end
			class.desc = match(s, '@d (.+)'):gsub('\r?\n', ' ')
			class.parameters = {}
			for optional, paramName, paramType in s:gmatch('@(o?)p ([%w%p]+)%s+([%w%p]+)') do
				insert(class.parameters, {paramName, paramType, optional == 'o'})
			end

		elseif checkType(s, '@s?m') then

			local method = {parameters = {}}
			method.name = match(s, '@s?m ([%w%p]+)')
			for optional, paramName, paramType in s:gmatch('@(o?)p ([%w%p]+)%s+([%w%p]+)') do
				insert(method.parameters, {paramName, paramType, optional == 'o'})
            end
            local returnTypes = {}
            for retType in s:gmatch('@r ([%w%p]+)') do
                insert(returnTypes, retType)
            end
			method.returnTypes = returnTypes
			method.desc = match(s, '@d (.+)'):gsub('\r?\n', ' ')
			insert(checkType(s, '@sm') and class.statics or class.methods, method)

		elseif checkType(s, '@p') then

			local propertyName, propertyType, propertyDesc = s:match('@p (%w+)%s+([%w%p]+)%s+(.+)')
			assert(propertyName, s); assert(propertyType, s); assert(propertyDesc, s)
			propertyDesc = propertyDesc:gsub('\r?\n', ' ')
			insert(class.properties, {
				name = propertyName,
				type = propertyType,
				desc = propertyDesc,
			})

		end
	end

	if class.name then
		docs[class.name] = class
	end
end

---@param str string
local function types(str)
    if str == "*" then return "any" end

    if str:find("Resolvable") or str:find("Resolvables") then
        local s = str:find("ID")
        if s then return "string|"..str:sub(1,s-2) end
        s = str:find("Base64")
        if s then return "string|\"data\"" end

        local _,e = str:find("Permissions") or str:find("Color")
        if e then return "number|"..str:sub(1,e) end

        s = str:find("Permission")
        if s then return "number|Permissions" end

        return str:sub(1, select(1, str:find("Resolvable")))
    end

    local ret = {}
	for t in str:gmatch('[^/]+') do
		insert(ret, t)
    end
	return concat(ret, '|')
end

local function sorter(a, b)
	return a.name < b.name
end

local function writeProperties(f, properties)
	sort(properties, sorter)
    for _, v in ipairs(properties) do
        -- the public thing is fix for GuildChannel#private
		f:write("---@field ", (v.name == "private") and "public" or "", v.name, " ", types(v.type), " @", v.desc, "\n")
	end
end

local function writeParams(f, parameters)
    for _,param in ipairs(parameters) do
        if param[1] ~= "..." or param[2] ~= "*" then
            local t = types(param[2])
            if param[3] and param[1] ~= "..." then t = t .. "|nil" end
            f:write("---@", param[1] ~= "..." and ("param "..param[1]) or "vararg", " ", t, "\n")
        end
    end
end

local function writeSig(f, name, params)
    r = {}
    for _,p in ipairs(params) do
        insert(r, p[1])
    end

    f:write("function ", name, "(", concat(r, ", "), ")end\n")
end

local function writeMethods(f, methods, cname, static)
    sort(methods, sorter)
    local s = static and "." or ":"

    for _, m in ipairs(methods) do
        local p = m.parameters
        writeParams(f, p)
        do --returns
            local ret = {}

            for i, retType in ipairs(m.returnTypes) do
                ret[i] = types(retType)
            end

            f:write('---@return ', concat(ret, ', '), '\n')
        end
        writeSig(f, cname .. s .. m.name, p)
        f:write("\n")
	end
end

for _, class in pairs(docs) do
    local f = io.open(pathJoin("./emmy/", class.name .. ".lua"), "w")
    f:write("---@class ", class.name)

    -- i'd like to put all parents here but EmmyLua doesn't support that yet
    local e,par = next(class.parents)
	if e then f:write(' : ', par) end

	f:write(" @", class.desc:gsub("\n", " "), "\n")

	if next(class.properties) then
        writeProperties(f, class.properties)
        f:write("\n\n")
	end
    f:write("local ", class.name, " = {}\n")

    if next(class.statics) then
        f:write("-- statics\n")
        writeMethods(f, class.statics, class.name, true)
        f:write("\n")
	end

	if next(class.methods) then
        f:write("-- methods\n")
		writeMethods(f, class.methods, class.name, false)
        f:write("\n")
	end

	if class.userInitialized then
        f:write("-- constructor\n")
		writeSig(f, class.name, class.parameters)
    end

    f:close()
end
