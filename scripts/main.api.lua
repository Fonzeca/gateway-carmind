-- /usr/local/openresty/nginx/scripts

dofile("/usr/local/openresty/nginx/scripts/cors.lua")
ngx.log(ngx.INFO, "Processed cors.lua")

dofile("/usr/local/openresty/nginx/scripts/validate.lua")
ngx.log(ngx.INFO, "Processed validate.lua")

