FROM quay.io/fedora/fedora-bootc:stable

LABEL org.opencontainers.image.title="immutabletesting"
LABEL org.opencontainers.image.description="Custom Fedora bootc server image with nginx + test page"
LABEL org.opencontainers.image.vendor="budgiebailey"
LABEL org.opencontainers.image.source="https://github.com/budgiebailey/immutabletesting"

COPY nginx/nginx.conf /etc/nginx/nginx.conf
COPY nginx/index.html /usr/share/nginx/html/index.html

RUN dnf -y install nginx && \
    dnf clean all

# Make nginx start on boot (systemd is pid 1 on a bootc host)
RUN systemctl enable nginx