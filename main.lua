local WidgetContainer = require("ui/widget/container/widgetcontainer")
local InputDialog = require("ui/widget/inputdialog")
local ButtonDialog = require("ui/widget/buttondialog")
local InfoMessage = require("ui/widget/infomessage")
local UIManager = require("ui/uimanager")
local lfs = require("libs/libkoreader-lfs")

local Settings = require("settings")
local Drive = require("drive")
local Config = require("config")

local Plugin = WidgetContainer:extend{
    name = "drivebooks",
}

local FOLDER_MIME = "application/vnd.google-apps.folder"
local DOWNLOAD_DIR = "/mnt/us/koreader/DriveBooks"

function Plugin:init()
    self.settings = Settings:new()
    self:reloadConfig(false)
    self.ui.menu:registerToMainMenu(self)
end

function Plugin:getDrive()
    return Drive:new(
        self:getConfigValue("api_key", ""),
        self:getConfigValue("folder_id", "")
    )
end

function Plugin:addToMainMenu(menu_items)
    menu_items.drivebooks = {
        text = "Drive Books",
        sorting_hint = "tools",
        callback = function()
            self:showHome()
        end,
    }
end

function Plugin:closeMenu()
    if self.active_menu then
        local dialog = self.active_menu
        self.active_menu = nil
        pcall(function() UIManager:close(dialog) end)
    end
end

function Plugin:reloadConfig(show_message)
    package.loaded["config"] = nil

    local ok, config = pcall(require, "config")

    if not ok or type(config) ~= "table" then
        if show_message then
            self:message("Error al leer config.lua:\n" .. tostring(config))
        end
        return false
    end

    self.config = config

    if show_message then
        self:message("Configuración recargada correctamente.")
    end

    return true
end

function Plugin:getConfigValue(key, fallback)
    local saved = self.settings:get(key, "")

    if saved ~= nil and saved ~= "" then
        return saved
    end

    local configured = self.config and self.config[key]

    if configured ~= nil and configured ~= "" then
        return configured
    end

    return fallback
end

-- Keep only one plugin menu/dialog active. Wrap callbacks so the current menu
-- is closed before another screen or message is opened.
function Plugin:showMenu(title, buttons)
    self:closeMenu()
    for _, row in ipairs(buttons) do
        for _, button in ipairs(row) do
            if button.callback then
                local callback = button.callback
                button.callback = function()
                    self:closeMenu()
                    callback()
                end
            end
        end
    end
    local dialog = ButtonDialog:new{ title = title, buttons = buttons }
    self.active_menu = dialog
    UIManager:show(dialog)
end

function Plugin:message(text)
    self:closeMenu()
    UIManager:show(InfoMessage:new{ text = tostring(text) })
end

local function ensureDirectory(path)
    if type(path) ~= "string" or path == "" or path:sub(1, 1) ~= "/" then
        return nil, "Please provide an absolute path, for example /mnt/us/koreader/Books."
    end
    local current = ""
    for part in path:gmatch("[^/]+") do
        current = current .. "/" .. part
        local mode = lfs.attributes(current, "mode")
        if mode ~= "directory" then
            if mode then
                return nil, "The path contains a file, not a folder: " .. current
            end
            local ok, err = lfs.mkdir(current)
            if not ok and lfs.attributes(current, "mode") ~= "directory" then
                return nil, "Could not create " .. current .. ": " .. tostring(err)
            end
        end
    end
    return true
end

function Plugin:askText(title, initial, hint, callback)
    local dialog
    dialog = InputDialog:new{
        title = title,
        input = initial or "",
        input_hint = hint,
        buttons = {
            {
                {
                    text = "Cancel",
                    id = "close",
                    callback = function()
                        UIManager:close(dialog)
                    end,
                },
                {
                    text = "Save",
                    is_enter_default = true,
                    callback = function()
                        local value = dialog:getInputText() or ""
                        UIManager:close(dialog)
                        callback(value)
                    end,
                },
            },
        },
    }
    self:closeMenu()
    UIManager:show(dialog)
    dialog:onShowKeyboard()
end

function Plugin:configureApiKey()
    self:askText(
        "Google Drive API key",
        self.settings:get("api_key", ""),
        "Paste your API key",
        function(value)
            value = value:match("^%s*(.-)%s*$")
            if value == "" then
                self:message("The API key cannot be empty.")
                return
            end
            self.settings:set("api_key", value)
            self:message("API key saved locally.")
        end
    )
end

