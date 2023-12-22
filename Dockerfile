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
COPY nginx.conf /usr/local/openresty/nginx/conf/nginx.conf

COPY scripts /usr/local/openresty/nginx/scripts

# Expón el puerto en el que escucha OpenResty
EXPOSE 80

# Inicia OpenResty cuando se inicie el contenedor
CMD ["/usr/local/openresty/bin/openresty", "-g", "daemon off;"]
