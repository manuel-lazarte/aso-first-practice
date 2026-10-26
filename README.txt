# ASO - Task 3 y Task 4: LAMP, Samba y FTP con Ansible

Repositorio: https://github.com/manuel-lazarte/aso-first-practice
Sistema destino: openSUSE Leap 16.0 por SSH (VM remota).

## Requisitos
- Controlador con Ansible y VM destino openSUSE Leap 16.0.
- Acceso SSH por clave y privilegios sudo en la VM destino.
- Python 3 y repositorios de zypper disponibles en la VM.
- Colecciones Ansible de requirements.yml instaladas en el controlador.

## Archivos y roles
- deploy.yml: instala/configura firewall, Apache, PHP, MariaDB, phpMyAdmin,
  Samba y FTP en una ejecucion.
- playbook_ftp.yml: despliegue separado de FTP sin actualizar todo el SO.
- probar_samba.yml: despliegue separado de Samba.
- roles/apache/: pagina HTML de prueba y servicio Apache.
- roles/php/: modulo PHP para Apache y /prueba.php.
- roles/mariadb/: BD simulacion_db y usuario simulacion_user.
- roles/phpmyadmin/: instalacion y configuracion empaquetada para Apache.
- roles/samba/: usuario del sistema, usuario SMB, carpeta compartida y
  roles/samba/templates/smb.conf.j2 (create mask 0660; directory mask 0770).
- roles/ftp/: usuario usuario_ftp, carpeta subidas y vsftpd.conf.j2.
- roles/firewall/: firewalld y servicios SSH/HTTP. Roles Samba/FTP abren sus puertos.
- examples/vault.example.yml: marcadores de variables (sin contrasenas).

## Preparacion del controlador
1. Clonar el repositorio y entrar a la carpeta.
2. Instalar las colecciones en el controlador:
   ansible-galaxy collection install -r requirements.yml
3. Ajustar hosts con la IP destino. No publicar nombre de usuario o claves.
   Usar ssh-agent o ~/.ssh/config para configurar el acceso remoto por clave.
   Por ejemplo en ~/.ssh/config del controlador:
     Host 192.168.1.114
       User TU_USUARIO_SSH
       IdentityFile ~/.ssh/id_ed25519
4. Generar hash de contrasena para usuario_ftp EN EL CONTROLADOR:
   openssl passwd -6
   Introducir la clave cuando el comando la solicite y copiar el hash.
5. Preparar variables cifradas:
   mkdir -p group_vars/all
   ansible-vault create group_vars/all/vault.yml
   Escribir estas variables, con valores privados propios:
     vault_db_password: "CLAVE_MARIADB"
     vault_samba_password: "CLAVE_SAMBA"
     vault_ftp_password_hash: "HASH_GENERADO_CON_OPENSSL"
   Usar contrasenas distintas. group_vars/all/vault.yml NO debe versionarse.

## Despliegue remoto y repetibilidad
  ansible servidor -m ping --ask-vault-pass
  ansible-playbook deploy.yml --syntax-check --ask-vault-pass
  ansible-playbook deploy.yml -K --ask-vault-pass
  ansible-playbook deploy.yml -K --ask-vault-pass

La segunda ejecucion debe ser idempotente (sin cambios innecesarios).
No declarar la tarea terminada si queda algun host FAILED o UNREACHABLE.

## Verificacion en la VM destino
  sudo systemctl is-active apache2 mariadb smb vsftpd firewalld
  sudo testparm -s
  id usuario_samba
  sudo pdbedit -L -u usuario_samba
  ls -ld /srv/samba/compartido /srv/ftp/usuario_ftp /srv/ftp/usuario_ftp/subidas
  sudo mariadb -e "SHOW DATABASES;"
  sudo mariadb -e "SHOW GRANTS FOR 'simulacion_user'@'localhost';"

En otra maquina de la red de laboratorio:
- Apache: http://IP_DESTINO/
- PHP: http://IP_DESTINO/prueba.php
- phpMyAdmin: http://IP_DESTINO/phpMyAdmin/
- Samba: smbclient //IP_DESTINO/compartido -U usuario_samba
  Probar la subida/descarga y verificar create mask 0660 y directory mask 0770.
- FTP: curl -u usuario_ftp ftp://IP_DESTINO/
  Para subir: curl -u usuario_ftp -T archivo.txt ftp://IP_DESTINO/subidas/
  curl solicita la contrasena si no se especifica en la URL.

## Seguridad y limitaciones
- El inventario hosts no incluye usuarios ni contrasenas visibles.
- Conservar group_vars/all/vault.yml cifrado, ignorado por .gitignore.
- FTP aqui es SIN TLS, SOLO para laboratorio en red privada aislada: las
  contrasenas se transmiten en claro. Para uso real utilizar SFTP o FTPS.
- El usuario FTP usa una contrasena Linux hasheada (no guardar hash publico).
- La regla SSH se agrega antes de activar firewalld para conservar acceso.
- Este repositorio no demuestra por si mismo que el deploy haya funcionado:
  realizar las pruebas reales en openSUSE 16.0 con las VMs.
- Si existe SELinux activo y bloquea FTP/Samba, revisar AVCs y contextos;
  no desactivar la seguridad como solucion permanente.

## Task 4: GitHub
Los playbooks, roles, plantillas smb.conf.j2 y vsftpd.conf.j2 se versionan.
No incluir credenciales reales ni group_vars/all/vault.yml en ningun commit.
