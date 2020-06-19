#!/usr/bin/env bash
#
# Use this wrapper script as Docker entrypoint to set the UID and GID
# of postgres user in container to fix data files owner
#
# CAVEAT:
# - security risk if either value conflicts already in-use in the container
#
set -eux
_uid="${POSTGRES_UID:-}"
_gid="${POSTGRES_GID:-}"
_home="${PGDATA:-/var/lib/postgresql}"
if [ -n "$_uid" ] && [ -n "$_gid" ] ; then
    if [ -x "/usr/sbin/usermod" ]; then
        usermod -u $_uid postgres
        groupmod -g $_gid postgres
        chown -R -h ${_uid}:${_gid} ${_home}
        # TODO: log directory may vary from the default
        chgrp -R -h ${_gid} /var/log/postgresql
    else
        deluser postgres
        addgroup -g ${_gid} postgres
        adduser -u ${_uid} -G postgres -s /bin/bash --home ${_home} -D postgres
    fi
    echo "postgres UID/GID set" >&2
else
    echo "Not setting UID/GID" >&2
fi
# When $1=postgres, the default entrypoint script does something wonderful
if [ -z "${1:-}" ] || [ "${1:0:1}" = '-' ]; then
    set -- postgres "$@"
fi
# Pass control to the default entrypoint script
exec /usr/local/bin/docker-entrypoint.sh "$@"
