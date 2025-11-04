# MySQL + phpMyAdmin Stack

## Overview

This directory contains the Docker Compose configuration that spins up a MySQL 8 instance alongside phpMyAdmin. MySQL data persists under `./data/mysql/`, phpMyAdmin session data lives in the Docker named volume `phpmyadmin_data`, and optional SQL files in `./init-scripts/` can seed the database the first time the stack runs.

## Prerequisites

- Docker Engine 20.10 or later.
- Docker Compose plugin 2.x (or the legacy `docker-compose` v1.29+ binary).
- Enough disk space for the `data/` directory and any dumps you produce.
- (Optional) Create `init-scripts/` for bootstrap SQL and `backups/` to store dumps; Docker creates them automatically if missing.

## Configuration (`.env`)

All runtime values are declared in `.env`:

- `MYSQL_DATABASE` – default schema created on first boot.
- `MYSQL_USER` / `MYSQL_PASSWORD` – application user credentials.
- `MYSQL_ROOT_PASSWORD` – password for the MySQL root account.
- `MYSQL_PORT` – host port that forwards to MySQL (`3306` inside the container).
- `PHPMYADMIN_PORT` – host port for phpMyAdmin (default `80` inside the container).
- `DATABASE_*` variables – convenience values for applications needing a connection string.

> Keep `.env` out of version control and rotate credentials when collaborating. Consider providing a committed `.env.example` with safe defaults for teammates.

## Running the Stack

1. Review `.env` and update passwords and port mappings as needed.
2. Start the services:
   ```bash
   docker compose --env-file .env up -d
   # or: docker-compose --env-file .env up -d
   ```
3. Confirm the containers are healthy:
   ```bash
   docker compose ps
   docker compose logs -f mysql
   ```
4. Stop everything when finished:
   ```bash
   docker compose down
   # include -v to drop the named volumes if you intentionally want a clean slate
   ```

### Access Endpoints

- **MySQL:** `localhost:${MYSQL_PORT}` from the host, or `mysql:3306` from other containers on the Compose network.
- **phpMyAdmin:** `http://localhost:${PHPMYADMIN_PORT}`.

Example `mysql` client command from the host:

```bash
MYSQL_PWD="$MYSQL_PASSWORD" mysql -h localhost -P "$MYSQL_PORT" -u "$MYSQL_USER" "$MYSQL_DATABASE"
```

Within phpMyAdmin, create a new server connection pointing to host `mysql`, port `3306`, and use the credentials defined in `.env`.

## Directory Layout & Volumes

- `docker-compose.yml` – service definitions for MySQL and phpMyAdmin.
- `.env` – runtime configuration (kept out of git via `.gitignore`).
- `data/mysql/` – MySQL data directory (created on first run).
- `phpmyadmin_data` – Docker named volume that stores phpMyAdmin session data. Inspect with `docker volume inspect phpmyadmin_data`.
- `init-scripts/` – drop SQL files here (prefix with numbers for ordering) to run once when the MySQL data directory is empty.
- `backups/` – suggested location for logical or physical backups (create before use).

## Managing Databases & Users

### Create a Database via CLI

```bash
docker compose exec mysql mysql -u root -p"$MYSQL_ROOT_PASSWORD" -e "CREATE DATABASE my_new_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
```

Grant privileges to an application user:

```bash
docker compose exec mysql mysql -u root -p -e "GRANT ALL ON my_new_db.* TO '$MYSQL_USER'@'%'; FLUSH PRIVILEGES;"
```
> enter your root password

### Seed on First Boot

Create an SQL file such as `init-scripts/02-create-my_new_db.sql` containing:

```sql
CREATE DATABASE my_new_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
GRANT ALL ON my_new_db.* TO '${MYSQL_USER}'@'%';
```

Any script placed in `init-scripts/` executes only when the database volume is empty, which keeps reboots idempotent.

### Manage via phpMyAdmin

1. Open phpMyAdmin at `http://localhost:${PHPMYADMIN_PORT}`.
2. Sign in with `MYSQL_USER` / `MYSQL_PASSWORD` (or root credentials if needed).
3. Use the UI to create databases, tables, users, or import SQL dumps.

## Backups

> Store backups outside of `data/` and verify them regularly. The examples assume you created a `backups/` folder alongside the compose file.

### Logical Dump (single database)

```bash
mkdir -p backups
docker compose exec mysql mysqldump -u "$MYSQL_USER" -p"$MYSQL_PASSWORD" "$MYSQL_DATABASE" \
  > backups/$(date +%Y%m%d-%H%M)_${MYSQL_DATABASE}.sql
```

### Logical Dump (all databases)

```bash
mkdir -p backups
docker compose exec mysql sh -c 'mysqldump -u root -p"$MYSQL_ROOT_PASSWORD" --all-databases' \
  > backups/$(date +%Y%m%d-%H%M)_all_dbs.sql
```

### Physical Backup (data directory)

> Only perform while the containers are stopped to avoid inconsistent state.

```bash
docker compose down
sudo tar -czf backups/mysql-data-$(date +%Y%m%d).tar.gz data/mysql
```

## Restoring

### Restore from SQL Dump

Create the target database if necessary, then:

```bash
docker compose exec -T mysql mysql -u "$MYSQL_USER" -p"$MYSQL_PASSWORD" "$MYSQL_DATABASE" \
  < backups/20240101-1200_my_db.sql
```

### Restore All Databases

```bash
docker compose exec -T mysql mysql -u root -p"$MYSQL_ROOT_PASSWORD" \
  < backups/20240101-1200_all_dbs.sql
```

### Restore from Physical Backup

1. Stop the stack: `docker compose down`.
2. Clear the existing data directory: `rm -rf data/mysql/*` (double-check the path).
3. Extract the archive: `tar -xzf backups/mysql-data-YYYYMMDD.tar.gz -C data/mysql --strip-components=2`.
4. Start the stack again: `docker compose up -d`.

## Maintenance & Best Practices

- Rotate MySQL and phpMyAdmin passwords regularly; consider Docker secrets or external vaults in production.
- Create dedicated database users per application with minimal privileges.
- Keep schema migrations in version control and run them via automated processes.
- Monitor container health (`docker compose ps`, `docker compose logs`) and watch for failing health checks.
- Keep Docker images current (`docker compose pull` followed by `docker compose up -d`).
- Limit port exposure by adjusting `.env` so the services bind only where needed.
- Automate and test backups; copy them off-host to avoid single points of failure.

## Troubleshooting

- **Container keeps restarting:** Inspect logs with `docker compose logs mysql`; common issues include invalid credentials or missing volumes.
- **Port already in use:** Change `MYSQL_PORT` or `PHPMYADMIN_PORT` in `.env`.
- **Permission denied on data directories:** Ensure `data/mysql/` is writable by Docker; adjust ownership/permissions on the host as needed.
- **phpMyAdmin cannot reach MySQL:** Verify the connection points to host `mysql`, port `3306`, and uses valid credentials.
- **Healthcheck failing:** The database may still be initializing or applying scripts; check the MySQL logs for SQL errors.

## Useful Commands

```bash
# Tail MySQL logs
docker compose logs -f mysql

# Open an interactive MySQL shell
docker compose exec mysql mysql -u "$MYSQL_USER" -p"$MYSQL_PASSWORD" "$MYSQL_DATABASE"

# Clean up unused Docker objects
docker system prune
```

With this setup you can iterate locally, attach additional services to the same network, and follow good MySQL hygiene practices (strong credentials, frequent backups, and verified restores).
