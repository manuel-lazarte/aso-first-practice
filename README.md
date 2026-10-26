# ASO — Tasks 3, 4 y 5 (openSUSE Leap 16.0)

Repositorio académico grupal: `manuel-lazarte/aso-first-practice`. `deploy.yml` es el único playbook principal de despliegue. Los playbooks `playbook*.yml` y `probar_samba.yml` son prácticas antiguas/auxiliares y **no** sustituyen `deploy.yml`.

## Arquitectura y límites

| Equipo | Función | Instalaciones iniciales |
|---|---|---|
| `OpenSUSE16` | Controladora, Ansible y repositorio Git | Python, Ansible Core, SSH, OpenSSL, psql cliente |
| `ASO-Destino` | VM openSUSE Leap 16.0 limpia | SSH habilitado, Python, sudo y firewalld; sin instalaciones manuales de las tareas |

Tasks: **3:** Apache, PHP, phpMyAdmin, MariaDB, Samba y vsftpd; **4:** scripts/roles/templates reproducibles y sin secretos; **5:** PostgreSQL, biblioteca PHP, usuario/base y acceso remoto TLS con SCRAM. Se recomienda red virtual aislada para FTP sin cifrar. No expongas FTP en Bridge público o redes desconocidas.

## 1. Clonar y preparar la controladora

```bash
# Ejecutar en OpenSUSE16, NO en ASO-Destino.
git clone https://github.com/manuel-lazarte/aso-first-practice.git
cd aso-first-practice
ansible --version
ansible-galaxy collection install -r requirements.yml
```

Para validar paquetes en Leap 16.0 si hay errores de instalación: `zypper search -s` para `postgresql`, `postgresql-server`, `python313-psycopg2`, `php8-pgsql`, `policycoreutils-python-utils`, `python3-firewall`. **No se confirmó la instalación de esos paquetes en ASO-Destino desde ChatGPT.**

En ASO-Destino, abrir consola de VMware y comprobar `ip -br addr`, `systemctl is-active sshd`, `getenforce`. Guardar una snapshot limpia. No instalar servicios manualmente en el destino antes de Ansible.

## 2. SSH e inventario portable

En `OpenSUSE16`, obtener la IP actual de ASO-Destino de su consola, verificar huella SSH por canal confiable y configurar `~/.ssh/config` (privado):

```sshconfig
Host aso-destino
  HostName IP_ACTUAL_DESTINO
  User ale
  IdentityFile ~/.ssh/id_ed25519
  StrictHostKeyChecking yes
```

Si falta clave: `ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519` y `ssh-copy-id ale@IP_ACTUAL_DESTINO`. Luego `ssh aso-destino`. El archivo `hosts` del repositorio ya dice únicamente `[servidor]` y `aso-destino`; no lo sustituyas por el ejemplo con IP ficticia. Para cambiar de red (Bridge/Wi-Fi), actualiza **HostName en `~/.ssh/config`**, las listas CIDR privadas y el certificado si cambia la IP; **no** deshabilites comprobación de identidad SSH.

```bash
ansible-inventory -i hosts --graph
ansible servidor -m ping
```

## 3. Configuración privada, zona y Vault

```bash
mkdir -p group_vars/all
cp examples/lab.example.yml group_vars/all/lab.yml
# EDITAR lab.yml: zone, listas IPv4 RFC1918 /24 a /32, DNS y IP reales.
python3 scripts/validate-lab-cidrs.py 192.168.136.5/32
ansible-vault create group_vars/all/vault.yml
```

El ejemplo utiliza `192.0.2.x` **solo como marcador** y fallará hasta reemplazarlo. `lab_firewall_zone` debe ser la zona real de la interfaz en `firewall-cmd --get-active-zones`. No uses 0.0.0.0/0, direcciones públicas, loopback o redes demasiado amplias. El rol **no elimina** reglas generales de terceros: si encuentra aperturas globales, aborta para que un administrador las audite; inspecciona políticas/rich rules además de `list-services`/`list-ports`.

Crear en `group_vars/all/vault.yml` cifrado estas variables (valores propios, **nunca** en Git):

```yaml
vault_db_password: 'CLAVE_REAL_MARIADB'
vault_samba_password: 'CLAVE_REAL_SAMBA'
vault_ftp_password_hash: 'HASH_SHA512_CRYPT_DE_OPENSSL_PASSWD_6'
vault_postgresql_admin_password: 'CLAVE_REAL_POSTGRES'
vault_postgresql_app_password: 'CLAVE_REAL_ASO_USER'
```

Genera el hash con `openssl passwd -6` sin copiar claves reales a la consola/historial. El ejemplo `examples/vault.example.yml` incluye los nombres. `.gitignore` excluye Vault, `lab.yml`, `secrets/`, claves y certificados privados.

## 4. CA, certificado y PostgreSQL TLS

La IP y el DNS deben coincidir con `postgresql_server_ip` y `postgresql_server_name` de `lab.yml` y el SAN del certificado:

```bash
bash scripts/generate-postgres-lab-certs.sh aso-destino.local IP_ACTUAL_DESTINO
bash scripts/validate-postgres-certs.sh \
  secrets/postgres/ca.crt \
  secrets/postgres/server.crt \
  secrets/postgres/server.key \
  aso-destino.local IP_ACTUAL_DESTINO
```

El validador comprueba CA, vigencia mayor a siete días, SAN DNS/IP, correspondencia clave/certificado y permisos privados. No genera ni sobrescribe una clave ya existente. Si cambia DNS/IP, **archiva y reemplaza conscientemente** los certificados privados fuera del repo, ajusta DNS o `/etc/hosts` local y repite validación. `sslmode=verify-full` exige que el cliente resuelva `aso-destino.local` y confíe en `ca.crt`.

