# Usa una imagen base de OpenResty
FROM openresty/openresty:latest

# Copia tu configuración personalizada de OpenResty al contenedor
COPY nginx.conf /usr/local/openresty/nginx/conf/nginx.conf

# Expón el puerto en el que escucha OpenResty
EXPOSE 8080

# Inicia OpenResty cuando se inicie el contenedor
CMD ["/usr/local/openresty/bin/openresty", "-g", "daemon off;"]
