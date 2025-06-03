FROM nginx:alpine
COPY /web_content /usr/share/nginx/html
COPY docker-entrypoint.sh /docker-entrypoint.sh

RUN chmod +x /docker-entrypoint.sh

ENV NAME=Shweta

ENTRYPOINT ["/docker-entrypoint.sh"]

