# Rol FTP para openSUSE Leap 16.0

Este rol instala **vsftpd**, configura el servicio a partir de
`templates/vsftpd.conf.j2`, crea un usuario FTP dedicado, su directorio
`subidas/` y las reglas de firewall para el modo pasivo.

Para que funcione el chroot de vsftpd, `/srv/ftp/usuario_ftp` pertenece a
`root`, mientras que `subidas/` pertenece a `usuario_ftp`.

La variable `vault_ftp_password_hash` se guarda en
`group_vars/all/vault.yml` cifrado mediante **Ansible Vault**. Generar el
hash con `openssl passwd -6` en el controlador; NO guardar claves reales
ni hashes de contrasenas en el repositorio.

**Seguridad:** FTP sin TLS es para la practica de laboratorio dentro de una
red aislada. Las credenciales viajan sin cifrar. No publicar el servicio
en Internet; preferir SFTP o configurar FTPS con certificados validos.