function Plugin:configureSharedFolder()
    self:askText(
        "Shared folder ID",
        self:getConfigValue("folder_id", ""),
        "Folder ID, not the full URL",
        function(value)
            value = value:match("^%s*(.-)%s*$")
            local id = value:match("/folders/([%w_-]+)") or value
            if id == "" then
                self:message("The folder ID cannot be empty.")
                return
            end
            self.settings:set("folder_id", id)
            self:message("Folder saved.")
        end
    )
end

function Plugin:configureDownloadDirectory()
    local current = self.settings:get("download_dir", DOWNLOAD_DIR)
    self:askText(
        "Download folder",
        current,
        "Absolute path on the Kindle",
        function(value)
            value = value:match("^%s*(.-)%s*$")
            if value == "" then
                self:message("The path cannot be empty.")
                return
            end
            local ok, err = ensureDirectory(value)
            if not ok then
                self:message("Could not use that folder:\n" .. tostring(err))
                return
            end
            self.settings:set("download_dir", value:gsub("/+$", ""))
            self:message("Download path saved:\n" .. value)
        end
    )
end

function Plugin:showHome()
    local current_folder_id = self:getConfigValue("folder_id", "")
    local buttons = {
        {
            {
                text = "Browse Drive books",
                callback = function()
                    self:showFolder(current_folder_id, "My folder")
                end,
            },
        },
        {
            {
                text = "Configure API key",
                callback = function()
                    self:configureApiKey()
                end,
            },
        },
        {
            {
                text = "Change shared folder",
                callback = function()
                    self:configureSharedFolder()
                end,
            },
        },
        {
            {
                text = "Change download path",
                callback = function()
                    self:configureDownloadDirectory()
                end,
            },
        },
        {
            {
                text = "Test connection",
                callback = function()
                    self:testConnection()
                end,
            },
        },
        {
            {
                text = "↻ Refrescar configuración",
                callback = function()
                    self:reloadConfig(true)
                end,
            },
        },
    }

    self:showMenu("Drive Books", buttons)
end

function Plugin:testConnection()
    local drive = self:getDrive()
    if not drive:isConfigured() then
        self:message("Configure the API key first.")
        return
    end
    local files, err = drive:list()
    if not files then
        self:message("Could not connect:\n" .. tostring(err))
        return
    end
    self:message("Connection successful. Items found: " .. #files)
end

function Plugin:showFolder(folder_id, folder_name)
    if not folder_id or folder_id == "" then
        self:message("Please configure the shared folder ID first.")
        return
    end

    local drive = self:getDrive()
    if not drive:isConfigured() then
        self:message("Please configure your API key first.")
        return
    end

    local files, err = drive:list(folder_id)
    if not files then
        self:message("Error listing files:\n" .. tostring(err))
        return
    end

    local buttons = {}
    buttons[#buttons + 1] = {
        {
            text = "↻ Refresh",
            callback = function()
                self:showFolder(folder_id, folder_name)
            end,
        },
    }

    local main_folder_id = self:getConfigValue("folder_id", "")
    if folder_id ~= main_folder_id then
        buttons[#buttons + 1] = {
            {
                text = "← Back to main folder",
                callback = function()
                    self:showFolder(main_folder_id, "My folder")
                end,
            },
        }
    end

    for _, file in ipairs(files) do
        local item = file
        local label = item.name or "(unnamed)"
        if item.mimeType == FOLDER_MIME then
            label = "[Folder] " .. label
        elseif item.size then
            label = label .. " (" .. tostring(math.floor(tonumber(item.size) / 1024)) .. " KB)"
        end

        buttons[#buttons + 1] = {
            {
                text = label,
                callback = function()
                    if item.mimeType == FOLDER_MIME then
                        self:showFolder(item.id, item.name)
                    else
                        -- Selecting a file starts the download immediately.
                        self:downloadFile(item)
                    end
                end,
            },
        }
    end

    if #files == 0 then
        buttons[#buttons + 1] = {
            { text = "No files found", callback = function() end },
        }
    end

    self:showMenu("Drive Books: " .. tostring(folder_name or "Folder"), buttons)
end

function Plugin:downloadFile(file)
    local drive = self:getDrive()
    local destination = self.settings:get("download_dir", DOWNLOAD_DIR)
    local path, err = drive:download(file, destination)
    if not path then
        self:message("Download error:\n" .. tostring(err))
        return
    end
    self:message("Downloaded successfully:\n" .. path)
end

return Plugin