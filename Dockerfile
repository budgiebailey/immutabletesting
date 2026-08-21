FROM fedora:latest

COPY nginx/nginx.conf /etc/nginx/nginx.conf
COPY nginx/index.html /usr/share/nginx/html/index.html

RUN yum install -y nginx && \
    yum clean all

ENTRYPOINT ["nginx", "-g", "daemon off;"]