--- @class Element
--- @field name string Name of the element
--- @field type string Type from the template
--- @field basaltElement table Basalt's element
local Element = {}
Element.__index = Element

-- Template's fields accepted by every type
local COMMON_FIELDS = {
    "name", "type", "text", "position", "size", "foreground", "background", "onClick",
}

-- Extra fields accepted by the inputs
local INPUT_FIELDS = {
    "inputType", "regex", "placeholder", "maxLength", "onEnter", "onChange",
}

-- Describe every element's types. For each type : 
--   add        Basalt function to create the element
--   defaults   default values for properties
--   fields     fields from the template exclusively used by this type
--   events     accepted events, in addition of onClick
--   fill       without 'size', take the size of the parent
--   formRole   role in the parent form    
Element.TYPES = {
    label             = {add = "addLabel"},
    button            = {add = "addButton", defaults = {background = "blue"}},
    input             = {add = "addInput", fields = INPUT_FIELDS, events = {"onEnter", "onChange"}},
    formInput         = {add = "addInput", fields = INPUT_FIELDS, events = {"onEnter", "onChange"}},
    confirmFormButton = {add = "addButton", defaults = {background = "green"}},
}

--- Describe a element for error messages
--- @param data table Piece of the template or element
--- @return string description
function Element._describe(data)
    local type = tostring(data.type)
    if data.name then
        return ("%s '%s'"):format(type, tostring(data.name))
    end
    return type
end

--- Treats an empty string as an absent value.
--- @param value any Read value in the template
--- @return any value The value, or nil if the string was empty
function Element._optional(value)
    if value == "" then return nil end
    return value
end

--- Verify if every fields from the template are known for the type
--- to ensure that there is no error in the template. 
--- @param data table Piece of the template
--- @param typeData table TYPES entries corresponding to data.type
--- @return true|nil ok true if every fields are known
--- @return string|nil message Message naming the unknown field
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


--- Convert a color's name as string into a CC color, also check if the result is a number
--- to avoid to return function from the colors table
--- @param name string|nil Name of the color
--- @param field string Name of the field for error messages
--- @return number|nil color The color, or nil if name is nil 
--- @return string|nil message Message if the color's name in unknown
local function resolveColor(name, field)
    if name == nil then return nil end
    local color = colors[name]
    if type(color) ~= "number" then
        return nil, ("%s: unknown color '%s'"):format(field, tostring(name))
    end
    return color
end

--- Translate parts of the template into propertie table for Basalt 
--- used in add functions on parents
--- @param parent table Parent Basalt element
--- @param data table Part of the template
--- @param typeData table TYPES entries corresponding to data.type
--- @return table|nil properties Basalt properties
--- @return string|nil message Message if a field is invalid
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

--- Transform a action from the template into a ready to call function
--- 
--- A action can be either a name, or a list which the first element 
--- is the name and next ones are arguments
--- @param value string|table|nil Action from the template
--- @param manager table Object with the 'functions' table
--- @return function|false|nil call The call function, false if there is no action or nil if its invalid
--- @return string|nil message Message if the action is invalid
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

--- Bind the events from the template with the manager functions 
--- @param self Element The element under construction
--- @param data table Part of the tempalte
--- @param typeData table TYPES entries corresponding to data.type
--- @param manager table Object with the 'functions' table
--- @return table|nil bound {eventName = true/false} : true if the template defines a action for the event
--- @return string|nil message Message if a action is invalid
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

--- Create a simple element from the template 
--- @param parent table Basalt container element
--- @param data table part of the template
--- @param manager table Object with the 'functions' table
--- @param form table|nil Containing form given by Container
--- @return Element|nil element
--- @return string|nil message Message naming the faulty element if the template if invalid
function Element.new(parent, data, manager, form)
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

--- Search an element by his name. A simple element can only find itself.
--- @param name string Searched name
--- @return Element|nil element The element if the name matches
function Element:find(name)
    if self.name == name then
        return self
    end
    return nil
end

--- Set the element visible
function Element:show()
    self.basaltElement:setVisible(true)
end

--- Set the element hidden
function Element:hide()
    self.basaltElement:setVisible(false)
end

--- Get the text of the element
--- @return string text
function Element:getText()
    return self.basaltElement:getText()
end

--- Set the text of the element
--- @param text string New text
function Element:setText(text)
    self.basaltElement:setText(text)
end


return Element