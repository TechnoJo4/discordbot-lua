---@class embed
---@field private __data table

---@return embed
function builder()
    ---@type embed
    local builder = {__data={}}

    local function d(n, v)
        if not builder.__data[n] then
            builder.__data[n] = v
        end
    end

    local function a(n, v)
        table.insert(builder.__data[n], v)
    end

    ---@param name string
    ---@param value string
    ---@param inline boolean
    ---@return embed
    function builder:addField(name, value, inline)
        d("fields", {})
        inline = inline or true

        a("fields", {
            name = name,
            value = value,
            inline = inline,
        })
        return self
    end

    ---@param value string
    ---@return embed
    function builder:setDescription(value, ...)
        if select("#", ...) > 0 then
            value = string.format(value, ...)
        end

        self.__data.description = value
        return self
    end

    ---@param value string
    ---@return embed
    function builder:setTitle(value, ...)
        if select("#", ...) > 0 then
            value = string.format(value, ...)
        end

        self.__data.title = value
        return self
    end

    ---@param value string
    ---@return embed
    function builder:setImage(value, ...)
        if select("#", ...) > 0 then
            value = string.format(value, ...)
        end

        self.__data.image = { url = value }
        return self
    end

    ---@param value number|Color
    ---@return embed
    function builder:setColor(value)
        self.__data.color = value or 0xFFFFFF
        return self
    end

    ---@return table
    function builder:build()
        return {embed=self.__data}
    end

    function builder:send(c, content)
        if c.channel then c = c.channel end
        local data = self:build()
        data.content = content
        return c:send(data)
    end

    return builder
end

return builder
