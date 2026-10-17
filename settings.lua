local DataStorage = require("datastorage")
local LuaSettings = require("luasettings")

local Settings = {}
Settings.__index = Settings

Settings.path = DataStorage:getSettingsDir() .. "/drivebooks.lua"

function Settings:new()
    local obj = setmetatable({}, self)
    obj.store = LuaSettings:open(obj.path)
    return obj
end

function Settings:get(key, default)
    return self.store:readSetting(key, default)
end

function Settings:set(key, value)
    self.store:saveSetting(key, value)
    self.store:flush()
end

function Settings:clear(key)
    self.store:delSetting(key)
    self.store:flush()
end

return Settings