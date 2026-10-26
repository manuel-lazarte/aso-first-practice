#!/usr/bin/env bash
# Genera una CA de laboratorio y un certificado PostgreSQL con SAN.
# Uso: ./scripts/generate-postgres-lab-certs.sh aso-destino.local 192.168.X.Y
set -euo pipefail
if [[ $# -ne 2 || ! "$1" =~ ^[a-zA-Z0-9.-]+$ || ! "$2" =~ ^[0-9.]+$ ]]; then
  echo 'Uso: bash scripts/generate-postgres-lab-certs.sh DNS_SERVIDOR IP_SERVIDOR' >&2
  exit 2
fi
DNS="$1"; IP="$2"; OUT='secrets/postgres'
if [[ -e "$OUT/ca.key" || -e "$OUT/server.key" ]]; then
  echo 'Certificados preexistentes: no se sobrescribiran.' >&2
  exit 1
fi
umask 077
mkdir -p "$OUT"
openssl req -x509 -newkey rsa:3072 -nodes -sha256 -days 365   -subj '/CN=ASO Local Lab CA'   -keyout "$OUT/ca.key" -out "$OUT/ca.crt"
openssl req -new -newkey rsa:3072 -nodes -sha256   -subj "/CN=$DNS" -keyout "$OUT/server.key" -out "$OUT/server.csr"
cat > "$OUT/san.ext" <<EOF
subjectAltName=DNS:$DNS,IP:$IP
extendedKeyUsage=serverAuth
keyUsage=digitalSignature,keyEncipherment
EOF
openssl x509 -req -in "$OUT/server.csr" -CA "$OUT/ca.crt" -CAkey "$OUT/ca.key"   -CAcreateserial -out "$OUT/server.crt" -days 365 -sha256 -extfile "$OUT/san.ext"
chmod 600 "$OUT"/*.key
openssl verify -CAfile "$OUT/ca.crt" "$OUT/server.crt"
openssl x509 -in "$OUT/server.crt" -noout -ext subjectAltName
