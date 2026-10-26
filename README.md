# ASO: despliegue automatizado LAMP + Samba + FTP + PostgreSQL (openSUSE Leap 16.0)

**Repositorio existente**: manuel-lazarte/aso-first-practice. Incluye Tasks 3, 4 y
5. Los playbooks antiguos (`playbook.yml`, `playbook2.yml`, `playbook3.yml`) se
conservan como antecedente. **Ejecucion recomendada**: `deploy.yml`.

## 1. Infraestructura y prerrequisitos

- **Controladora:** openSUSE Leap 16.0 con Ansible Core y acceso a Internet
  para instalar colecciones. Ejecutar `sudo zypper in ansible openssh-clients openssl postgresql` si
  falta alguna herramienta y verificar nombres mediante `zypper search`.
- **Destino:** `ASO-Destino`, VM limpia openSUSE Leap 16.0 con OpenSSH y Python.
  No instalar LAMP/Samba/FTP/PostgreSQL manualmente en la VM de destino.
- Red de laboratorio confiable (preferir VMnet aislada); en bridge FTP sin TLS
  expone contrasenas a la LAN y **no debe usarse** sin aislamiento.
- Conservar una snapshot limpia de ASO-Destino. Los servicios se prueban alli;
  nunca confundir controladora y destino.

## 2. Preparar acceso SSH en la controladora

```bash
git clone https://github.com/manuel-lazarte/aso-first-practice.git
cd aso-first-practice
ansible-galaxy collection install -r requirements.yml
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519
ssh-copy-id ale@IP_ACTUAL_DESTINO
ssh ale@IP_ACTUAL_DESTINO
```

Copia `examples/hosts.example` a `hosts`, sustituye la IP. No pongas usuario
ni contrasena en `hosts`; configura `~/.ssh/config`, fuera del repositorio:

```sshconfig
Host aso-destino
  HostName IP_ACTUAL_DESTINO
  User ale
  IdentityFile ~/.ssh/id_ed25519
  StrictHostKeyChecking yes
```

El inventario se puede configurar como `[servidor]` seguido de
`aso-destino` (alias SSH). Usa `ssh-keyscan` solamente para consultar huellas;
verifica huella del servidor por un canal fiable antes de aceptarla. No
deshabilites `host_key_checking` ni uses login directo como root.

## 3. Configuracion privada y Vault

```bash
mkdir -p group_vars/all
cp examples/lab.example.yml group_vars/all/lab.yml
ansible-vault create group_vars/all/vault.yml
```

Edita `lab.yml` con la IP/CIDR **real** de la controladora (p.ej. /32) y
`postgresql_server_name` correspondiente al certificado (DNS o IP).
Para evitar que se olvide una red por defecto, `deploy.yml` exige
`lab_client_cidrs` y `postgresql_client_cidrs` **no vacios**. No usar
`0.0.0.0/0`; el firewall abrirá únicamente para esos clientes.

En `vault.yml` escribe valores reales para los nombres de
`examples/vault.example.yml`. Para FTP, usar `openssl passwd -6` y pegar el
hash resultante en `vault_ftp_password_hash` (nunca la contraseña en claro).
El archivo Vault y los certificados estan excluidos por `.gitignore`.

Genera una CA y un certificado con SAN para la IP y nombre actual de la VM:

```bash
bash scripts/generate-postgres-lab-certs.sh aso-destino.local IP_ACTUAL_DESTINO
openssl verify -CAfile secrets/postgres/ca.crt secrets/postgres/server.crt
```

Configura resolución del nombre `aso-destino.local` desde la controladora,
por ejemplo con `/etc/hosts` local, o usa un DNS confiable del laboratorio.
El nombre conectado al servidor debe coincidir con el SAN del certificado.

## 4. Desplegar y verificar

Desde el repositorio **en la controladora**, con sudo disponible en VM destino:

```bash
ansible servidor -m ping
ansible-playbook deploy.yml --syntax-check --ask-vault-pass
ansible-playbook deploy.yml --ask-vault-pass -K
```

Si falla un servicio: `journalctl -u NOMBRE_SERVICIO -n 100 --no-pager`,
`sudo ausearch -m avc -ts recent` y `sudo semanage fcontext -l` (sin desactivar
SELinux). En el destino:

