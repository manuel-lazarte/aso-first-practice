#!/usr/bin/env bash
# SOLO LECTURA. Ejecutar como root en ASO-Destino (ansible -m script -b).
set -euo pipefail
failures=0
check() { local label="$1"; shift; if "$@" >/dev/null 2>&1; then printf 'OK    %s\n' "$label"; else printf 'ERROR %s\n' "$label" >&2; failures=$((failures+1)); fi; }
command -v systemctl >/dev/null || { echo 'Este script requiere openSUSE con systemd.' >&2; exit 2; }
for s in apache2 mariadb smb vsftpd postgresql firewalld; do
  check "$s activo" systemctl is-active --quiet "$s"
  check "$s habilitado" systemctl is-enabled --quiet "$s"
done
check 'Apache HTTP 200' curl -fsS --max-time 10 http://127.0.0.1/
check 'PHP real por Apache, extensión PDO PGSQL' bash -c 'curl -fsS --max-time 10 http://127.0.0.1/prueba.php | grep -q PDO_PGSQL_OK'
check 'Extensiones PHP CLI' php -r 'exit(extension_loaded("pgsql") && extension_loaded("pdo_pgsql") ? 0 : 1);'
check 'Samba testparm' testparm -s
check 'Usuario Linux Samba' id usuario_samba
check 'Cuenta Samba' bash -c 'pdbedit -L | grep -q "^usuario_samba:"'
check 'Usuario FTP' id usuario_ftp
check 'Chroot FTP no escribible' test "$(stat -c '%U' /srv/ftp/usuario_ftp)" = root
check 'Subidas FTP asignadas a usuario' test "$(stat -c '%U' /srv/ftp/usuario_ftp/subidas)" = usuario_ftp
check 'MariaDB funcionando' mariadb-admin ping
check 'PostgreSQL funcionando' sudo -u postgres psql -Atqc 'SELECT 1'
check 'PostgreSQL SSL habilitado (configuración)' bash -c "[[ \$(sudo -u postgres psql -Atqc 'SHOW ssl') == on ]]"
check 'HBA sin errores de sintaxis' bash -c "[[ \$(sudo -u postgres psql -Atqc 'SELECT count(*) FROM pg_hba_file_rules WHERE error IS NOT NULL') == 0 ]]"
check 'SELinux en modo Enforcing' bash -c '[[ $(getenforce) == Enforcing ]]'
check 'Firewall activo' firewall-cmd --state
printf '\nPENDIENTE REMOTO: acceso phpMyAdmin/login; Samba escritura/máscaras; FTP transferencia/chroot; TLS verify-full, rechazo sin TLS, firewall desde clientes; segunda ejecución/snapshot.\n'
if (( failures > 0 )); then echo "Fallaron $failures verificaciones locales" >&2; exit 1; fi
echo 'Comprobaciones locales realizadas sin fallos (NO sustituye pruebas remotas).'
