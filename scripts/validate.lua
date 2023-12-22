
-- Middleware para manejar las llamadas CORS

local method = ngx.req.get_method()
local origin = ngx.req.get_headers()["Origin"]

-- Verificar si es una llamada OPTIONS y el origin es permitido
local authorizedOrigins = {
    "https://dev.carmind.com.ar",
    "https://localhost:3000"
}

if method == "OPTIONS" and contains(authorizedOrigins, origin) then
    ngx.header["Access-Control-Allow-Origin"] = origin
    ngx.header["Access-Control-Allow-Methods"] = "GET, POST, PUT, DELETE"
    ngx.header["Access-Control-Allow-Headers"] = "Content-Type, Authorization"
    ngx.header["Access-Control-Max-Age"] = "86400" -- 24 horas
    return ngx.exit(ngx.HTTP_OK)
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

    -- Crear una nueva instancia de HTTP client
    local httpc = http.new()

    ngx.log(ngx.STDERR, "new intarnal call to: ", "http://" , service , path)

    ngx.log(ngx.STDERR, "headers: ", ngx.req.get_headers())

    ngx.log(ngx.STDERR, "body: ", ngx.req.get_body_data())

    -- Realizar la llamada a la API
    local res, err = httpc:request_uri("http://" .. service .. path, {
        method = ngx.req.get_method(), -- Utilizar el mismo método del request original
        -- headers = ngx.req.get_headers(), -- Utilizar los mismos encabezados del request original
        -- body = ngx.req.get_body_data(), -- Utilizar el mismo cuerpo del request original
    })
    

    -- Verificar si hubo un error en la llamada
    if not res then
        ngx.log(ngx.ERR, "Failed to make API request: ", err)
        return ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
    end

    if is_public and res.status == 200 and path == "login" and service == "user-hub" then


        -- Leer el json de la respuesta
        local json = require "cjson"
        local data = json.decode(res.body)

        -- Crear una nueva sesión
        local session, err = resty_session.start()
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

local function table_contains(tbl, x)
    found = false
    for _, v in pairs(tbl) do
        if v == x then 
            found = true 
        end
    end
    return found
end

ngx.log(ngx.STDERR, "new call to: ", ngx.var.uri)

-- Lista de path admitidos
local authorizedPaths = {
    "/api/user-hub/login",
    "/api/user-hub/register",
}
-- Si el path del request esta en una lista blanca , no da error
if table_contains(authorizedPaths, ngx.var.uri) then
    proxy_pass(true)
    return
end



local session, err, exists = resty_session.open()


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



