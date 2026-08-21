FROM quay.io/fedora/fedora-bootc:latest

LABEL org.opencontainers.image.title="immutabletesting"
LABEL org.opencontainers.image.description="Custom Fedora bootc server image with nginx + test page"
LABEL org.opencontainers.image.vendor="budgiebailey"
LABEL org.opencontainers.image.source="https://github.com/budgiebailey/immutabletesting"

# Install first, then drop the packaged index.html symlink so our COPY below
# replaces it with a real file (nginx's index.html is a symlink to the Fedora
# test page; removing it first stops the package default from winning).
RUN dnf -y install nginx && \
    rm -f /usr/share/nginx/html/index.html && \
    dnf clean all

COPY nginx/nginx.conf /etc/nginx/nginx.conf
COPY nginx/index.html /usr/share/nginx/html/index.html

# Make nginx start on boot (systemd is pid 1 on a bootc host)
RUN systemctl enable nginx