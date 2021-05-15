return function(str)
    local user

    if str == "me" then return author end

    if str:sub(1,2) == "<@" and str:sub(#str,#str) == ">" then
        str = str:sub(str:sub(3,3) == "!" and 4 or 3, #str-1)
    end

    if tonumber(str) and tonumber(str) % 1 == 0 then
        user = client:getUser(str)
    end

    --[[if not user and guild then
        if guild.totalMemberCount <= 250 then
            for member in guild.members:iter() do
                if member.nickname:lower() == str:lower() or member.user.name:lower() == str:lower() then
                    user = member.user
                end
            end
        end
    end]]

    return user
end
