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

if [ -d "/etc/letsencrypt/live/$SERVER_NAME" ] && [ "$(ls -A /etc/letsencrypt/live/$SERVER_NAME)" ]; then
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
    echo "Running certbot with webroot and variables: $CERTBOT_EMAIL and $SERVER_NAME"
    rm /var/www/certbot
    mkdir /var/www/certbot
    certbot certonly --webroot -w /var/www/certbot --non-interactive --agree-tos --email $CERTBOT_EMAIL --domains $SERVER_NAME

    # Restore file
    echo "Restoring nginx.conf.template"
    mv /usr/local/openresty/nginx/templates/nginx.conf.template.bak /usr/local/openresty/nginx/templates/nginx.conf.template

    # Reload nginx
    echo "quit neginx"
    /usr/local/openresty/bin/openresty -s quit

    echo "run_nginx"
    run_nginx off
fi

