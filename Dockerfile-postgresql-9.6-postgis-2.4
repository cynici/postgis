FROM postgres:9.6
LABEL maintainer "Cheewai Lai <clai@csir.co.za>"

# Subscribe to pgsql-pkg-debian@postgresql.org for release announcements
# and watch https://github.com/docker-library/postgres Dockerfile
ARG POSTGIS_MAJOR=2.4

ARG DEBIAN_FRONTEND=noninteractive
ENV LANG en_ZA.UTF-8
ENV LANGUAGE en_ZA.UTF-8

RUN apt-get update \
&& apt-get install -y --no-install-recommends \
 postgis \
 postgresql-$PG_MAJOR-postgis-$POSTGIS_MAJOR \
 postgis-$POSTGIS_MAJOR \
 locales \
 rsyslog \
 curl \
 wget \
 pgbouncer \
&& curl -sSL https://dl.2ndquadrant.com/default/release/get/deb | bash \
&& apt-get update \
&& apt-get install -y --no-install-recommends postgresql-$PG_MAJOR-pglogical \
&& sed -i -e 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen \
&& sed -i -e 's/# en_ZA.UTF-8 UTF-8/en_ZA.UTF-8 UTF-8/' /etc/locale.gen \
&& echo 'LANG="en_ZA.UTF-8"'>/etc/default/locale \
&& dpkg-reconfigure locales \
&& update-locale LANG=en_ZA.UTF-8 \
&& dpkg-reconfigure locales \
&& rm -rf /var/lib/apt/lists/*

# Optional entrypoint script to set UID/GID of postgres user
ADD set-postgres-uid.sh /set-postgres-uid.sh
