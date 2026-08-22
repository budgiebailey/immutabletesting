# immutabletesting

A learning project that builds a **custom Fedora OS image** (bootc / OSTree-style) that you can
install on real machines and update by **rebasing**, exactly like Fedora Atomic Desktop / Silverblue.

The source of truth is this repo. Every push to `main` (or tag) rebuilds the image and pushes it to
**GitHub Container Registry (ghcr.io)**. Machines `bootc switch` to the image; when you edit the repo,
they pull the new commit on upgrade and boot it next time — with automatic rollback if it fails to boot.

## Concept

- **bootc** (`github.com/bootc-dev/bootc`) = the modern way to boot a machine from a normal
  OCI/Docker container image. The image includes a kernel in `/usr` and systemd runs as pid 1.
- The OS is delivered as an image, not a package-by-package install. Updating = rebasing to a new image.
- We build on **`quay.io/fedora/fedora-bootc`** — the official minimal Fedora bootc base — and layer
  our own packages/config on top.

## What's in the image

- **Base:** `quay.io/fedora/fedora-bootc:latest` (official Fedora bootc base)
- **nginx** installed via `dnf` and pinned to **systemd** (auto-start on boot)
- **`nginx/index.html`** -> `<h1>Test Succeeded!</h1>`
- **Keycloak** (dev mode) + **Postgres** running as a podman pod, auto-started by
  systemd via **quadlet** (see `containers/`). Admin console: `http://<ip>:8080`

## Keycloak (dev instance)

The image ships a pod of two containers, defined in `containers/` as podman **quadlet**
units (systemd translates `.pod` / `.container` / `.volume` files into services and
starts them at boot):

| Unit file                       | What it runs                     | Listens on       |
|---------------------------------|----------------------------------|------------------|
| `containers/keycloak.pod`       | shared pod (network namespace)   | 8080, 5432 (LAN) |
| `containers/keycloak-db.container` | `postgres:18`                  | 5432 in-pod      |
| `containers/keycloak.container` | `keycloak:26.7.2 start-dev`    | 8080 in-pod      |

Because it's a pod, Keycloak reaches Postgres at `localhost:5432` and both start as
systemd services (`keycloak.service`, `keycloak-db.service`, `keycloak-pod.service`,
auto-enabled to `default.target`) so they survive reboots and restart on crash.

### Access it

After the machine is up, from another machine on the LAN:

```
http://<machine-ip>:8080/admin     # admin console
```

Default dev credentials (set via `KC_BOOTSTRAP_ADMIN_*` in `keycloak.container`):

```
username: admin
password: admin
```

Postgres is exposed on `5432` (dev only) so you can poke at it:

```
psql "postgresql://keycloak:keycloak@<machine-ip>:5432/keycloak"
```

### Firewall

If firewalld is running, allow the ports:

```bash
systemctl enable --now firewalld
firewall-cmd --permanent --add-port=8080/tcp --add-port=5432/tcp
firewall-cmd --reload
```

Notes:
- In `dev` mode (`start-dev`) Keycloak binds to `0.0.0.0`, so the local IP works without a
  reverse proxy — exactly what we want for a dev box.
- The pod images are pre-pulled into the image at build time (rootful/CI builds bake them
  in so first boot works offline). Rootless local builds skip the pre-pull and the pod
  just pulls the images on first start.

## Project layout

```
.
├── Containerfile               # the OS image definition (FROM fedora-bootc + our layers)
├── nginx/
│   ├── nginx.conf              # server config (port 80)
│   └── index.html             # the "test succeeded!" page
├── containers/                 # podman quadlet units for the keycloak pod
│   ├── keycloak.pod            # pod: shared netns, publishes 8080 + 5432
│   ├── keycloak.container      # keycloak:26.7.2 start-dev, admin admin/admin
│   ├── keycloak-db.container   # postgres:18, db=user=pass=keycloak
│   └── *.volume                # named volumes for postgres + keycloak state
└── .github/workflows/
    └── build-image.yml        # build + push to ghcr.io on push/tag
```

## The Containerfile (the OS definition)

```containerfile
FROM quay.io/fedora/fedora-bootc:latest

LABEL org.opencontainers.image.title="immutabletesting"
LABEL org.opencontainers.image.source="https://github.com/budgiebailey/immutabletesting"

COPY nginx/nginx.conf /etc/nginx/nginx.conf
COPY nginx/index.html /usr/share/nginx/html/index.html

RUN dnf -y install nginx && dnf clean all
RUN systemctl enable nginx
```

Edit anything here and push — the workflow rebuilds and repushes the image.

## What the workflow does

On every push to `main`/tag:
1. logs into ghcr.io (built-in `GITHUB_TOKEN`, no extra secret)
2. builds the image with **buildah** (required for bootc, keeps the OCI layout intact)
3. pushes `ghcr.io/<owner>/immutabletesting:latest` and `:<git-ref>`

## Installing on a fresh machine (from a Fedora Atomic installer)

If you boot a Fedora Atomic install, you can rebase in-place from the live installer:

```bash
# from the installer, once the target disk is ready:
bootc switch --install-to-disk --replace-self \
  ghcr.io/budgiebailey/immutabletesting:latest
```

Then reboot into your custom image.

## Rebasing an already-installed Fedora Atomic / Silverblue system

On the running machine:

```bash
bootc switch ghcr.io/budgiebailey/immutabletesting:latest
bootc upgrade   # fetch the latest stored image
```

Reboot when ready. `bootc status` shows the deployment; if it fails to boot, the previous
deployment is still there and boots next.

## Iterating (the bit you asked about)

Because the image is managed in the repo:

1. edit `nginx/` or `Containerfile`
2. `git commit` + `git push` -> CI rebuilds and repushes `ghcr.io/budgiebailey/immutabletesting:latest`
3. on the target machine: `bootc upgrade` (or `bootc switch ghcr.io/budgiebailey/immutabletesting:latest`)
4. reboot — the machine is now running your new image

No package installs directly on the box. The repo is the source of truth.

## Local build (optional, for testing)

```bash
buildah build --label io.bootc.install=1 -f Containerfile -t immutabletesting .
```

## Notes / current status

- Image builds and pushes automatically to ghcr.io.
- "Test Succeeded!" is served by nginx on port 80.
- Keycloak 26.7.2 (dev admin console) + Postgres 18 run as a systemd-managed podman pod
  on ports 8080 / 5432 — verified locally: postgres schema initialises and Keycloak listens.
