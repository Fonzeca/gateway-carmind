
local function table_contains(tbl, x)
    found = false
    for _, v in pairs(tbl) do
        if v == x then 
            found = true 
        end
    end
    return found
end

-- Middleware para manejar las llamadas CORS

local method = ngx.req.get_method()
local origin = ngx.req.get_headers()["Origin"]

local originServer = os.getenv("ORIGIN_SERVER")

if not originServer then
    originServer = "https://dev.carmind.com.ar"
end

-- Verificar si es una llamada OPTIONS y el origin es permitido
local corsAllowed = os.getenv("CORS_ALLOWED")
local authorizedOrigins = {}

if corsAllowed then
    -- Split the string by comma to get individual origins
    for origin in corsAllowed:gmatch("[^,%s]+") do
        table.insert(authorizedOrigins, origin)
    end
end

if table_contains(authorizedOrigins, origin) then
    ngx.header["Access-Control-Allow-Origin"] = origin
    ngx.header["Access-Control-Allow-Methods"] = "GET, POST, PUT, DELETE"
    ngx.header["Access-Control-Allow-Headers"] = "Content-Type, Authorization"
    ngx.header["Access-Control-Max-Age"] = "86400" -- 24 horas
    ngx.header["Access-Control-Allow-Credentials"] = "true" -- Allow credentials

    if method == "OPTIONS" then
        return ngx.exit(ngx.HTTP_OK)
    end
end



local resty_session = require "resty.session"
local http = require "resty.http"

local function proxy_pass(is_public)

    local pattern = "/*ws/*(?<service>[^/].*[^/])/*(?<path>/.*)"
    local match, err = ngx.re.match(ngx.var.uri, pattern)
    if err then
        ngx.log(ngx.ERR, "Failed to match URI: ", err)
        return ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
    end

    local service = match[1]
    local path = match[2]
    local query = ngx.var.query_string
    local origin = ngx.req.get_headers()["Origin"]

    ngx.var.proxy_uri = service .. path .. (query and "?" .. query or "")
end


-- Lista de path admitidos
-- local authorizedPaths = {
--     "/api/user-hub/login",
--     "/api/user-hub/register",
--     "/api/user-hub/pw/recover",
--     "/api/user-hub/pw/validateToken",
--     "/api/user-hub/pw/reset",
-- }
-- -- Si el path del request esta en una lista blanca , no da error
-- if table_contains(authorizedPaths, ngx.var.uri) then
--     proxy_pass(true)
--     return
-- end

-- if ngx.var.uri == "/api/user-hub/logout" then
--     -- Destruir la sesión
--     resty_session.logout({cookie_same_site = (origin == originServer and "Strict" or "None")})
--     return ngx.exit(ngx.HTTP_OK)
-- end


local session, err, exists = resty_session.open()

-- if ngx.var.uri == "/api/user-hub/validate" then
--     if exists and session:get("username") then
--         -- Setear los headers para el backend
--         return ngx.exit(ngx.HTTP_OK)
--     else
--         return ngx.exit(ngx.HTTP_UNAUTHORIZED)
--     end
-- end


if not exists then

    --Verificamos si tiene apikey
    local apikey = ngx.req.get_headers()["X-Api-Key"]

    if not apikey then
        -- Terminar la request con error
        ngx.log(ngx.ERR, "On open session, not exists: ", err)
        return ngx.exit(ngx.HTTP_UNAUTHORIZED)
    end

    -- Proxy pass con apikey
    proxy_pass(false)
else
    local username = session:get("username")
    local admin = session:get("admin")
    local roles = session:get("roles")

    if not username then
        -- Terminar la request con error
        ngx.log(ngx.ERR, "Not username in session")
        resty_session.destroy()
        return ngx.exit(ngx.HTTP_UNAUTHORIZED)
    end


    -- Setear los headers para el backend
    ngx.req.set_header("X-Username", username)
    ngx.req.set_header("X-Admin", admin)
    ngx.req.set_header("X-Roles", roles)

    proxy_pass(false)
end



