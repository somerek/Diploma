FROM nginx:alpine
WORKDIR /usr/share/nginx/html
COPY index.html .
COPY frontend.js .
#COPY entrypoint.sh /
#RUN chmod +x /entrypoint.sh
#CMD [ "sh", "-c", "/entrypoint.sh"]
HEALTHCHECK --interval=5s --timeout=5s --retries=3 CMD curl --fail http://localhost/ || exit 1
