#!/bin/sh
# Railway entrypoint for the Hyperswitch router.
# 1. Maps Railway Postgres variables (PGHOST, PGPORT, PGUSER, PGPASSWORD, PGDATABASE) onto every
#    database section the router reads (master, replica, accounts, global, analytics.sqlx),
#    unless a ROUTER__<SECTION>__* variable is already set.
# 2. Runs the v1 diesel migrations (idempotent; waits for Postgres to accept connections).
# 3. Fixes ownership of the uploads volume and execs the router as the unprivileged `app` user.
set -eu

: "${PGHOST:?PGHOST is required}"
: "${PGPASSWORD:?PGPASSWORD is required}"
PGPORT="${PGPORT:-5432}"
PGUSER="${PGUSER:-postgres}"
PGDATABASE="${PGDATABASE:-railway}"

for s in MASTER_DATABASE REPLICA_DATABASE ACCOUNTS_DATABASE GLOBAL_DATABASE ANALYTICS__SQLX; do
  for pair in "HOST:$PGHOST" "PORT:$PGPORT" "USERNAME:$PGUSER" "PASSWORD:$PGPASSWORD" "DBNAME:$PGDATABASE"; do
    k="${pair%%:*}"; v="${pair#*:}"; var="ROUTER__${s}__${k}"
    eval "cur=\${$var:-}"
    [ -n "$cur" ] || export "$var=$v"
  done
done

# Sensible defaults for a single-container deploy (each can be overridden with a Railway variable).
export ROUTER__SUPERPOSITION__ENDPOINT="${ROUTER__SUPERPOSITION__ENDPOINT:-http://127.0.0.1:1}"
export ROUTER__SUPERPOSITION__BACKUP_FILE_PATH="${ROUTER__SUPERPOSITION__BACKUP_FILE_PATH:-/local/config/superposition_seed.toml}"
export ROUTER__SUPERPOSITION__POLLING_INTERVAL="${ROUTER__SUPERPOSITION__POLLING_INTERVAL:-3600}"
export ROUTER__LOG__TELEMETRY__METRICS_ENABLED="${ROUTER__LOG__TELEMETRY__METRICS_ENABLED:-false}"
export ROUTER__LOG__TELEMETRY__TRACES_ENABLED="${ROUTER__LOG__TELEMETRY__TRACES_ENABLED:-false}"

DB_URL="${MIGRATION_DATABASE_URL:-postgresql://${PGUSER}:${PGPASSWORD}@${PGHOST}:${PGPORT}/${PGDATABASE}}"

if [ "${SKIP_MIGRATIONS:-false}" != "true" ]; then
  echo "[railway] running database migrations"
  i=0
  until diesel migration run --database-url "$DB_URL" --migration-dir /local/migrations --config-file /local/diesel.toml; do
    i=$((i + 1))
    if [ "$i" -ge 30 ]; then echo "[railway] migrations failed after $i attempts" >&2; exit 1; fi
    echo "[railway] migrations not applied yet (attempt $i), retrying in 5s"
    sleep 5
  done
  echo "[railway] migrations complete"
fi

if [ "$(id -u)" = "0" ]; then
  mkdir -p /local/bin/files
  chown -R app:app /local/bin/files 2>/dev/null || true
  exec setpriv --reuid=app --regid=app --init-groups "$@"
fi
exec "$@"
