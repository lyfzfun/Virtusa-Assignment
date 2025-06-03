#!/bin/sh

sed -i "s/__NAME__/${NAME}/g" /usr/share/nginx/html/index.html

exec nginx -g "daemon off;"