```bash
systemctl is-enabled apache2 mariadb smb vsftpd postgresql
systemctl is-active apache2 mariadb smb vsftpd postgresql
getenforce
sudo testparm -s
sudo pdbedit -L -u usuario_samba
id usuario_samba; id usuario_ftp
ls -ldZ /srv/samba/compartido /srv/ftp/usuario_ftp/subidas
sudo -u postgres psql -Atqc 'SELECT datname FROM pg_database;'
sudo -u postgres psql -Atqc 'SHOW ssl;'
php -m | grep -Ei 'pgsql|pdo_pgsql'
```

Pruebas desde un cliente de la misma red privada:

```bash
curl -fsS http://IP_ACTUAL_DESTINO/
curl -fsS http://IP_ACTUAL_DESTINO/prueba.php
smbclient //IP_ACTUAL_DESTINO/compartido -U usuario_samba
curl -u usuario_ftp -T archivo.txt ftp://IP_ACTUAL_DESTINO/subidas/
curl -u usuario_ftp ftp://IP_ACTUAL_DESTINO/subidas/archivo.txt -o recibido.txt
bash scripts/check-postgres-tls.sh aso-destino.local
```

El script de PostgreSQL requiere un `.pgpass` privado (0600) en el equipo
cliente para `aso_user`. Debe mostrar una fila `ssl=t` y fallar el intento
con `sslmode=disable`. `verify-full` verifica la CA y el SAN del servidor.
`hostssl` y `SCRAM` son requisitos **distintos**: autenticación sola no cifra.

Probar permisos de Samba creando archivos y directorios mediante cliente
SMB, verificando `create mask = 0660` y `directory mask = 0770`. Verificar
acceso a phpMyAdmin en `http://IP_ACTUAL_DESTINO/phpMyAdmin/` (la ruta
exacta depende de la configuración empaquetada) e iniciar sesión.

## 5. Reinicio, idempotencia, defensa

- Ejecutar el playbook dos veces. La segunda ejecución no debe cambiar tareas
  que ya están en el estado esperado (exceptuando comprobaciones justificadas).
- Reiniciar SOLO la VM `ASO-Destino`, confirmar que los servicios vuelven.
- Restaurar la snapshot limpia, repetir el procedimiento y grabar evidencia.
- Mostrar comandos desde la controladora, `ansible servidor -m ping`, recap
  sin `FAILED` ni `UNREACHABLE`, accesos y archivos transferidos.

## 6. Diagnóstico y seguridad

- `Permission denied (publickey)`: corregir `ssh-copy-id`, usuario o permiso
  sobre la clave; no desactivar verificación SSH.
- `UNREACHABLE`/`Connection refused`: IP actual, bridge/NAT, sshd y firewall.
- Error sudo: ejecutar con `-K` o configurar privilegios controlados.
- `zypper` bloqueado: esperar proceso PackageKit; no matar transacciones.
- MariaDB: revisar `journalctl -u mariadb` y socket real de `mysql`.
- FTP 500 OOPS: comprobar propiedad root del chroot, `getenforce` y AVCs.
- Samba: validar `testparm`, usuario `pdbedit`, máscara y contexto SELinux.
- PostgreSQL: `sudo -u postgres psql -c 'SHOW config_file;'`, `SHOW hba_file;`,
  `SHOW ssl;`, `SELECT * FROM pg_hba_file_rules WHERE error IS NOT NULL;`;
  verificar SAN, CA y permisos 0600 de `server.key`.
- Sin `community.postgresql`: `ansible-galaxy collection install -r requirements.yml`.

**Atención:** FTP se mantiene sin TLS solo para laboratorios privados donde
la práctica lo requiere; en red Bridge compartida utilizar aislamiento o
configurar FTPS/SFTP. `firewalld` y SELinux **no** deben deshabilitarse.
No publicar certificados privados, Vault ni credenciales.

**Estado:** la revisión estática y los archivos no equivalen a haber probado
el despliegue en la VM. Task 3, Task 4 y Task 5 solamente se aprueban con
pruebas reales desde un snapshot limpio.
