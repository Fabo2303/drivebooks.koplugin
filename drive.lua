local https = require("ssl.https")
local ltn12 = require("ltn12")
local json = require("rapidjson")
local lfs = require("libs/libkoreader-lfs")

local Drive = {}
Drive.__index = Drive

local API = "https://www.googleapis.com/drive/v3"
local PAGE_SIZE = 100
local MAX_DOWNLOAD_BYTES = 250 * 1024 * 1024 -- safety limit: 250 MiB

local function encode(s)
    return tostring(s):gsub("[^%w%-_%.~]", function(c)
        return string.format("%%%02X", string.byte(c))
    end)
end

local function urlencode_params(params)
    local out = {}
    for k, v in pairs(params) do
        if v ~= nil and v ~= "" then
            out[#out + 1] = encode(k) .. "=" .. encode(v)
        end
    end
    table.sort(out)
    return table.concat(out, "&")
end

local function safe_name(name)
    name = tostring(name or "download")
    name = name:gsub("[/\\:%z]", "_")
    name = name:gsub("[%c]", "_")
    name = name:gsub("^%.+", "")
    name = name:gsub("%s+$", "")
    if name == "" or name == "." or name == ".." then
        return "download"
    end
    return name
end

local function http_json(url, extra_headers)
    local chunks = {}
    local headers = {
        ["Accept"] = "application/json",
        ["User-Agent"] = "DriveBooks-KOReader/0.1.0",
    }
    for k, v in pairs(extra_headers or {}) do
        headers[k] = v
    end

    local ok, code, response_headers, status = https.request{
        url = url,
        method = "GET",
        headers = headers,
        sink = ltn12.sink.table(chunks),
    }

    if not ok then
        return nil, "No se pudo conectar por HTTPS: " .. tostring(code)
    end
    if tonumber(code) ~= 200 then
        local body = table.concat(chunks)
        local detail = body:sub(1, 400)
        return nil, "Google Drive respondió HTTP " .. tostring(code)
            .. (status and (" (" .. tostring(status) .. ")") or "")
            .. (detail ~= "" and ("\n" .. detail) or "")
    end

    local decoded, result = pcall(json.decode, table.concat(chunks))
    if not decoded or type(result) ~= "table" then
        return nil, "La respuesta de Google no es JSON válido."
    end
    return result
end

function Drive:new(api_key, root_folder_id)
    return setmetatable({
        api_key = api_key or "",
        root_folder_id = root_folder_id or "",
    }, self)
end

function Drive:isConfigured()
    return self.api_key ~= "" and self.root_folder_id ~= ""
end

function Drive:list(folder_id)
    if not self:isConfigured() then
        return nil, "Configura la API Key y el ID de carpeta."
    end

    folder_id = folder_id or self.root_folder_id
    local all_files, page_token = {}, nil

    repeat
        local params = {
            key = self.api_key,
            q = "'" .. folder_id .. "' in parents and trashed = false",
            pageSize = tostring(PAGE_SIZE),
            orderBy = "name",
            fields = "nextPageToken,files(id,name,mimeType,size,resourceKey,modifiedTime,webViewLink)",
            pageToken = page_token,
            supportsAllDrives = "true",
            includeItemsFromAllDrives = "true",
        }

        local url = API .. "/files?" .. urlencode_params(params)
        local headers = {}

        -- Resource keys are supplied by Drive when required. Folder ID alone
        -- cannot reveal a resource key if Google has not made it available.
        local data, err = http_json(url, headers)
        if not data then
            return nil, err
        end

        for _, file in ipairs(data.files or {}) do
            all_files[#all_files + 1] = file
        end
        page_token = data.nextPageToken
    until not page_token

    table.sort(all_files, function(a, b)
        local af = a.mimeType == "application/vnd.google-apps.folder"
        local bf = b.mimeType == "application/vnd.google-apps.folder"
        if af ~= bf then return af end
        return (a.name or ""):lower() < (b.name or ""):lower()
    end)

    return all_files
end

function Drive:download(file, destination)
    if not self:isConfigured() then
        return nil, "Configura primero la API Key y la carpeta."
    end
    if type(file) ~= "table" or not file.id or not file.name then
        return nil, "Datos del archivo no válidos."
    end
    if file.mimeType == "application/vnd.google-apps.folder" then
        return nil, "Selecciona un archivo, no una carpeta."
    end
    if file.mimeType and file.mimeType:match("^application/vnd%.google%-apps%.") then
        return nil, "Este es un documento nativo de Google. La exportación de Docs/Sheets/Slides aún no está implementada."
    end

    local ok_dir = lfs.attributes(destination, "mode") == "directory"
    if not ok_dir then
        local made = lfs.mkdir(destination)
        if not made and lfs.attributes(destination, "mode") ~= "directory" then
            return nil, "No se pudo crear la carpeta: " .. destination
        end
    end

    local name = safe_name(file.name)
    local path = destination .. "/" .. name

    -- Avoid overwriting an existing file: append a numeric suffix.
    local base, ext = name:match("^(.*)(%.[^%.]+)$")
    if not base then base, ext = name, "" end
    local suffix = 1
    while lfs.attributes(path) do
        path = destination .. "/" .. base .. " (" .. suffix .. ")" .. ext
        suffix = suffix + 1
    end

    local url = API .. "/files/" .. encode(file.id) .. "?"
        .. urlencode_params({alt = "media", key = self.api_key})

    local out, open_err = io.open(path, "wb")
    if not out then
        return nil, "No se pudo crear el archivo: " .. tostring(open_err)
    end

    local received = 0
    local sink = function(chunk, err)
        if chunk then
            received = received + #chunk
            if received > MAX_DOWNLOAD_BYTES then
                return nil, "El archivo supera el límite de 250 MiB."
            end
            return out:write(chunk)
        end
        if err then return nil, err end
        return 1
    end

    local headers = {
        ["User-Agent"] = "DriveBooks-KOReader/0.1.0",
    }
    if file.resourceKey then
        headers["X-Goog-Drive-Resource-Keys"] = file.id .. "/" .. file.resourceKey
    end

    local ok, code, response_headers, status = https.request{
        url = url,
        method = "GET",
        headers = headers,
        sink = sink,
    }
    out:close()

    if not ok or tonumber(code) ~= 200 then
        os.remove(path)
        return nil, "Descarga fallida (HTTP " .. tostring(code or status or "sin respuesta") .. ")."
    end

    if received == 0 then
        os.remove(path)
        return nil, "Google devolvió un archivo vacío."
    end

    return path
end

return Drive