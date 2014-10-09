local _ENV = nil
local getters = {}

local Attr = {
    specified = true
}

function Attr:__index(k)
    local field = Attr[k]
    if field then
        return field
    else
        local getter = getters[k]
        if getter then
            return getter(self)
        end
    end
end

function getters:localName()
    return self.name
end

return Attr