#! /bin/bash
#
# Use this wrapper script as Docker entrypoint to
# set the UID of postgres user.
#
# CAVEAT:
# - security risk if either value conflicts already in-use in the container
#
set -eu
_uid="${POSTGRES_UID:-}"
_gid="${POSTGRES_GID:-}"
if [ -n "$_uid" ] && [ -n "$_gid" ] ; then
    usermod -u $_uid postgres
    groupmod -g $_gid postgres
    chown -R -h ${_uid}:${_gid} /var/lib/postgresql
    chgrp -R -h ${_gid} /var/log/postgresql
    echo "postgres UID/GID set" >&2
else
    echo "Not setting UID/GID" >&2
fi
# Pass control to the default entrypoint script
exec /docker-entrypoint.sh $@
