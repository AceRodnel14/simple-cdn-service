#!/bin/sh

ALLOWED_BLOCKS=""
for net in $ALLOWED_LAN; do
    ALLOWED_BLOCKS="${ALLOWED_BLOCKS}        allow $net;\n"
done

# Export with printf to interpret \n as actual newlines
export ALLOWED_BLOCKS=$(printf "$ALLOWED_BLOCKS")

case "$SECURED_KEY" in
    "")
        echo "WARNING: SECURED_KEY is not set, /secured/ is disabled (all requests get 403)" >&2
        SECURED_KEY_MAP=""
        ;;
    *[!A-Za-z0-9_-]*)
        echo "ERROR: SECURED_KEY is invalid: only A-Z a-z 0-9 _ - are allowed, 32 to 128 characters" >&2
        exit 1
        ;;
    *)
        if [ "${#SECURED_KEY}" -lt 32 ] || [ "${#SECURED_KEY}" -gt 128 ]; then
            echo "ERROR: SECURED_KEY is invalid: only A-Z a-z 0-9 _ - are allowed, 32 to 128 characters" >&2
            exit 1
        fi
        # regex entry (~) makes the match case-sensitive; the key is restricted to [A-Za-z0-9_-]
        # shellcheck disable=SC2089,SC2090 # literal quotes are intended for the nginx map
        SECURED_KEY_MAP='"~^'"$SECURED_KEY"'$" 1;'
        ;;
esac
# shellcheck disable=SC2090
export SECURED_KEY_MAP

envsubst '${SERVER_NAME} ${ALLOWED_BLOCKS} ${SECURED_KEY_MAP}' \
    < /etc/nginx/nginx.conf.template \
    > /etc/nginx/conf.d/default.conf

exec nginx -g 'daemon off;'