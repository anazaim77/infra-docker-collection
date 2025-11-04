# PostgreSQL + pgAdmin Stack

## Overview

This directory contains the Docker Compose configuration that brings up a PostgreSQL 15 instance together with pgAdmin 4. PostgreSQL data persists under `./data/postgres/`, pgAdmin metadata lives in the Docker named volume `pgadmin_data`, and optional SQL files in `./init-scripts/` can seed the database on first boot.

## Prerequisites

- Docker Engine 20.10 or later.
- Docker Compose plugin 2.x (or the legacy `docker-compose` v1.29+ binary).
- Sufficient disk space for the `data/` directory and any backups you produce.
- (Optional) Create `init-scripts/` for first-run SQL and `backups/` to store dumps; Docker will create them automatically if they do not exist.

## Configuration (`.env`)

All runtime settings live in `.env`:

- `POSTGRES_DB` – default database name to create on first startup.
- `POSTGRES_USER` / `POSTGRES_PASSWORD` – superuser credentials for PostgreSQL.
- `POSTGRES_PORT` – host port that forwards to PostgreSQL (`5432` inside the container).
- `PGADMIN_EMAIL` / `PGADMIN_PASSWORD` – pgAdmin login. Use non-personal accounts for shared environments.
- `PGADMIN_PORT` – HTTP port for pgAdmin (e.g. `8080`).
- `PGADMIN_PORT_SSL` – HTTPS port for pgAdmin (set this in `.env`, e.g. `8443`, if you need TLS access).
- `DATABASE_*` variables – convenience values for applications that need a connection string.

> Keep `.env` out of version control and rotate credentials when sharing or promoting to higher environments. Consider maintaining a checked-in `.env.example` containing safe defaults.

## Running the Stack

1. Review and update `.env` with the values you need (especially passwords and external ports).
2. Start the services:
   ```bash
   docker compose --env-file .env up -d
   # or: docker-compose --env-file .env up -d
   ```
3. Confirm the containers are healthy:
   ```bash
   docker compose ps
   docker compose logs -f postgres
   ```
4. Stop the stack when finished:
   ```bash
   docker compose down
   # add -v to drop the volumes if you intentionally want a clean slate
   ```

### Access Endpoints

- **PostgreSQL:** `localhost:${POSTGRES_PORT}` from the host, or `postgres:5432` from other containers on the Compose network.
- **pgAdmin:** `http://localhost:${PGADMIN_PORT}` for HTTP, `https://localhost:${PGADMIN_PORT_SSL}` if TLS is mapped.

Example `psql` command from the host:

```bash
PGPASSWORD="$POSTGRES_PASSWORD" psql -h localhost -p "$POSTGRES_PORT" -U "$POSTGRES_USER" -d "$POSTGRES_DB"
```

Within pgAdmin, add a new server connection that points to host `postgres`, port `5432`, and uses the credentials from `.env`.

## Directory Layout & Volumes

- `docker-compose.yml` – service definitions for PostgreSQL and pgAdmin.
- `.env` – runtime configuration (excluded from git via `.gitignore`).
- `data/postgres/` – PostgreSQL data directory (created on first run).
- `pgadmin_data` – Docker named volume holding pgAdmin configuration and user data. Inspect with `docker volume ls` / `docker volume inspect pgadmin_data`.
- `init-scripts/` – drop SQL scripts here (prefixed with numbers for ordering) to run once when the database volume is empty.
- `backups/` – suggested location for logical dumps (ensure it exists before writing backups).

> If you previously ran an older compose file that bound pgAdmin to `./data/pgadmin/`, it is now safe to delete that folder after copying out anything you still need.

## Adding a New Database

### Option 1 – via psql/CLI

```bash
docker compose exec postgres psql -U "$POSTGRES_USER" -c "CREATE DATABASE my_new_db TEMPLATE template0;"
```

Adjust ownership as needed:

```bash
docker compose exec postgres psql -U "$POSTGRES_USER" -d my_new_db -c "GRANT ALL ON DATABASE my_new_db TO your_app_user;"
```

### Option 2 – via `createdb`

```bash
docker compose exec postgres createdb -U "$POSTGRES_USER" my_new_db
```

### Option 3 – seed on first boot

Create an SQL file such as `init-scripts/02-create-my_new_db.sql` containing:

