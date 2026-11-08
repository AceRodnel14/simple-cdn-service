FROM nginx:latest

COPY nginx.conf.template /etc/nginx/nginx.conf.template
COPY entrypoint.sh /entrypoint.sh
COPY assets/favicon.ico /usr/share/nginx/brand/favicon.ico

ENTRYPOINT ["/entrypoint.sh"]