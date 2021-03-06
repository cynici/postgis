# PostgreSQL and PostGIS in a Docker container

## 2020-05-27 update

Due to work commitment, I may not catch up with latest versions timeously. So I recommend you do this:

- Switch to use the versatile official [postgis/postgis](https://hub.docker.com/r/postgis/postgis) image which offers many tagged combination of PostgreSQL and PostGIS versions
- If you need the `POSTGRES_UID` feature, grab my [set-postgres-uid.sh](set-postgres-uid.sh) and use it as your *docker-entrypoint*

This project creates a PostgreSQL and PostGIS database server in a Docker container. It is inspired by base image [mdillon/postgis](https://hub.docker.com/r/mdillon/postgis/~/dockerfile/) and includes rsyslog.

The tiny [postgres:alpine](https://hub.docker.com/_/postgres/) is not used as the base image because it is tricky to compile PostGIS in it.

With rsyslog, one could log to files and feed into feature-rich log analysis software like [Graylog2](https://www.digitalocean.com/community/tutorials/how-to-install-graylog2-and-centralize-logs-on-ubuntu-14-04), [ELK stack](http://www.freeipa.org/page/Howto/Centralised_Logging_with_Logstash/ElasticSearch/Kibana), etc. in real time in *postgresql.conf*:

```
log_destination = 'stderr,syslog'
logging_collector = on
log_directory = '/var/log/postgresql'
log_filename = 'postgresql-%Y%m%d-%H%M%S.log'
log_rotation_size = 1GB
log_rotation_age = 1d
log_min_duration_statement = 250ms
log_checkpoints = on
log_connections = on
log_disconnections = on
log_lock_waits = on
log_statement = 'ddl'
log_temp_files = 0
log_autovacuum_min_duration = 1000
```

## CAVEAT

- Beware of general consideration when running database server, https://www.2ndquadrant.com/en/blog/using-docker-hub-postgresql-images/
  - Specify volume explicitly to persist data
  - Do not use dm-thin/lvmthin backed storage driver for Docker
  - Don't use persisted data directory with a different image
  - Customize pg_hba.conf
  
- When upgrading from an existing database with an older release of PostGIS, be sure to read the upgrade instructions on https://postgis.net/install/ in case the instructions below are outdated.


```
ALTER EXTENSION postgis UPDATE;
ALTER EXTENSION postgis_topology UPDATE;

# or to specific version
ALTER EXTENSION postgis UPDATE TO "2.5.1";
ALTER EXTENSION postgis_topology UPDATE TO "2.5.1";
ALTER EXTENSION postgis_tiger_geocoder UPDATE TO "2.5.1";
```

## Docker entrypoint and custom initialization

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

Before you use the sample file below, read about:

- Mountpoint (docker volume) and `PGDATA` http://thebuild.com/blog/2018/03/27/mountpoints-and-the-single-postgresql-server/

- Full list of environment variables https://hub.docker.com/\_/postgres/ for other possibilities


### Create your *docker-compose.yml* file

```
version: '2.2'
services:
  db:
    image: cheewai/postgis
    environment:
      - PGDATA=/var/lib/postgresql/data
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
    restart: on-failure:5
```

### Initialize PostgreSQL database

When the container starts up, if *PGDATA* directory is empty, the bootstrapping script will run `docker-entrypoint.sh` to initialize PostgreSQL database.

The initialization script will also execute any additional bootstrapping scripts it finds in `/docker-entrypoint-initdb.d/` if this directory exists.  Subsequent runs of the container will ignore `/docker-entrypoint-initdb.d/`.

Check out the [base image](https://store.docker.com/images/postgres) documentation for details.


```
docker-compose -f docker-compose.yml up
```

When you see the database server ready message, you may stop the container and customise `postgres.conf` and `pg_hba.conf` in *PGDATA* directory.


## Optional. Set UID and GID of postgres user

By default, the postgres user in the Docker image is assigned some arbitrary numeric UID/GID i.e. 999, during package installation. By specifying the following environment variables to the same UID and GID of the user who runs `docker-compose`, the database files created will be owned the same user.
Add these lines with the appropriate indentation to your *docker-compose.yml*:

```
environment:
  - POSTGRES_UID={your_uid}
  - POSTGRES_GID={your_gid}
entrypoint: ["/set-postgres-uid.sh"]
```


## Known Issues/Errors

Refer to https://github.com/appropriate/docker-postgis#known-issues--errors


## Production Use

* The default postgresql.conf is good enough for development but for production use, consider using [guided parameter tuning](http://pgconfigurator.cybertec.at/). Or run [pgtune in a docker](http://imincik.blogspot.co.za/2016/08/automatic-postgresql-tuning-in-ansible.html).

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


## Upgrade database between major releases

Between upgrade between minor releases PostgreSQL, restarting the server using the new binaries should just work. For PostGIS, you can usually perform [soft upgrade](http://postgis.net/docs/postgis_installation.html#soft_upgrade) while the database is online.

It turns out that there several online approaches available but your mileage may vary:

* [PGLogical](https://2ndquadrant.com/en/resources/pglogical/)
* [Slony-I](http://slony.info/documentation/1.2/versionupgrade.html)
* [Skytool3 + PGQ + londiste3](https://blog.lateral.io/2015/09/postgresql-replication-with-londiste-from-skytools-3/)

This section refers specifically the most conservative approach to upgrade between major releases of either PostgreSQL or PostGIS. The bundled `pg_upgrade` is only good for vanilla PostgreSQL databases that do not use PostGIS extension. I haven't found a reliable way other than [hard upgrade](http://postgis.net/docs/postgis_installation.html#hard_upgrade) which requires the server to be offline during the upgrade. An outline of the steps involved:

* Dump roles, `pg_dumpall --roles-only -U postgres -f roles.sql`

* Dump individual database, `pg_dump -Fc -b -U postgres {db} -f {db}.dmp

* Start up an instance of the desired new version of PostgreSQL server
  * make sure `initdb` is executed
  * avail *roles.sql* and all the dump files in a mounted volume 

* Create roles, `psql -U postgres -f roles.sql`

* If your dump file is huge, consider changing your `postgresql.conf` temporarily to speed up the restore process, http://www.databasesoup.com/2014/09/settings-for-fast-pgrestore.html

* Create database and import from dump file. This script serves only as an example to be adapted according to your needs, particularly the path to `postgis_restore.pl`, the database encoding, locale, and PostGIS extensions.

```
#! /bin/bash
#
# - To be run as 'postgres' user inside container
# - /restore contains all the database dump files
# - /restore must be writable by 'postgres'

# where 'pg_dump -Fc -b -v' output is, named as {dbname}-*.dmp
DMPDIR="${DMPDIR:-/restore}"

cd $DMPDIR || {
  echo "DMPDIR '$DMPDIR' must point to existing directory where {dbname}-*.dmp is found" >&2
  exit 1
}

if [ $# -gt 0 ]; then
  _flist="$@"
  for _f in $_flist; do
    [ -f $_f ] || {
      echo "pg_dump file '$DMPDIR/$_f' not found" >&2
      exit 1
    }
  done
else
  _flist="$(echo *.dmp)"
fi

for _f in $_flist ; do
  _db="${_f%-*}"
  _dbuniq=$(echo $_db* | wc -l)
  [ $_dbuniq -eq 1 ] || {
    echo "More than one dmp file for '$_db' in $DMPDIR" >&2
    exit
  }
  createdb -E UTF8 --locale=en_ZA.UTF-8 $_db 
  _err=$?
  [ $_err -eq 0 ] || continue
  psql $_db -c "CREATE EXTENSION postgis;" 
  psql $_db -c "CREATE EXTENSION postgis_topology;"
  time /usr/share/postgresql/9.6/contrib/postgis-2.3/postgis_restore.pl $_f | psql $_db >"${DMPDIR}/restore-${_db}.log" 2>&1
done
```
