
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

    local pattern = "/*api/*(?<service>[^/].*[^/])/*(?<path>/.*)"
    local match, err = ngx.re.match(ngx.var.uri, pattern)
    if err then
        ngx.log(ngx.ERR, "Failed to match URI: ", err)
        return ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
    end

    local service = match[1]
    local path = match[2]
    local query = ngx.var.query_string
    local origin = ngx.req.get_headers()["Origin"]

    -- Crear una nueva instancia de HTTP client
    local httpc = http.new()

    local headers = ngx.req.get_headers()

    --parse map to table
    local headers_table = {}
    for k, v in pairs(headers) do
        headers_table[k] = v
    end

    local full_query = ""
    if query ~= nil then
        full_query = "?" .. query
    end

    ngx.log(ngx.STDERR, "full: ", "http://" .. service .. path .. full_query)

    -- Realizar la llamada a la API
    local res, err = httpc:request_uri("http://" .. service .. path .. full_query, {
        method = ngx.req.get_method(), -- Utilizar el mismo método del request original
        headers = headers_table, -- Utilizar los mismos encabezados del request original
        body = ngx.req.get_body_data(), -- Utilizar el mismo cuerpo del request original
    })
    

    -- Verificar si hubo un error en la llamada
    if not res then
        ngx.log(ngx.ERR, "Failed to make API request: ", err)
        return ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
    end

    if is_public and res.status == 200 and path == "/login" and service == "user-hub" then


        -- Leer el json de la respuesta
        local json = require "cjson"
        local data = json.decode(res.body)

        -- Crear una nueva sesión
        local session, err = resty_session.start({cookie_same_site = (origin == originServer and "Strict" or "None")})
        if not session then
            ngx.log(ngx.ERR, "Failed to create session: ", err)
            return ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
        end

        -- Guardar los datos de usuario en la sesión
        session:set("username", data.username)
        session:set("admin", data.admin)
        session:set("roles", data.roles)
        session:save()
    end

    -- Establecer los encabezados de la respuesta
    ngx.status = res.status
    for key, value in pairs(res.headers) do
        ngx.header[key] = value
    end

    -- Enviar el cuerpo de la respuesta al cliente
    ngx.say(res.body)

    -- Finalizar la ejecución del script
    return ngx.exit(ngx.OK)
end


-- Lista de path admitidos
local authorizedPaths = {
    "/api/user-hub/login",
    "/api/user-hub/password/recover",
    "/api/user-hub/password/validateToken",
    "/api/user-hub/password/reset",
}
-- Si el path del request esta en una lista blanca , no da error
if table_contains(authorizedPaths, ngx.var.uri) then
    proxy_pass(true)
    return
end

if ngx.var.uri == "/api/user-hub/logout" then
    -- Destruir la sesión
    resty_session.logout({cookie_same_site = (origin == originServer and "Strict" or "None")})
    return ngx.exit(ngx.HTTP_OK)
end


local session, err, exists = resty_session.open()

if ngx.var.uri == "/api/user-hub/validate" then
    if exists and session:get("username") then
        local json = require "cjson"

        local resp = {
            username = session:get("username"),
            admin = session:get("admin"),
            roles = session:get("roles"),
        }

        ngx.print(json.encode(resp))
        return ngx.exit(ngx.HTTP_OK)
    else
        return ngx.exit(ngx.HTTP_UNAUTHORIZED)
    end
end


if not exists then
    -- Terminar la request con error
    ngx.log(ngx.ERR, "On open session, not exists: ", err)
    return ngx.exit(ngx.HTTP_UNAUTHORIZED)
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



