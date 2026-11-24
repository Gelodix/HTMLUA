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
    --- @param pageName string Name of the page to show
    redirect = function(manager, pageName)
        local shown, showError = manager:showPage(pageName)
        if not shown then error("redirect: " .. showError, 0)end
    end,

    --- Stop the Basalt's loop. Use in template : {"exit"}
    --- @param manager any
    exit = function(manager)
        manager.basalt.stop()
    end,
}

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

function PageManager:build()
    --- building logic
    self.built = true
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
            -- set page's container visibility to true
        else
            -- set page's container visibility to false
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