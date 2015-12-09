# PostgreSQL and PostGIS in a Docker container


## About

This Docker project creates a PostgreSQL and PostGIS database server in a container on a suitable host machine. It is inspired by base image [mdillon/postgis](https://hub.docker.com/r/mdillon/postgis/~/dockerfile/) but includes syslog ~~and   [pg-barman](http://www.pgbarman.org/) which is an essential tool for database archive/backup/restore~~.

[2015-09-16 update]
pg-barman requires ssh server on both the live and backup database servers, thus making it unsuitable for postgresql server running as Docker container

With syslog, one could log to files and feed into feature-rich log analysis software like [Graylog2](https://www.digitalocean.com/community/tutorials/how-to-install-graylog2-and-centralize-logs-on-ubuntu-14-04),  [ELK stack](http://www.freeipa.org/page/Howto/Centralised_Logging_with_Logstash/ElasticSearch/Kibana), etc. in real time in *postgresql.conf*:

```
log_destination = 'stderr,syslog'
logging_collector = on
```

The base image Dockerfile uses [/docker-entrypoint.sh](https://github.com/docker-library/postgres/blob/master/docker-entrypoint.sh) as ENTRYPOINT

From the [base image README](https://hub.docker.com/_/postgres/):
> If you would like to do additional initialization in an image derived from this one, add one or more *.sql or *.sh scripts under /docker-entrypoint-initdb.d (creating the directory if necessary). After the entrypoint calls initdb to create the default postgres user and database, it will run any *.sql files and source any *.sh scripts found in that directory to do further initialization before starting the service.
>
>These initialization files will be executed in sorted name order as defined by the current locale, which defaults to en_US.utf8. Any *.sql files will be executed by POSTGRES_USER, which defaults to the postgres superuser. It is recommended that any psql commands that are run inside of a *.sh script be executed as POSTGRES_USER by using the --username "$POSTGRES_USER" flag. This user will be able to connect without a password due to the presence of trust authentication for Unix socket connections made inside the container.
>
>...
>
>If there is no database when postgres starts in a container, then postgres will create the default database for you. While this is the expected behavior of postgres, this means that it will not accept incoming connections during that time. This may cause issues when using automation tools, such as **docker-compose**, that start several containers simultaneously.

## Usage

* Create your *docker-compose.yml* file

```
postgis:
  # Either use autobuild image on Docker hub or build locally from Dockerfile:
  image: cheewai/postgis
  #build: .

  # Specify container name also ensures only one instance is started
  #name: postgis

  # Refer to https://hub.docker.com/_/postgres/ for other possibilities
  environment:
   - PGDATA=/var/lib/postgresql/data
   - POSTGRES_PASSWORD=
   #- POSTGRES_USER=postgres

  ports:
   - "5432:5432"

  volumes:
   # Mount your data directory so your database may be persisted
   - path/to/data/directory:/var/lib/postgresql/data
   #*** If you have no existing database, comment the following the first-run
   #*** Empty data directory triggers initdb to be run
   # Customize access control to overwrite the default
   #- path/to/pg_hba.conf:/var/lib/postgresql/data/pg_hba.conf:ro
   # Customize server tuning parameters to overwrite the default
   #- path/to/postgresql.conf:/var/lib/postgresql/data/postgresql.conf:ro
```

* Build the Docker image:

```
docker-compose -f docker-compose.yml build
```

* Run the newly built Docker image:

```
docker-compose -f docker-compose.yml up -d
```

## Production Use

* The default postgresql.conf is good enough for development but for production use, consider using [guided parameter tuning](http://pgtune.leopard.in.ua/)

* Plan for disaster.

> ~~Seriously consider [Barman](http://www.pgbarman.org/) first. Maybe it is adequate and superior to the other suggestions below~~

### Daily Backup

This repo includes a script, *dumpdb.sh* which is intended to be run by Postgresql admin user *postgres* inside the container. When executed, it dumps the roles, schema (including GRANT) and all databases as separate files suffixed with *yyyy-mm-dd*

You can schedule a nightly cron job to execute it using *docker exec*, e.g.

```
# Obviously /restore must be persisted outside the container
docker exec {DOCKER_NAME} su - postgres /runtime/dumpdb.sh /restore
```

You should consider storing the daily dumps to a different server.

To restore a specific database. This will wipe out all existing data:

```
docker exec -it {DOCKER_NAME} su - postgres
pg_restore -j4 --clean --create {dumpfile}
```

To restore every database, either drop all your databases first, or run a separate instance of postgresql container but pointing to an existing empty PGDATA_DIR directory.

```
pg_restore -j4 -d postgres {postgres_dumpfile}
psql -f {roles_sql}
grep GRANT {schema_sql} | psql
# Repeat for every dumpfile
pg_restore -j4 --clean --create {dumpfile}
```

### Continuous Archiving

First and foremost, read the official documentation for **Continuous Archiving and Point-in-Time Recovery** for your specific version of Postgresql.

> At all times, PostgreSQL maintains a write ahead log (WAL) in the pg_xlog/ subdirectory of the cluster's data directory. The log records every change made to the database's data files. This log exists primarily for crash-safety purposes: if the system crashes, the database can be restored to consistency by "replaying" the log entries made since the last checkpoint.

Make use of these settings in *postgresql.conf* to enable WAL archiving:

* wal_level = hot_standby
* archive_mode = on
* archive_command = 'rsync -a %p postgres@replica-host:/path/to/wal_archive/%f'

To delete old WAL archive using pg_archivecleanup, read  http://stackoverflow.com/questions/16943599/how-to-specify-cleanup-by-file-age-or-date-with-pg-archivecleanup

### High-availability

*postgresql.conf* has a section for replication. Refer to https://wiki.postgresql.org/wiki/Streaming_Replication