**PostgreSQL:** `roles/postgresql` conserva el clúster existente; usa el arranque empaquetado por openSUSE para inicializar cuando proceda, comprueba `PG_VERSION` y consulta rutas reales de PostgreSQL antes de modificar. Si falla el primer arranque, inspecciona `journalctl -u postgresql` y los paquetes, no ejecutes `initdb` sobre datos sin verificar. Configura HBA `hostssl`/`hostnossl`, usuario `aso_user` sin privilegios administrativos, base `aso_db`, y acceso limitado por CIDR. Verificación remota real es obligatoria.

## 5. Despliegue principal (solo OpenSUSE16)

```bash
ansible-galaxy collection install -r requirements.yml
ansible-inventory -i hosts --graph
ansible-playbook -i hosts deploy.yml --syntax-check --ask-vault-pass
ansible-playbook -i hosts deploy.yml --ask-vault-pass -K
```

La primera ejecución debe tener `failed=0` y `unreachable=0`. Cuando haya errores, corregir roles, no instalar manualmente en ASO-Destino. La segunda ejecución debe tener `changed=0` en recursos convergidos.

## 6. Verificación en ASO-Destino

El script es de **solo lectura** y debe ejecutarse con permisos root en el destino:

```bash
# Desde la CONTROLADORA: transmite el script de verificación a ASO-Destino.
ansible servidor -b -m script -a scripts/verify-deployment.sh
```

Comprueba servicios, cuentas, PostgreSQL/HBA, PHP por HTTP, firewall y SELinux. No sustituye la prueba de clientes remotos.

## 7. Pruebas remotas desde un cliente autorizado

```bash
curl -fsS http://IP_ACTUAL_DESTINO/
curl -fsS http://IP_ACTUAL_DESTINO/prueba.php
# Visitar http://IP_ACTUAL_DESTINO/phpMyAdmin/ y autenticar contra MariaDB.
smbclient //IP_ACTUAL_DESTINO/compartido -U usuario_samba
# Ejecutar desde smbclient: put archivo.txt; get archivo.txt; mkdir carpeta
curl -u usuario_ftp -T archivo.txt ftp://IP_ACTUAL_DESTINO/subidas/
curl -u usuario_ftp ftp://IP_ACTUAL_DESTINO/subidas/archivo.txt -o recibido.txt
cmp archivo.txt recibido.txt
bash scripts/check-postgres-tls.sh aso-destino.local
```

Para PostgreSQL, configura `~/.pgpass` (permisos 0600) del **cliente** con la contraseña real; no la pongas en argumentos visibles. `check-postgres-tls.sh` exige que `verify-full` funcione y que `sslmode=disable` sea rechazado **por reglas HBA**, no simplemente por un error DNS o de contraseña. MariaDB debe aceptar a `simulacion_user` y su base; Samba debe permitir subidas/descargas y aplicar máscaras (`create mask=0660`, `directory mask=0770`; son límites máximos). FTP debe rechazar anónimo, no permitir escape de chroot ni shell SSH para `usuario_ftp`. Inspecciona zona, rich rules, políticas y etiquetas SELinux sin deshabilitarlos.

## 8. Reinicio, snapshot e idempotencia

En ASO-Destino ejecutar `sudo reboot`. Tras reconexión, volver a ejecutar el verificador. En OpenSUSE16, ejecutar `ansible-playbook -i hosts deploy.yml -K --ask-vault-pass` una segunda vez. Comprobar qué tareas reportan `changed`; investigar si repiten sin cambios reales. Restaurar snapshot limpia y repetir el proceso como lo haría el docente.

## 9. Fallos frecuentes

- **SSH:** `Permission denied` → revisar llave/usuario/huella, nunca desactivar verificación. `UNREACHABLE` → IP actual, NAT/Bridge, sshd, firewall.
- **Zypper/PackageKit:** esperar a que termine la transacción; no matar procesos de paquetes.
- **Sudo:** usar `-K` y cuenta autorizada.
- **MariaDB:** `journalctl -u mariadb`; socket real en `SHOW VARIABLES LIKE 'socket';`.
- **Samba:** `testparm -s`, `pdbedit -L` y `pdbedit -Lv -u usuario_samba`; permisos/directorios/SELinux.
- **FTP:** error de chroot → raíz propiedad root no escribible, `/etc/shells`, PAM, `ausearch -m avc -ts recent`.
- **PostgreSQL:** `journalctl -u postgresql`, `SHOW ssl`, `SHOW hba_file`, `SELECT * FROM pg_hba_file_rules WHERE error IS NOT NULL`, SAN, permisos 0600 de key.
- **Firewall:** `firewall-cmd --get-active-zones`, `--zone=ZONA --list-all` y `--permanent --list-all`, además de `--list-policies`. Revisar cambios preexistentes, no borrarlos indiscriminadamente.

## 10. CI y guía de defensa

`.github/workflows/aso-static.yml` incluye comprobación YAML/Jinja/Bash, pruebas CIDR, `ansible-playbook --syntax-check` y ansible-lint en runner Ubuntu. **No prueba la instalación en openSUSE**. Si el workflow falla, revisar el log: no afirmar que CI pasó hasta verlo en GitHub. Ver `DEFENSA_ASO.md` y `AUDITORIA_FINAL.md` para guión, pendientes y matriz de cobertura.

**Estado honesto:** se preparó el código y se realizaron pruebas locales de formatos, CIDR y certificados. Sin acceso SSH real a las VMs, todavía no se ha probado el despliegue, SELinux, transferencia de archivos, TLS remoto, reinicio ni idempotencia de los servicios de openSUSE Leap 16.0.
