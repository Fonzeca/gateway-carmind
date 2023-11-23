local http = require "resty.http"

local httpc = http.new()

local res, err = httpc:request_uri("http://user-hub/validate", {
    method = "POST", -- o "POST", "PUT", etc., según lo que necesites
    headers = {
        ["Content-Type"] = "application/json", -- ajusta los encabezados según tus necesidades
    },
    -- body = '{"key": "value"}', -- si necesitas enviar datos en el cuerpo de la solicitud
})

if not res then
    ngx.status = 500
    ngx.say("Error en la solicitud REST: ", err)
    return
end

-- Puedes manejar la respuesta del servicio REST aquí
ngx.status = res.status
ngx.say(res.body)

httpc:close()
