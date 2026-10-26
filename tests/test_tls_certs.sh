#!/usr/bin/env bash
set -euo pipefail
R="$(cd "$(dirname "$0")/.." && pwd)"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
(cd "$T" && bash "$R/scripts/generate-postgres-lab-certs.sh" db.lab.example 192.168.56.21 >/dev/null 2>&1)
CA="$T/secrets/postgres/ca.crt"
CERT="$T/secrets/postgres/server.crt"
KEY="$T/secrets/postgres/server.key"
bash "$R/scripts/validate-postgres-certs.sh" "$CA" "$CERT" "$KEY" db.lab.example 192.168.56.21
if bash "$R/scripts/validate-postgres-certs.sh" "$CA" "$CERT" "$KEY" incorrect.lab.example 192.168.56.21 >/dev/null 2>&1; then
  echo 'ERROR: validador aceptó DNS incorrecto' >&2; exit 1
fi
if bash "$R/scripts/validate-postgres-certs.sh" "$CA" "$CERT" "$KEY" db.lab.example 192.168.56.22 >/dev/null 2>&1; then
  echo 'ERROR: validador aceptó IP incorrecta' >&2; exit 1
fi
chmod 644 "$KEY"
if bash "$R/scripts/validate-postgres-certs.sh" "$CA" "$CERT" "$KEY" db.lab.example 192.168.56.21 >/dev/null 2>&1; then
  echo 'ERROR: validador aceptó clave pública' >&2; exit 1
fi
if (cd "$T" && bash "$R/scripts/generate-postgres-lab-certs.sh" db.lab.example 192.168.56.21 >/dev/null 2>&1); then
  echo 'ERROR: generador sobrescribió clave existente' >&2; exit 1
fi
echo 'OK: casos TLS positivos y negativos'
