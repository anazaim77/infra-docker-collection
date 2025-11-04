# SQL Server 2022 Stack

## Overview

This directory provides a Docker Compose setup that launches Microsoft SQL Server 2022 (Developer edition by default). Data files, logs, secrets, and temporary backup media are mounted from local folders so that database state persists across container restarts. You can connect using any SQL Server–compatible client; DBeaver is a convenient cross-platform option.

## Prerequisites

- Docker Engine 20.10 or newer.
- Docker Compose plugin 2.x (or legacy `docker-compose` v1.29+ binary).
- x86_64 host with at least 2 vCPUs and 4 GB RAM available for the SQL Server container.
- Ensure the directories under this folder (`data/`, `log/`, `secrets/`, `temp_bu/`) are writable by Docker.

## Configuration (`.env`)

Key environment variables are defined in `.env`:

- `MSSQL_PASS` – SA password; must meet SQL Server complexity requirements.
- `USER_MSSQL_USERNAME` / `USER_MSSQL_PASS` – example application credentials (create the login in SQL Server after first boot).
- `SQLPAD_ADMIN` / `SQLPAD_ADMIN_PASSWORD` – placeholders if you wire this stack into SQLPad or similar tools.

> Keep `.env` out of version control and rotate credentials regularly. Consider tracking a `.env.example` with sanitized defaults if you need sharable configuration.

## Running the Stack

1. Review `.env` and update passwords or port mappings (`docker-compose.yml` exposes `14332` on the host by default).
2. Start SQL Server:
   ```bash
   docker compose --env-file .env up -d
   ```
3. Verify the container is healthy:
   ```bash
   docker compose ps
   docker compose logs -f mssql
   ```
4. Stop the container when finished:
   ```bash
   docker compose down
   # include -v only if you intentionally want to remove the named volumes
   ```

## Connecting from DBeaver

1. Install DBeaver and choose **Database → New Connection**.
2. Select **SQL Server** as the driver.
3. Use the following values:
   - **Server Host:** `localhost`
   - **Port:** `14332`
   - **Database:** leave blank or specify the database you want to open.
   - **Authentication:** SQL Server.
   - **Username:** `sa` (or another login you created).
   - **Password:** value of `MSSQL_PASS` from `.env`.
4. Test the connection and finish the setup. DBeaver stores connections locally so you can reconnect quickly.

You can also use `sqlcmd` if you prefer the CLI:

```bash
sqlcmd -S localhost,14332 -U sa -P 'P4ssw0rdMs5QL'
```

## Directory Layout

- `docker-compose.yml` – service definition for SQL Server with volume mounts.
- `.env` – runtime secrets and connection defaults.
- `data/` – stores MDF/NDF files.
- `log/` – stores LDF files.
- `secrets/` – placeholder for certificates or key files if required.
- `temp_bu/` – handy location for `.bak` files or scripted backups/restores.
- `.README` – quick notes/commands (left intact).

> SQL Server requires `data/`, `log/`, and `secrets/` to exist; Compose creates them automatically if missing, but verify permissions if the container fails to start.

## Restore & Backup Tips

- Place `.bak` files in `temp_bu/` and restore from inside the container:
  ```bash
  docker compose exec mssql /opt/mssql-tools/bin/sqlcmd \
    -S localhost -U sa -P "$MSSQL_PASS" \
    -Q "RESTORE DATABASE MyDb FROM DISK = N'/var/opt/mssql/temp_bu/MyDb.bak' WITH REPLACE;"
  ```
- To back up a database to the mounted folder:
  ```bash
  docker compose exec mssql /opt/mssql-tools/bin/sqlcmd \
    -S localhost -U sa -P "$MSSQL_PASS" \
    -Q "BACKUP DATABASE MyDb TO DISK = N'/var/opt/mssql/temp_bu/MyDb_$(date +%Y%m%d).bak' WITH INIT;"
  ```
- Copy files off the host regularly and test restores to ensure backups are valid.

## Maintenance Best Practices

- Keep Docker images current: `docker compose pull && docker compose up -d`.
- Create dedicated logins and limit privileges per application.
- Monitor container memory usage; SQL Server reserves significant RAM by default.
- Use `docker compose logs -f mssql` to track startup issues or failed restores.
- Automate backups and copy them to external storage.
- Update the `MSSQL_PID` value to `Express`, `Standard`, or `Enterprise` if you deploy beyond development (ensure licensing compliance).

With this Compose file and README, you can run SQL Server locally, interact via DBeaver or `sqlcmd`, and manage backups with persistent storage on the host machine.
