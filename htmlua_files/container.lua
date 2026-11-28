local modulePrefix = (...):match("^(.-)[^%./]+$") or ""
local Element = require(modulePrefix .. "element")

--- @class Container : Element
--- @field children Element[] Children, in template's order
--- @field inputs Element[]|nil For forms only, contain every inputs
--- @field confirmFunction function|nil For forms only, the function used to verify the form
--- @field onConfirm function|nil For forms only, the function called when the form has been verified
--- @field messageLabel Element|nil For forms only, a label to show messages, especially when there is error during verification
local Container = setmetatable({}, {__index = Element})
Container.__index = Container

Container.TYPES = {
    container = {add = "addFrame", fields = {"content"}},
    page      = {add = "addFrame", fields = {"content"}, fill = true},
    form      = {add = "addFrame", form = true,
                fields = {"content", "confirmFunction", "onConfirm", "messageLabel"}},
}

--- Build a child with the right class, a container will build itself its childs
--- @param parent table Basalt Element of the parent container
--- @param data table Template's part of the child
--- @param manager table The pages manager with the 'functions' table
--- @param form Container|nil The form containing the element
--- @return Element|nil child
--- @return string|nil message
local function buildChild(parent, data, manager, form)
    if type(data) == "table" and Container.TYPES[data.type] then
        return Container.new(parent, data, manager, form)
    end
    return Element.new(parent, data, manager, form)
end


--- Setup a form before building its childs
--- @param self Container The form to setup
--- @param data table Part of the template corresponding to the form
--- @param manager table The object with the functions table
--- @return true|nil ok
--- @return string|nil message
local function setupForm(self, data, manager)
    self.inputs = {}
    local confirmFunction, confirmError = Element._resolveAction(data.confirmFunction, manager)
    if confirmFunction == nil then return nil, "confirmFunction: " .. confirmError end
    
    self.confirmFunction = confirmFunction or nil

    local onConfirm, onConfirmError = Element._resolveAction(data.onConfirm, manager)
    if onConfirm == nil then return nil, "onConfirm: " .. onConfirmError end

    self.onConfirm = onConfirm or nil

    return true
end

--- Create a new container
--- @param parent table Basalt container element
--- @param data table part of the template
--- @param manager table Object with the 'functions' table
--- @param form table|nil Containing form given by Container
--- @return Container|nil container
--- @return string|nil message Message naming the faulty element if the template if invalid
function Container.new(parent, data, manager, form)
    if type(data) ~= "table" then
        return nil, "Container: table expected, got " .. type(data)
    end

    local typeData = Container.TYPES[data.type]
    if not typeData then
        return nil, ("unknown container type '%s'"):format(tostring(data.type))
    end

    local function fail(message)
        return nil, ("%s: %s"):format(Element._describe(data), message)
    end

    local self = setmetatable({}, Container)
    local ok, initError = self:_init(typeData, parent, data, manager)
    if not ok then return fail(initError) end


    if typeData.form then
        local ready, formError = setupForm(self, data, manager)
        if not ready then return fail(formError) end
        form = self
    end

    self.children = {}
    if data.content ~= nil and type(data.content) ~= "table" then
        return fail("content: table expected")
    end

    for index, childData in ipairs(data.content or {}) do
        local child, childError = buildChild(self.basaltElement, childData, manager, form)
        if not child then
            return nil, ("%s > #%d %s"):format(Element._describe(data), index, childError)
        end
        self.children[index] = child
    end

    local messageLabel = typeData.form and Element._optional(data.messageLabel)
    if messageLabel then
        self.messageLabel = self:find(messageLabel)
        if not self.messageLabel then
            return fail(("messageLabel: no element named '%s' in the form"):format(tostring(messageLabel)))
        end
    end

    return self
end

--- Search a element by its name
--- @param name string Searched name
--- @return Element|nil element the first element found with this name
function Container:find(name)
    if self.name == name then return self end
    for _, child in ipairs(self.children) do
        local found = child:find(name)
        if found then return found end
    end
    return nil
end

--- Tells if the container is a form
--- @return boolean isForm
function Container:isForm()
    return self.inputs ~= nil
end



--- Form : return values from the form's inputs
--- Throw a error if the container isn't a form
--- @return table values Table { input name = value }
function Container:getValues()
    if not self:isForm() then
        error(("Container:getValues: %s is not a form")
            :format(Element._describe(self)), 2)
    end

    local values = {}
    for _, input in ipairs(self.inputs) do 
        values[input.name] = input:getText()
    end
    return values
end

--- Form : verify the form content based on the confirmFunction 
--- @return boolean confirm true if the form is validated
--- @return string|nil message Message if the form content is invalid
function Container:confirm()
    if not self:isForm() then
        error(("Container:confirm: %s is not a form")
            :format(Element._describe(self)), 2)
    end

    local accepted, message = true, nil
    if self.confirmFunction then
        accepted, message = self.confirmFunction(self, self:getValues())
    end
    if self.messageLabel then
        self.messageLabel:setText(message ~= nil and tostring(message) or "")
    end

    if not accepted then return false, message end
    if self.onConfirm then self.onConfirm(self) end
    return true
end


return Container