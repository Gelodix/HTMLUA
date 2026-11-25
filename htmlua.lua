--- Entry point of the library.
--- only this file need to be manually loaded when using the libray
local modulePrefix = (...):match("^(.-)[^%./]+$") or ""
local PagesManager = require(modulePrefix .. "htmlua_files.pagesManager")

local HTMLUA = {}
local basalt = nil

--- Define the basalt instance to use.
--- Only needed if Basalt is installed in a separate folder
--- @param instance table Basalt instance already loaded
function HTMLUA.setBasalt(instance)
    basalt = instance
end

--- Return the Basalt's instance: the one defined by setBasalt() or else the one got
--- with require("Basalt") which will be kept for next calls.
--- Throw a error if Basalt can't be found.
local function getBasalt()
    if basalt then return basalt end
    local ok, result = pcall(require, "basalt")
    if not ok then error("HTMLUA: Basalt can't be found, install or use HTMLUA.setBasalt()", 3) end
    basalt = result
    return basalt
end

--- Read a template file et convert it into a table.
--- @param filepath string Template's file path
--- @return table|nil template
--- @return string|nil message Message if the file can't be read or is invalid
local function readTemplate(filepath)
    local file, openError = fs.open(filepath, "r")
    if not file then 
        return nil, ("cannot open '%s' : %s"):format(filepath, tostring(openError))
    end
    local content = file.readAll()
    file.close()

    local template = textutils.unserialize(content)
    if type(template) ~= "table" then
        return nil, ("'%s' is not a valid template"):format(filepath)
    end
    return template
end

--- Create a PageManager(not implemented yet) from a template(either file path or table)
--- Throw a error if the file can't be read, if the template isn't a table or Basalt can't be found
--- @param template string|table Template's file path or as a table
--- @param functions table<string, function>|nil Functions usable in the template by name
--- @return PageManager manager
function HTMLUA.newPageManager(template, functions)
    local templateData = template
    if type(template) == "string" then
        local readError
        templateData, readError = readTemplate(template)
        if not templateData then
            error("HTMLUA.newPageManager: " .. readError, 2)
        end
    end
    if type(templateData) ~= "table" then
        error("HTMLUA.newPageManager: file path or table expected, got" .. type(template), 2)
    end

    return PagesManager.new(getBasalt(), templateData, functions)
end

return HTMLUA
