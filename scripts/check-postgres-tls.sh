#!/usr/bin/env bash
# Desde un cliente de la red autorizada, con .pgpass 0600 configurado.
set -euo pipefail
[[ $# -eq 1 ]] || { echo 'Uso: bash scripts/check-postgres-tls.sh DNS_SERVIDOR' >&2; exit 2; }
HOST="$1"
CA='secrets/postgres/ca.crt'
[[ -f "$CA" ]] || { echo "Falta CA privada de laboratorio: $CA" >&2; exit 1; }
command -v psql >/dev/null || { echo 'Falta psql en el cliente' >&2; exit 1; }
: "${PGPASSFILE:=$HOME/.pgpass}"
[[ -f "$PGPASSFILE" ]] || { echo 'Configura ~/.pgpass con permisos 0600 (no usar passwords en CLI).' >&2; exit 1; }
[[ $(stat -c %a "$PGPASSFILE") == 600 ]] || { echo 'chmod 600 ~/.pgpass' >&2; exit 1; }

printf '%s\n' '1) Comprobando CA, hostname y sesion TLS con verify-full...'
psql -w "host=$HOST port=5432 dbname=aso_db user=aso_user sslmode=verify-full sslrootcert=$CA" \
  -X -v ON_ERROR_STOP=1 -At \
  -c "SELECT CASE WHEN ssl THEN 'TLS_OK:' || version ELSE 'SIN_TLS' END FROM pg_stat_ssl WHERE pid=pg_backend_pid();" \
  | grep -q '^TLS_OK:' || { echo 'No se pudo confirmar TLS para esta conexion.' >&2; exit 1; }
echo 'OK: certificado verificado y conexion TLS confirmada'

printf '%s\n' '2) Probando que el servidor rechaza la misma cuenta sin TLS...'
if result=$(psql -w "host=$HOST port=5432 dbname=aso_db user=aso_user sslmode=disable" \
  -X -v ON_ERROR_STOP=1 -At -c 'SELECT 1' 2>&1); then
  echo 'FALLO: la conexion sin TLS fue ACEPTADA' >&2; exit 1
fi
if grep -Eqi 'pg_hba.conf rejects connection|no pg_hba.conf entry' <<< "$result"; then
  echo 'OK: acceso sin TLS rechazado por las reglas de PostgreSQL'
else
  echo 'No se pudo confirmar motivo HBA del rechazo; revisar error real:' >&2
  printf '%s\n' "$result" >&2
  exit 1
fi
