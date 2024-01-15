#!/bin/sh

if [ -d "/etc/letsencrypt" ]; then
    echo "Let's Encrypt SSL certificates found in /etc/letsencrypt"
else
    echo "No Let's Encrypt SSL certificates found in /etc/letsencrypt"
    
    sed -i '/ssl/s/^/#/' /usr/local/openresty/nginx/templates/nginx.conf.template
fi




# Aquí puedes poner cualquier comando que necesites ejecutar cuando se inicie el contenedor.
# Por ejemplo, podrías querer reemplazar algunas variables de entorno en tu archivo de configuración de nginx:

envsubst < /usr/local/openresty/nginx/templates/nginx.conf.template > /usr/local/openresty/nginx/conf/nginx.conf

cat /usr/local/openresty/nginx/conf/nginx.conf

# Luego, puedes iniciar tu servidor nginx:
/usr/local/openresty/bin/openresty -g "daemon off;"