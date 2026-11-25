--- @class Element
--- @field name string Name of the element
--- @field type string Type from the template
--- @field basaltElement table Basalt's element
local Element = {}
Element.__index = Element

local COMMON_FIELDS = {
    "name", "type", "text", "position", "size", "foreground", "background", "onClick",
}

local INPUT_FIELDS = {
    "inputType", "regex", "placeholder", "maxLength", "onEnter", "onChange",
}

Element.TYPES = {
    label             = {add = "addLabel"},
    button            = {add = "addButton", defaults = {background = "blue"}},
    input             = {add = "addInput", fields = INPUT_FIELDS, events = {"onEnter", "onChange"}},
    formInput         = {add = "addInput", fields = INPUT_FIELDS, events = {"onEnter", "onChange"}},
    confirmFormButton = {add = "addButton", defaults = {background = "green"}},
}

function Element._describe(data)
    local type = tostring(data.type)
    if data.name then
        return ("%s '%s'"):format(type, tostring(data.name))
    end
    return type
end

function Element._optional(value)
    if value == "" then return nil end
    return value
end

local function checkFields(data, typeData)
    local allowed = {}
    for _, field in ipairs(COMMON_FIELDS) do allowed[field] = true end
    for _, field in ipairs(typeData.fields or {}) do allowed[field] = true end
    for field in pairs(data) do
        if not allowed[field] then
            return nil, ("unknown field '%s'"):format(tostring(field))
        end
    end
    return true
end

local function resolveColor(name, field)
    if name == nil then return nil end
    local color = colors[name]
    if type(color) ~= "number" then
        return nil, ("%s: unknown color '%s'"):format(field, tostring(name))
    end
    return color
end

local function buildProperties(parent, data, typeData)
    local default = typeData.defaults or {}
    local properties = {name = data.name, text = data.text}

    if data.position ~= nil then
        if type(data.position) ~= "table" then
            return nil, "position: table {x, y} expected"
        end
        properties.x = data.position.x
        properties.y = data.position.y
    end

    if data.size ~= nil then
        if type(data.size) ~= "table" then
            return nil, "size: table {x, y} expected"
        end
        properties.width = data.size.x
        properties.height = data.size.y
    elseif typeData.fill then
        properties.width = parent.width
        properties.height = parent.height
    end

    local colorError

    properties.foreground, colorError =
        resolveColor(data.foreground or default.foreground, "foreground")
    if colorError then return nil, colorError end

    properties.background, colorError =
        resolveColor(data.background or default.background, "background")
    if colorError then return nil, colorError end

    if typeData.add == "addInput" then
        local inputType = Element._optional(data.inputType)
        if inputType == "password" then
            properties.replaceChar = "*"
        elseif inputType ~= nil then
            return nil, ("inputType: unknown type '%s'"):format(tostring(inputType))
        end
        properties.pattern = Element._optional(data.regex)
        properties.placeholder = Element._optional(data.placeholder)
        properties.maxLength = data.maxLength
    end

    return properties
end

function Element._resolveAction(value, manager)
    if value == nil then return false end

    local action
    if type(value) == "string" then
        action = {value}
    elseif type(value) == "table" then
        if value[1] == nil then return false end
        action = value
    end
    if not action or type(action[1]) ~= "string" then
        return nil, "function name expected"
    end

    local handler =  manager and manager.functions and manager.functions[action[1]]

    if type(handler) ~= "function" then
        return nil, ("unknown function '%s'"):format(action[1])
    end

    return function(element, ...)
        local arguments = table.pack(...)
        for index = 2, #action do
            arguments.n = arguments.n + 1
            arguments[arguments.n] = action[index]
        end
        return handler(manager, element, table.unpack(arguments, 1, arguments.n))
    end
end

local function bindEvents(self, data, typeData, manager)
    local bound = {}
    local fields = {"onClick"}
    for _, field in ipairs(typeData.events or {}) do
        fields[#fields+1] = field
    end

    for _, field in ipairs(fields) do
        local call, actionError = Element._resolveAction(data[field], manager)
        if call == nil then
            return nil, ("%s: %s"):format(field, actionError)
        end
        if call then
            self.basaltElement[field](self.basaltElement, function()
                call(self)
            end)
        end
        bound[field] = call ~= false
    end
    return bound
end

function Element:_init(typeData, parent, data, manager)
    local fieldsOk, fieldsError = checkFields(data, typeData)
    if not fieldsOk then return nil, fieldsError end

    local properties, propertiesError = buildProperties(parent, data, typeData)
    if not properties then return nil, propertiesError end

    self.name = data.name
    self.type = data.type
    self.basaltElement = parent[typeData.add](parent, properties)

    local bound, bindError = bindEvents(self, data, typeData, manager)
    if not bound then return nil, bindError end

    return true

end

function Element.new(parent, data, manager)
    if type(data) ~= "table" then
        return nil, "Element: table expected, got " .. type(data)
    end

    local typeData = Element.TYPES[data.type]
    if not typeData then
        return nil, ("Element: unknown element type '%s'"):format(tostring(data.type))
    end

    local self = setmetatable({}, Element)

    local ok, initError = self:_init(typeData, parent, data, manager)

    if not ok then
        return nil, ("%s: %s"):format(Element._describe(data), initError)
    end

    return self
end




return Element