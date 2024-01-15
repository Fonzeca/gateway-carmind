#!/bin/sh

# function that run nginx
run_nginx() 
{
    DEAMON=$1
    # Remplaza las variables de entorno en el archivo de configuración de nginx
    echo "Replacing environment variables in nginx configuration file"
    envsubst < /usr/local/openresty/nginx/templates/nginx.conf.template > /usr/local/openresty/nginx/conf/nginx.conf

    # Luego, puedes iniciar tu servidor nginx:
    echo "Starting nginx with daemon $DEAMON"
    /usr/local/openresty/bin/openresty -g "daemon $DEAMON;"
}

if [ -d "/etc/letsencrypt" ] && [ "$(ls -A /etc/letsencrypt)" ]; then
    echo "Let's Encrypt SSL certificates found in /etc/letsencrypt"

    # Run nginx
    echo "run_nginx"
    run_nginx off

else
    echo "No Let's Encrypt SSL certificates found in /etc/letsencrypt"
    echo "Generating Let's Encrypt SSL certificates"

    # Backup file
    echo "Backing up nginx.conf.template"
    cp /usr/local/openresty/nginx/templates/nginx.conf.template /usr/local/openresty/nginx/templates/nginx.conf.template.bak
    
    # Remove the ssl directive from the nginx.conf.template
    echo "Removing ssl directive from nginx.conf.template"
    sed -i '/ssl/s/^/#/' /usr/local/openresty/nginx/templates/nginx.conf.template

    # Run nginx 
    echo "run_nginx"
    run_nginx on

    # Run certbot
    echo "Running certbot with webroot and variables: $EMAIL and $SERVER_NAME"
    certbot certonly --webroot -w /var/www/certbot --standalone --non-interactive --agree-tos --email $EMAIL --domains $SERVER_NAME

    # Restore file
    echo "Restoring nginx.conf.template"
    mv /usr/local/openresty/nginx/templates/nginx.conf.template.bak /usr/local/openresty/nginx/templates/nginx.conf.template

    echo "Adding ssl directive to nginx.conf.template"
    envsubst < /usr/local/openresty/nginx/templates/nginx.conf.template > /usr/local/openresty/nginx/conf/nginx.conf

    # Reload nginx
    echo "Reloading nginx"
    /usr/local/openresty/bin/openresty -s reload
fi

