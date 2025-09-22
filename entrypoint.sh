#!/bin/sh

ALLOWED_BLOCKS=""
for net in $ALLOWED_LAN; do
    ALLOWED_BLOCKS="${ALLOWED_BLOCKS}        allow $net;\n"
done

# Export with printf to interpret \n as actual newlines
export ALLOWED_BLOCKS=$(printf "$ALLOWED_BLOCKS")

envsubst '${SERVER_NAME} ${ALLOWED_BLOCKS}' \
    < /etc/nginx/nginx.conf.template \
    > /etc/nginx/conf.d/default.conf

exec nginx -g 'daemon off;'