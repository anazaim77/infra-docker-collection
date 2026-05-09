# Docker

This project ships with a `Dockerfile` and `docker-compose.yml` for building and running 9Router in a container.

## Start with Docker Compose

```bash
docker compose up -d --build
```

This builds the local image if it does not already exist, then starts the app in the background.

The app listens on port `20128` in the container and is published on the host at the same port.

## View logs

```bash
docker compose logs -f
```

## Stop the stack

```bash
docker compose down
```

## What the volume does

The Compose file mounts:

```text
${HOME}/.9router:/app/data
```

and sets:

```text
DATA_DIR=/app/data
```

`9router` stores its database at `path.join(DATA_DIR, "db.json")`.
Without `DATA_DIR`, the app falls back to the current user's home directory (for example `~/.9router/db.json` on macOS/Linux). In the container, set `DATA_DIR=/app/data` so the bind mount is actually used.

With the Compose configuration above, the database file is:

```text
/app/data/db.json
```

and it is persisted on the host at:

```text
${HOME}/.9router/db.json
```

## Resource limits

The Compose service uses conservative runtime limits:

```text
cpus: 0.5
mem_limit: 256m
mem_reservation: 128m
```

These are intended to keep resource usage low while still leaving enough headroom for the app to start and serve requests reliably.

## Optional environment changes

If you want to change runtime settings such as `PORT`, `HOSTNAME`, or `DATA_DIR`, edit the `environment:` section in `docker-compose.yml` before starting the service.

## Build image manually

If you want to build the image without starting the container:

```bash
docker build -t 9router .
```

After rebuilding manually, you can start the service with:

```bash
docker compose up -d
```
