#!/usr/bin/env bash
# Verificacion de TLS remoto, desde la controladora con psql instalado.
# Requiere .pgpass privado (0600). No introducir password en linea de comandos.
set -euo pipefail
[[ $# -eq 1 ]] || { echo 'Uso: bash scripts/check-postgres-tls.sh DNS_SERVIDOR' >&2; exit 2; }
HOST="$1"
CA='secrets/postgres/ca.crt'
[[ -f "$CA" ]] || { echo "Falta $CA" >&2; exit 1; }
psql "host=$HOST port=5432 dbname=aso_db user=aso_user sslmode=verify-full sslrootcert=$CA"   -X -v ON_ERROR_STOP=1 -c 'SELECT ssl, version, cipher FROM pg_stat_ssl WHERE pid=pg_backend_pid();'
if psql "host=$HOST port=5432 dbname=aso_db user=aso_user sslmode=disable"   -X -v ON_ERROR_STOP=1 -c 'SELECT 1;' >/dev/null 2>&1; then
  echo 'ERROR: Conexion sin cifrado inesperadamente aceptada' >&2
  exit 1
else
  echo 'OK: conexion sin TLS rechazada'
fi
