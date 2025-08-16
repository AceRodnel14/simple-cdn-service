#!/bin/sh

envsubst '${SERVER_NAME} ${ALLOWED_LAN}' < /etc/nginx/nginx.conf.template > /etc/nginx/conf.d/default.conf

exec nginx -g 'daemon off;'