#!/usr/bin/env bash
# Se ejecuta en la CONTROLADORA antes de desplegar; nunca publica claves privadas.
set -euo pipefail
if [[ $# -ne 5 ]]; then
  echo 'Uso: validate-postgres-certs.sh CA CERT KEY DNS IP' >&2
  exit 2
fi
CA="$1"; CRT="$2"; KEY="$3"; DNS="$4"; IP="$5"
for f in "$CA" "$CRT" "$KEY"; do
  [[ -f "$f" && -r "$f" ]] || { echo "Falta o no se puede leer: $f" >&2; exit 1; }
done
command -v openssl >/dev/null || { echo 'Falta openssl' >&2; exit 1; }
python3 - "$IP" <<'PY'
import ipaddress, sys
try:
    if ipaddress.ip_address(sys.argv[1]).version != 4:
        raise ValueError('IPv4 requerida')
except ValueError as exc:
    raise SystemExit(f'IP inválida del certificado: {exc}')
PY
# Vigencia mínima para evitar certificados a punto de caducar durante la defensa.
openssl x509 -in "$CRT" -checkend 604800 -noout >/dev/null || {
  echo 'Certificado caducado o caduca en menos de 7 dias' >&2; exit 1;
}
openssl x509 -in "$CA" -checkend 604800 -noout >/dev/null || {
  echo 'CA caducada o caduca en menos de 7 dias' >&2; exit 1;
}
openssl verify -purpose sslserver -CAfile "$CA" "$CRT" >/dev/null || {
  echo 'Certificado no firmado por la CA o no válido para servidor' >&2; exit 1;
}
# Exigir SAN DNS/IP explícitos, no únicamente coincidencia con CN.
SAN="$(openssl x509 -in "$CRT" -noout -ext subjectAltName)"
python3 - "$DNS" "$IP" "$SAN" <<'PY_SAN'
import re, sys
name, ip, san = sys.argv[1:]
dns_entries = re.findall(r'DNS:([^,\s]+)', san)
ip_entries = re.findall(r'IP Address:([^,\s]+)', san)
if name not in dns_entries:
    raise SystemExit('No existe SAN DNS exacto solicitado')
if ip not in ip_entries:
    raise SystemExit('No existe SAN IPv4 exacto solicitado')
PY_SAN
openssl x509 -in "$CRT" -noout -checkhost "$DNS" >/dev/null || {
  echo 'El hostname no coincide con el certificado' >&2; exit 1;
}
openssl x509 -in "$CRT" -noout -checkip "$IP" >/dev/null || {
  echo 'La IP no coincide con el certificado' >&2; exit 1;
}
# Validar que clave privada y certificado tienen idéntica clave pública.
PUB_CERT="$(openssl x509 -in "$CRT" -pubkey -noout | openssl pkey -pubin -outform DER | openssl dgst -sha256)"
PUB_KEY="$(openssl pkey -in "$KEY" -pubout -outform DER | openssl dgst -sha256)"
[[ -n "$PUB_CERT" && "$PUB_CERT" == "$PUB_KEY" ]] || {
  echo 'La clave privada no corresponde al certificado' >&2; exit 1;
}
# Exigir que la clave privada no esté abierta a grupo ni a otros.
MODE="$(stat -c '%a' "$KEY")"
(( (8#$MODE & 077) == 0 )) || { echo "Permisos inseguros para $KEY (usar chmod 600)" >&2; exit 1; }
echo 'OK: CA, vigencia, identidad SAN, clave coincidente y permisos certificados'
