FROM nginx
COPY bin/intellij/sage.html /usr/share/nginx/html
COPY bin/intellij/Scratch.swf /usr/share/nginx/html