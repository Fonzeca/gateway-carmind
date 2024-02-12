# Usa una imagen base de OpenResty
FROM openresty/openresty:latest

RUN DEBIAN_FRONTEND=noninteractive apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        openresty-opm \
    && opm get leafo/pgmoon

RUN opm get ledgetech/lua-resty-http

RUN opm get bungle/lua-resty-session

# Install Certbot and its Nginx plugin
RUN apt-get update && apt-get install -y certbot python3-certbot-nginx

# Copia tu configuración personalizada de OpenResty al contenedor
COPY nginx.conf.template /usr/local/openresty/nginx/templates/nginx.conf.template

COPY scripts /usr/local/openresty/nginx/scripts

# Expón el puerto en el que escucha OpenResty
EXPOSE 80

# Copia el script de entrada al contenedor
COPY entrypoint.sh /entrypoint.sh

# Asegúrate de que el script de entrada tenga permisos de ejecución
RUN chmod +x /entrypoint.sh

# Configura el script de entrada como el punto de entrada para el contenedor
ENTRYPOINT ["/entrypoint.sh"]
