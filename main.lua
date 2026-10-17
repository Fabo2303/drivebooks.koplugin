local WidgetContainer = require("ui/widget/container/widgetcontainer")
local InputDialog = require("ui/widget/inputdialog")
local ButtonDialog = require("ui/widget/buttondialog")
local InfoMessage = require("ui/widget/infomessage")
local UIManager = require("ui/uimanager")
local DataStorage = require("datastorage")
local lfs = require("libs/libkoreader-lfs")

local Settings = require("settings")
local Drive = require("drive")

local Plugin = WidgetContainer:extend{
    name = "drivebooks",
}

local FOLDER_MIME = "application/vnd.google-apps.folder"
local DEFAULT_FOLDER_ID = "1R0b6EwM6dOs2wdXanW6VqeywBqooCFDU"
local DOWNLOAD_DIR = "/mnt/us/koreader/DriveBooks"

function Plugin:init()
    self.settings = Settings:new()
    self.ui.menu:registerToMainMenu(self)
end

function Plugin:getDrive()
    return Drive:new(
        self.settings:get("api_key", ""),
        self.settings:get("folder_id", DEFAULT_FOLDER_ID)
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

function Plugin:message(text)
    UIManager:show(InfoMessage:new{ text = tostring(text) })
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
                    text = "Cancelar",
                    id = "close",
                    callback = function()
                        UIManager:close(dialog)
                    end,
                },
                {
                    text = "Guardar",
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
    UIManager:show(dialog)
    dialog:onShowKeyboard()
end

function Plugin:configureKey()
    self:askText(
        "Google Drive API Key",
        self.settings:get("api_key", ""),
        "Pega tu API Key",
        function(value)
            value = value:match("^%s*(.-)%s*$")
            if value == "" then
                self:message("La API Key no puede estar vacía.")
                return
            end
            self.settings:set("api_key", value)
            self:message("API Key guardada localmente.")
        end
    )
end

function Plugin:configureFolder()
    self:askText(
        "ID de carpeta compartida",
        self.settings:get("folder_id", DEFAULT_FOLDER_ID),
        "ID, no el enlace completo",
        function(value)
            value = value:match("^%s*(.-)%s*$")
            local id = value:match("/folders/([%w_-]+)") or value
            if id == "" then
                self:message("El ID de carpeta no puede estar vacío.")
                return
            end
            self.settings:set("folder_id", id)
            self:message("Carpeta guardada.")
        end
    )
end

function Plugin:showHome()
    local buttons = {
        {
            {
                text = "Explorar libros de Drive",
                callback = function()
                    self:showFolder(self.settings:get("folder_id", DEFAULT_FOLDER_ID), "Mi carpeta")
                end,
            },
        },
        {
            {
                text = "Configurar API Key",
                callback = function()
                    self:configureKey()
                end,
            },
        },
        {
            {
                text = "Cambiar carpeta compartida",
                callback = function()
                    self:configureFolder()
                end,
            },
        },
        {
            {
                text = "Probar conexión",
                callback = function()
                    self:testConnection()
                end,
            },
        },
    }

    UIManager:show(ButtonDialog:new{
        title = "Drive Books",
        buttons = buttons,
    })
end

function Plugin:testConnection()
    local drive = self:getDrive()
    if not drive:isConfigured() then
        self:message("Configura primero la API Key.")
        return
    end
    local files, err = drive:list()
    if not files then
        self:message("No se pudo conectar:\n" .. tostring(err))
        return
    end
    self:message("Conexión correcta. Elementos encontrados: " .. #files)
end

function Plugin:showFolder(folder_id, folder_name)
    local drive = self:getDrive()
    if not drive:isConfigured() then
        self:message("Primero configura tu API Key.")
        return
    end

    self:message("Consultando Google Drive…")
    local files, err = drive:list(folder_id)
    if not files then
        self:message("Error al listar archivos:\n" .. tostring(err))
        return
    end

    local buttons = {}
    buttons[#buttons + 1] = {
        {
            text = "↻ Actualizar",
            callback = function()
                self:showFolder(folder_id, folder_name)
            end,
        },
    }

    if folder_id ~= self.settings:get("folder_id", DEFAULT_FOLDER_ID) then
        buttons[#buttons + 1] = {
            {
                text = "← Volver a la carpeta principal",
                callback = function()
                    self:showFolder(
                        self.settings:get("folder_id", DEFAULT_FOLDER_ID),
                        "Mi carpeta"
                    )
                end,
            },
        }
    end

    for _, file in ipairs(files) do
        local item = file
        local label = item.name or "(sin nombre)"
        if item.mimeType == FOLDER_MIME then
            label = "[Carpeta] " .. label
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
                        self:showFileActions(item)
                    end
                end,
            },
        }
    end

    if #files == 0 then
        buttons[#buttons + 1] = {
            { text = "No se encontraron archivos", callback = function() end },
        }
    end

    UIManager:show(ButtonDialog:new{
        title = "Drive Books: " .. tostring(folder_name or "Carpeta"),
        buttons = buttons,
    })
end

function Plugin:showFileActions(file)
    local buttons = {
        {
            {
                text = "Descargar: " .. file.name,
                callback = function()
                    self:downloadFile(file)
                end,
            },
        },
        {
            {
                text = "Cancelar",
                callback = function() end,
            },
        },
    }
    UIManager:show(ButtonDialog:new{
        title = file.name or "Archivo",
        buttons = buttons,
    })
end

function Plugin:downloadFile(file)
    local drive = self:getDrive()
    self:message("Descargando:\n" .. tostring(file.name))
    local path, err = drive:download(file, DOWNLOAD_DIR)
    if not path then
        self:message("Error de descarga:\n" .. tostring(err))
        return
    end
    self:message("Descarga completa:\n" .. path
        .. "\n\nPuedes encontrar el archivo en la carpeta DriveBooks de KOReader.")
end

return Plugin