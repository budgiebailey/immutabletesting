FROM quay.io/fedora/fedora-bootc:latest

LABEL org.opencontainers.image.title="immutabletesting"
LABEL org.opencontainers.image.description="Custom Fedora bootc server image with nginx + Keycloak + Postgres"
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

# Quadlet units: these tell systemd (pid 1 on a bootc host) to start the
# keycloak pod (postgres + keycloak) automatically at boot.
COPY containers/keycloak.pod /usr/share/containers/systemd/keycloak.pod
COPY containers/keycloak-db.container /usr/share/containers/systemd/keycloak-db.container
COPY containers/keycloak.container /usr/share/containers/systemd/keycloak.container
COPY containers/keycloak-db.volume /usr/share/containers/systemd/keycloak-db.volume
COPY containers/keycloak-data.volume /usr/share/containers/systemd/keycloak-data.volume

# Pre-pull the app images so the pod boots immediately without a network call.
# Podman stores them under /var/lib/containers/storage which is part of this image.
# NOTE: a rootless local build cannot unpack gid-mapped layers, so we tolerate a
# failed pull here; the pod then just pulls the images on first start instead.
# Rootful builds (CI, real hosts) succeed and bake the images in.
RUN (podman pull docker.io/library/postgres:18 && podman pull quay.io/keycloak/keycloak:26.7.2) || echo "WARNING: image pull skipped during build (rootless?) - the pod will pull on first boot"

# Make nginx start on boot (systemd is pid 1 on a bootc host)
RUN systemctl enable nginx