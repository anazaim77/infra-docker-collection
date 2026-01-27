RESTORE BACKUP INTO MYSQL CONTAINER

Prereqs:
- Docker is running
- Backup file is in ./db_backups (example: ./db_backups/backup.sql)

1) Identify the MySQL container name
   docker compose ps

2) (Optional) Create the target database inside the container
   docker exec -it <mysql_container> mysql -uroot -p -e "CREATE DATABASE IF NOT EXISTS <db_name>;"

3) Restore the SQL file into the database
   docker exec -i <mysql_container> mysql -uroot -p <db_name> < ./db_backups/<backup_file>.sql

Notes:
- Replace <mysql_container>, <db_name>, and <backup_file> with your values.
- If the SQL file already contains CREATE DATABASE/USE statements, you can omit <db_name>:
  docker exec -i <mysql_container> mysql -uroot -p < ./db_backups/<backup_file>.sql