```sql
CREATE DATABASE my_new_db TEMPLATE template0;
```

Any script placed here executes only when the PostgreSQL volume is empty, which keeps reboots idempotent.

### Option 4 – via pgAdmin UI

1. Open pgAdmin and sign in.
2. Right-click **Databases → Create → Database**.
3. Provide the database name, owner, and encoding; save.

## Backups

> Store backups outside of `data/` and verify them regularly. The examples below assume you created a `backups/` folder next to the compose file.

### Single-database logical backup (SQL)

```bash
mkdir -p backups
docker compose exec postgres pg_dump -U "$POSTGRES_USER" "$POSTGRES_DB" \
  > backups/$(date +%Y%m%d-%H%M)_${POSTGRES_DB}.sql
```

### All databases logical backup

```bash
mkdir -p backups
docker compose exec postgres pg_dumpall -U "$POSTGRES_USER" \
  > backups/$(date +%Y%m%d-%H%M)_cluster.sql
```

### Custom-format backup (compress + parallel restore capable)

```bash
mkdir -p backups
docker compose exec postgres pg_dump -U "$POSTGRES_USER" -Fc "$POSTGRES_DB" \
  > backups/$(date +%Y%m%d-%H%M)_${POSTGRES_DB}.dump
```

### Physical backup (data directory)

> Only perform while the containers are stopped to avoid inconsistent state.

```bash
docker compose down
sudo tar -czf backups/postgres-data-$(date +%Y%m%d).tar.gz data/postgres
```

## Restoring

### Restore from SQL dump

Create the target database first (if it does not exist), then:

```bash
cat backups/20240101-1200_my_db.sql | \
  docker compose exec -T postgres psql -U "$POSTGRES_USER" -d my_db
```

### Restore from custom-format dump

```bash
cat backups/20240101-1200_my_db.dump | \
  docker compose exec -T postgres pg_restore -U "$POSTGRES_USER" -d my_db --clean --if-exists
```

### Restore from physical backup

1. Stop the stack: `docker compose down`.
2. Clear the existing data directory: `rm -rf data/postgres/*` (double-check the path!).
3. Extract the archive: `tar -xzf backups/postgres-data-YYYYMMDD.tar.gz -C data/postgres --strip-components=2`.
4. Start the stack again: `docker compose up -d`.

## Maintenance & Best Practices

- Rotate database and pgAdmin passwords routinely; prefer Docker secrets or environment-specific secret stores in production.
- Create separate database roles per application with only the privileges they require.
- Keep schema migrations in version control and apply them through automated pipelines.
- Monitor container health (`docker compose ps`, `docker compose logs`) and watch for `pg_isready` failures.
- Ensure host backups are copied off-machine and tested; automate recurring backup jobs where possible.
- Vacuum and analyze heavily-used databases (`VACUUM (ANALYZE)` or via scheduled maintenance tools).
- Keep Docker images up to date (`docker compose pull` followed by `docker compose up -d`).
- Limit network exposure by binding ports only where needed (adjust `.env` to avoid public interfaces).

## Troubleshooting

- **Container keeps restarting:** Check logs with `docker compose logs postgres`; invalid credentials or missing volumes commonly cause restarts.
- **Port already in use:** Update `POSTGRES_PORT`, `PGADMIN_PORT`, or `PGADMIN_PORT_SSL` in `.env` to free ports.
- **Permission denied on data directories:** Ensure the `data/postgres/` subtree is writable by Docker (adjust ownership/permissions on the host). The pgAdmin service now uses the named volume `pgadmin_data`, which avoids Linux UID/GID issues.
- **pgAdmin cannot reach PostgreSQL:** Verify the server entry uses host `postgres`, port `5432`, and that the database exists.
- **Healthcheck failing:** The database may still be applying migrations or waiting on init scripts; wait or inspect the logs for SQL errors.

## Useful Commands

```bash
# Tail PostgreSQL logs
docker compose logs -f postgres

# Run psql in the default database
docker compose exec postgres psql -U "$POSTGRES_USER" -d "$POSTGRES_DB"

# Remove dangling Docker volumes and images
docker system prune
```

With this setup you can iterate locally, attach additional services to the same network, and carry forward good PostgreSQL hygiene (strong credentials, regular backups, and tested restore procedures).
