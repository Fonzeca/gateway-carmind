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
    ngx.exit(ngx.HTTP_OK)
end

-- Continuar con la ejecución normal


