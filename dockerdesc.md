> Source code, full documentation and issues: https://github.com/AceRodnel14/simple-cdn-service

# simple-cdn-service

A minimal static-file CDN built on nginx. It serves files from a mounted folder with a plain directory listing; there is no frontend.

- Access is limited to the networks in `ALLOWED_LAN`.
- Files under `/secured/` also need a secret key in the URL (`?key=...`), so scripts can fetch them without any login prompt.

## Quick start

```yaml
services:
  cdn:
    image: eacer/simple-cdn-service:latest
    ports:
      - "8888:80"
    environment:
      SERVER_NAME: cdn.example.com
      ALLOWED_LAN: 192.168.99.0/24
      SECURED_KEY: ${SECURED_KEY:-}   # set in .env, generate with: openssl rand -hex 32
    volumes:
      - ./static:/usr/share/nginx/html:ro
```

```bash
curl -O "http://cdn.example.com:8888/images/logo.png"
```

```bash
curl -O "http://cdn.example.com:8888/secured/reports/2026.pdf?key=<SECURED_KEY>"
```

## Configuration

| Variable | Description |
| :- | :- |
| `SERVER_NAME` | Host name(s) nginx answers to, space-separated (e.g. `cdn.example.com cdn2.example.com`). Other hosts get 403. |
| `ALLOWED_LAN` | Space-separated networks allowed to access the CDN. Everyone else gets 403. |
| `SECURED_KEY` | Key for `/secured/`: 32 to 128 characters of `A-Z a-z 0-9 _ -`, case-sensitive. If it is unset, `/secured/` always returns 403. If it is invalid, the container refuses to start. |

- **Port:** `80` (plain HTTP; put TLS on your reverse proxy or ingress).
- **Volume:** mount your files at `/usr/share/nginx/html` (read-only is fine). Files in its `secured/` subfolder need the key.
- **Client IP:** taken from `X-Forwarded-For`, which nginx trusts from any source. Expose the container only through your proxy or ingress.
- **Kubernetes:** set `SECURED_KEY` from a Secret.

## Tags and architectures

- `latest`: the most recent build (normally `main`).
- `main`, `main-<yymmddHHMMSS>`: builds of the default branch; the timestamped tag pins one build.
- `vX.Y`, `vX.Y.Z`: releases, when tagged.
- Architectures: `linux/amd64`, `linux/arm64`.
