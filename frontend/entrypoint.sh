#!/bin/sh
sed -i "s|BACKEND_HOST_PORT|$BACKEND_HOST_PORT|g" /usr/share/nginx/html/frontend.js
nginx -g 'daemon off;'
