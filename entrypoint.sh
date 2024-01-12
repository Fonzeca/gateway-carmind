#!/bin/sh

# Aquí puedes poner cualquier comando que necesites ejecutar cuando se inicie el contenedor.
# Por ejemplo, podrías querer reemplazar algunas variables de entorno en tu archivo de configuración de nginx:

envsubst < /usr/local/openresty/nginx/templates/nginx.conf.template > /usr/local/openresty/nginx/conf/nginx.conf

cat /usr/local/openresty/nginx/conf/nginx.conf

# Luego, puedes iniciar tu servidor nginx:
/usr/local/openresty/bin/openresty -g "daemon off;"