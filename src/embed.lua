---@class embed
---@field private __data table

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
            value = value
        })
    end

    ---@param value string
    ---@return embed
    function builder:setDescription(value, ...)
        if select("#", ...) > 0 then
            value = string.format(value, ...)
        end

        self.__data.description = value
    end

    ---@param value number|Color
    ---@return embed
    function builder:setColor(value)
        self.__data.color = value or 0xFFFFFF
    end

    ---@return table
    function builder:build()
        return self.__data
    end

    return builder
end

return builder