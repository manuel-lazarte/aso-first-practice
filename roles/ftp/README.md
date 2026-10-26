# FTP en openSUSE Leap 16.0

Instala vsftpd y configura `usuario_ftp` sin acceso shell interactivo mediante
`/usr/sbin/nologin`. Para sistemas con PAM `pam_shells`, el rol registra
`/usr/sbin/nologin` en `/etc/shells`; una shell reconocida para FTP no
significa acceso shell funcional por SSH, ya que `nologin` lo niega.

El directorio raíz `/srv/ftp/usuario_ftp` lo administra root y no permite
escritura. Solo `subidas/` permite cargar archivos. El FTP anónimo está
prohibido en la plantilla Jinja `vsftpd.conf.j2` y solo la cuenta aprobada
puede autenticarse.

En SELinux se registran persistentemente `public_content_t` para la raíz y
`public_content_rw_t` para subidas. `ansible.posix.seboolean` habilita
`ftpd_anon_write` solo si existe; el nombre del booleano permite acceso al
tipo SELinux de escritura y **no** cambia `anonymous_enable=NO`.
No habilita el booleano excesivo `ftpd_full_access`.

Los puertos 21/TCP y 30000-30010/TCP solo deben estar abiertos desde los
CIDR privados de `lab_client_cidrs` en la zona `lab_firewall_zone`.

**ADVERTENCIA:** FTP sin TLS expone las credenciales. Debe utilizarse solo
sobre un enlace de laboratorio aislado (no Wi-Fi público ni Bridge compartido).
En otros entornos usar SFTP o FTPS autorizado por el docente.

La prueba funcional aún requiere conectar desde otra máquina: subir un archivo,
recuperarlo, intentar acceso anónimo y comprobar que el usuario no puede salir
de su chroot o iniciar una shell SSH interactiva.
