local modulePrefix = (...):match("^(.-)[^%./]+$") or ""
local Container = require(modulePrefix .. "container")


--- @class PageManager
--- @field basalt table Basalt instance used by the manager
--- @field basaltMainFrame table Basalt's main frame
--- @field root table|nil Basalt's frame containing all pages
--- @field template table
--- @field default string default page name
--- @field functions table<string, function> functions used in the template
--- @field pages table<string, table>|nil Pages by name
--- @field current string|nil Current page's name
--- @field built boolean true once the pages are builded
local PageManager = {}
PageManager.__index = PageManager

--- this is a first idea of how functions will be implemented to be used in the template
local BUILTIN_FUNCTIONS = {
    --- Change the current shown page. Use in template : {"redirect", "pageName"}
    --- @param manager PageManager
    --- @param element Element Element triggering the action
    --- @param pageName string Name of the page to show
    redirect = function(manager, element, pageName)
        local shown, showError = manager:showPage(pageName)
        if not shown then error("redirect: " .. showError, 0)end
    end,

    --- Stop the Basalt's loop. Use in template : {"exit"}
    --- @param manager any
    exit = function(manager)
        manager.basalt.stop()
    end,
}

--- Verify the template and build each pages in the root frame
--- @param root table Basalt frame on which pages will be added
--- @param manager PageManager Give the template, the default page and the functions
--- @return table<string, Container>|nil pages Pages by name
--- @return string|nil message Message if the template is invalid
local function buildPages(root, manager)
    local template = manager.template
    if type(template.pages) ~= "table" then
        return nil, "pages: table expected, got " .. type(template.pages)
    end

    local pages = {}
    for index, pageData in ipairs(template.pages) do
        if type(pageData) ~= "table" then
            return nil, ("page #%d: table expected, got %s"):format(index, type(pageData))
        end

        local name = pageData.name
        if type(name) ~= "string" or name == "" then
            return nil, ("page #%d: a page need a name"):format(index)
        end

        local page, pageError = Container.new(root, pageData, manager)
        if not page then
            return nil, pageError
        end
        pages[name] = page
    end

    if not pages[manager.default] then
        return nil, ("default_page: no page named '%s'"):format(tostring(manager.default))
    end
    return pages
end

--- Create a manager. Don't build anything on the screen, you must call build().
--- 
--- The functions table is filled with the builtin functionsn then filled with the custom ones.
--- A custom function with the same as a builtin one will replace it.
--- @param basalt table The Basalt's instance used for run()
--- @param template table Loaded template
--- @param functions table<string, function>|nil Custom functions used in the template by name
--- @return PageManager manager
function PageManager.new(basalt, template, functions)
    local self = setmetatable({}, PageManager)
    self.functions = {}
    for name, task in pairs(BUILTIN_FUNCTIONS or {}) do
        self.functions[name] = task
    end
    for name, task in pairs(functions or {}) do
        self.functions[name] = task
    end

    self.basalt = basalt
    self.basaltMainFrame = basalt.getMainFrame()
    self.template = template
    self.default = template.default_page
    self.built = false
    return self
end

--- Build every pages from the template and show the default page
--- Pages are built in a unique root which will be destroy if there is any error
--- @return boolean built true if the pages were built
--- @return string|nil message Message if the template is invalid
function PageManager:build()
    if self.built then
        error("PageManager:build: pages are already built", 2)
    end

    local root = self.basaltMainFrame:addFrame({
        width = self.basaltMainFrame.width,
        height = self.basaltMainFrame.height,
    })

    local pages, buildError = buildPages(root, self)
    if not pages then
        root:destroy()
        return false, buildError
    end

    self.root = root
    self.pages = pages
    self.built = true

    return self:showPage(self.default)
end

--- Add a new usable function for the template or replace one with the same name
--- @param name string The name of the function in the template
--- @param task function The function called with (manager, element, args from template)
--- @return PageManager self The manager to chain calls
function PageManager:addFunction(name, task)
    if self.built then error(("PageManager:addFunction: pages are already built, adding functions will not have any effect"), 2) end

    if type(task) ~= "function" then
        error("PageManager:addFunction: expected function, got" .. type(task), 2)
    end

    if type(name) ~= "string" then
        error("PageManager:addFunction: expected string, got" .. type(name), 2)
    end

    self.functions[name] = task
    return self
end

--- Show a page and hide every other ones. If page don't exist, don't change anything.
--- Throw a error if used before build()
--- @param pageName string The name of the page to show
--- @return boolean shown true if the page is shown
--- @return string|nil message Message if the page don't exist
function PageManager:showPage(pageName)
    if not self.built then error("PageManager:showPage: the pages aren't built yet", 2) end
    if not self.pages[pageName] then return false, ("no page named '%s'"):format(tostring(pageName)) end

    for name, page in pairs(self.pages) do
        if name == pageName then
            page:show()
        else
            page:hide()
        end
    end

    self.current = pageName
    return true
end

--- Start the Basalt's event loop on the manager instance
function PageManager:run()
    if self.built then 
        self.basalt.run() 
    else
        error("PageManager:run: Can't start basalt, the pages aren't builded yet", 2)
    end
end

return PageManager