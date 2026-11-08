# simple-cdn-service
CDN (Content Delivery Network). This repository contains minimal code to be able to use NGINX as CDN server to host static files like images.

- Everything is served from one folder (`static/` in the examples) with a plain nginx directory listing. There is no frontend.
- Access is limited to the networks in `ALLOWED_LAN`.
- Files under `secured/` also need a secret key in the URL (`?key=...`), so scripts can fetch them without any login prompt.

## How it works

At start, [entrypoint.sh](entrypoint.sh) renders [nginx.conf.template](nginx.conf.template) from the environment variables below and starts nginx.

| Path | Who can access | Notes |
| :- | :- | :- |
| `/...` | clients in `ALLOWED_LAN` | Files and folder listings, with `Access-Control-Allow-Origin: *`. |
| `/secured/...` | clients in `ALLOWED_LAN` with `?key=<SECURED_KEY>` | No folder listings. |
| `/favicon.ico` | clients in `ALLOWED_LAN` | Built-in logo (see [Favicon](#favicon)). |

Requests for any host name other than `SERVER_NAME` get `403`.

## Configuration

| Variable | Required | Description |
| :- | :- | :- |
| `SERVER_NAME` | yes | Host name nginx answers to, e.g. `cdn.example.com`. It must match the host in the URL clients use. Other host names get 403. |
| `ALLOWED_LAN` | yes | Networks allowed to access the CDN, e.g. `192.168.99.0/24`. Separate several with spaces: `<net1> <net2>`. Everyone else gets 403. |
| `SECURED_KEY` | for `/secured/` | Secret key for files under `/secured/`: 32 to 128 characters, only `A-Z a-z 0-9 _ -`. Generate one with `openssl rand -hex 32`. If it is unset, `/secured/` is disabled (always 403). If it is invalid, the container refuses to start. |

The client IP is taken from the `X-Forwarded-For` header when a reverse proxy or ingress sets it. Otherwise nginx uses the connection's own IP.

**Important:** nginx trusts `X-Forwarded-For` from any source, so a client that reaches nginx directly could claim an address in `ALLOWED_LAN`. Make the container reachable only through your proxy or ingress.

## Folder layout

Mount your files at `/usr/share/nginx/html` (read-only is fine):

```
static/
├── images/logo.png          → /images/logo.png
├── docs/manual.pdf          → /docs/manual.pdf
└── secured/                 → needs ?key=
    └── reports/2026.pdf     → /secured/reports/2026.pdf?key=<SECURED_KEY>
```

## Setup with Docker Compose

1. Create the folder for your files:
   ```bash
   mkdir -p static/secured
   ```
2. Create `.env` with a key. `.env` is ignored by git:
   ```bash
   cp .env.example .env
   ```
   ```bash
   sed -i "s/^SECURED_KEY=.*/SECURED_KEY=$(openssl rand -hex 32)/" .env
   ```
3. In [docker-compose.yml](docker-compose.yml), set `SERVER_NAME` and `ALLOWED_LAN` for your network.
4. Start it:
   ```bash
   docker compose up -d
   ```
5. Open `http://<SERVER_NAME>:8888/` from a machine in `ALLOWED_LAN`.

[docker-compose.yml](docker-compose.yml) uses a published image tag. To run your local changes instead, build an image and put its name in `image:`:

```bash
docker build -t simple-cdn-service:local .
```

## Setup on Kubernetes

The manifests are not part of this repository. What the deployment needs:

- **Key in a Secret:** store `SECURED_KEY` in a Secret and reference it from the container's env:
  ```bash
  kubectl -n <namespace> create secret generic simple-cdn-service --from-literal=SECURED_KEY="$(openssl rand -hex 32)"
  ```
  Read the key back when your automations need it:
  ```bash
  kubectl -n <namespace> get secret simple-cdn-service -o jsonpath='{.data.SECURED_KEY}' | base64 -d
  ```
  ```yaml
  env:
    - name: SERVER_NAME
      value: cdn.example.com
    - name: ALLOWED_LAN
      value: "192.168.99.0/24"
    - name: SECURED_KEY
      valueFrom:
        secretKeyRef:
          name: simple-cdn-service
          key: SECURED_KEY
  ```
- **Files:** mount a volume (PVC, NFS, ...) with your files at `/usr/share/nginx/html`.
- **Service and ingress:** expose port `80` through a Service and an Ingress. Requirements:
  - The ingress host must equal `SERVER_NAME`.
  - The ingress must forward the client IP in `X-Forwarded-For`. Most ingress controllers (e.g. Traefik) do this by default.
  - The ingress itself must see the real client IP. With the default `externalTrafficPolicy: Cluster` on the ingress controller's LoadBalancer or NodePort Service, clients show up as node IPs and `ALLOWED_LAN` won't match them. Use `externalTrafficPolicy: Local` (or PROXY protocol).

## Using the CDN

```bash
curl -O "http://<SERVER_NAME>:8888/images/logo.png"
```

```bash
curl -O "http://<SERVER_NAME>:8888/secured/reports/2026.pdf?key=<SECURED_KEY>"
```

In HTML: `<img src="http://<SERVER_NAME>:8888/images/logo.png">`. Behind an ingress, use its URL instead, e.g. `https://<SERVER_NAME>/images/logo.png`.

### Secured files

- A missing or wrong key returns `403`. The key is case-sensitive.
- There is no directory listing under `/secured/`: folder URLs return `404` even with the key.
- To rotate the key, change `SECURED_KEY` and restart the container. Old URLs stop working.

**Note:** the key is part of the URL. This CDN's access log does not record it. Its error log does when the correct key is used from outside `ALLOWED_LAN`. Also, reverse proxies or ingress controllers in front of it, and browser history, may store full URLs. Treat a leaked URL as a leaked key and rotate it.

## Troubleshooting

| Symptom | Likely cause |
| :- | :- |
| `403` on every URL | The host in the URL is not `SERVER_NAME`, or your IP is not in `ALLOWED_LAN`. When testing on the Docker host itself, nginx sees the Docker network's gateway IP (e.g. `172.17.0.1`; Compose networks use their own), not your LAN IP. |
| `403` on `/secured/...` only | Missing, wrong or wrongly-cased `?key=`, or `SECURED_KEY` is not set (check the container log for a warning). |
| Container exits at start | `SECURED_KEY` is invalid (see [Configuration](#configuration)). The log says why without printing the key. |
| `404` on `/secured/folder/` | Expected: secured folders are never listed. Request a file. |

Check the logs:

```bash
docker compose logs cdn
```

## Favicon

The browser-tab icon is built into the image and always served at `/favicon.ico`; a `favicon.ico` in `static/` is ignored. The source is `assets/favicon.svg`. To regenerate `assets/favicon.ico` after editing it (needs `rsvg-convert` and ImageMagick):

```bash
for n in 16 32 48; do rsvg-convert -w $n -h $n assets/favicon.svg -o /tmp/fav$n.png; done && magick /tmp/fav16.png /tmp/fav32.png /tmp/fav48.png assets/favicon.ico
```

---
_Developed with assistance from Claude (Claude Opus 5.5)._
