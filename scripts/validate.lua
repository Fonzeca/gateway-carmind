local resty_session = require "resty.session"
local http = require "resty.http"

local function proxy_pass(is_public)
    -- Obtener la URI del request
    local service = ngx.var.service
    local path = ngx.var.path

    -- Crear una nueva instancia de HTTP client
    local httpc = http.new()

    ngx.log(ngx.INFO, "new call to: ", service, "/", path)

    -- Realizar la llamada a la API
    local res, err = httpc:request_uri("http://" .. service .. path, {
        method = ngx.req.get_method(), -- Utilizar el mismo método del request original
        headers = ngx.req.get_headers(), -- Utilizar los mismos encabezados del request original
        body = ngx.req.get_body_data(), -- Utilizar el mismo cuerpo del request original
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



-- Lista de path admitidos
local authorizedPaths = {
    "/user-hub/login",
    "/user-hub/register",
}
-- Si el path del request esta en una lista blanca , no da error
if table_contains(authorizedPaths, "/" .. ngx.var.service .. "/" .. ngx.var.path) then
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





local function connect_redis()
    local red = redis:new()

    local redis_host = "127.0.0.11"
    local redis_port = 6379

    red:set_timeout(1000)
    red:set_keepalive(10000, 100)

    local ok, err = red:connect(redis_host, redis_port)
    if not ok then
        ngx.log(ngx.ERR, "Failed to connect to Redis: ", err)
        return nil
    end

    return red
end

local function add_session_to_redis(session_id, user_json)
    local red = connect_redis()
    if not red then
        return false
    end

    local username = user_json['username']
    local admin = user_json['admin']
    local roles = user_json['roles']

    local res, err = red:hmset('sessions:' .. session_id, 'username', username, 'admin', admin, 'roles', roles)
    if not res then
        ngx.log(ngx.ERR, "Failed to add session to Redis: ", err)
        return false
    end

    return true
end

--new function
local function validate_session(cookie_session)
    local http = require "resty.http"
    local httpc = http.new()

    local res, err = httpc:request_uri("http://user-hub:5623/validate", {
        method = "POST", -- o "POST", "PUT", etc., según lo que necesites
        headers = {
            ["Content-Type"] = "application/json", -- ajusta los encabezados según tus necesidades
            ["Cookie"] = "session=" .. cookie_session,
        },
        -- body = '{"key": "value"}', -- si necesitas enviar datos en el cuerpo de la solicitud
    })

    if not res then
        ngx.status = 500
        ngx.say("Error en la solicitud REST: ", err)
        return false
    end

    -- Puedes manejar la respuesta del servicio REST aquí
    
    -- leer el json de la respuesta
    local json = require "cjson"
    local data = json.decode(res.body)

    --create session_id



    add_session_to_redis()

    httpc:close()

    return true
end





if not session_id then
    -- validamos contra user-hub
    validate_session(session)
else
    -- validamos en redis, y sino en user-hub
end





-- Verificar si la sesión está activa en Redis
local session_active, err = red:get(session_id)
if err then
    ngx.log(ngx.ERR, "Error al obtener la sesión de Redis: ", err)
    return ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
end

-- Comprobar si la sesión está activa
if session_active == ngx.null then
    ngx.log(ngx.ERR, "La sesión no está activa")
    return ngx.exit(ngx.HTTP_UNAUTHORIZED)
end

-- La sesión está activa, continuar con la lógica del script...

-- Cerrar la conexión a Redis
-- local ok, err = red:close()
-- if not ok then
--     ngx.log(ngx.ERR, "Error al cerrar la conexión a Redis: ", err)
--     return ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
-- end


