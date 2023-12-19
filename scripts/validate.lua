-- Importar la biblioteca de Redis
local redis = require "resty.redis"

-- Crear una nueva instancia de conexión a Redis
local red = redis:new()

-- Establecer la dirección y el puerto de Redis
local redis_host = "127.0.0.11"
local redis_port = 6379

-- Establecer el tiempo de espera para la conexión a Redis (en milisegundos)
red:set_timeout(1000)
red:set_keepalive(10000, 100)

-- Conectar a Redis
local ok, err = red:connect(redis_host, redis_port)
if not ok then
    ngx.log(ngx.ERR, "Error al conectar a Redis: ", err)
    return ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
end

-- Obtener el ID de sesión del cliente desde la solicitud
local session_id = ngx.var.cookie_session_id

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
