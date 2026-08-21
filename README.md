# immutabletesting

A learning project that builds a custom Fedora-based server image with nginx and a
small test page baked in, then publishes it to **GitHub Container Registry (ghcr.io)**.

Think of it like rebasing Fedora Silverblue: take an official `fedora` base image and layer
your own changes on top. Each time you edit this repo, the workflow rebuilds and repushes,
so anything that pulls the image automatically gets your latest changes.

## What's in the image

- **Base:** `fedora:latest` (official Fedora container image)
- **nginx** installed via `yum`, serving a custom page
- **`nginx/index.html`** -> `<h1>Test Succeeded!</h1>`

## Project layout

```
.
├── Dockerfile                  # layering: base fedora + nginx + your edit
├── nginx/
│   ├── nginx.conf              # minimal server config (port 8080)
│   └── index.html             # your custom "test succeeded!" page
└── .github/workflows/
    └── build-image.yml        # build + push to ghcr.io on push/tag
```

## The Dockerfile (the "rebase")

```dockerfile
FROM fedora:latest
COPY nginx/nginx.conf /etc/nginx/nginx.conf
COPY nginx/index.html /usr/share/nginx/html/index.html
RUN yum install -y nginx && yum clean all
ENTRYPOINT ["nginx", "-g", "daemon off;"]
```

Edit anything under `nginx/` and the next push rebuilds and repushes the image.

## How the workflow publishes

The workflow runs on pushes to `main` and on tags. It logs into ghcr.io using the built-in
`GITHUB_TOKEN` (no extra secret needed), builds the image, and pushes two references:

- `ghcr.io/<owner>/immutabletesting:latest` — always the newest `main` build
- `ghcr.io/<owner>/immutabletesting:<git-ref>` — tagged per branch/tag

## Pulling and running it

```bash
docker pull ghcr.io/<owner>/immutabletesting:latest
docker run -p 8080:8080 ghcr.io/<owner>/immutabletesting:latest
# then open http://localhost:8080 -> "Test Succeeded!"
```

## Why it's reusable

Because the image is just a Docker layer on top of the official Fedora image, GitH
**Changes to the repo are the source of truth.** Next time you want to redeploy, you pull the
same repo's image and get an identical result.