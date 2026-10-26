# Guía de defensa — ASO Tasks 3, 4 y 5

## 0. Preparar dos VM y snapshot

- **OpenSUSE16**: controladora, donde se clona el repositorio y se ejecuta Ansible.
- **ASO-Destino**: VM limpia, destino. Antes de ejecutar, `ip -br addr`, `systemctl is-active sshd`, `getenforce`, y snapshot limpia en VMware. No instalar servicios manualmente en destino.
- En controladora, `ip -br addr`; comprobar IP de destino desde consola física de ASO-Destino (no usar IP antigua). La demostración debe mostrar ambas terminales identificadas.

## 1. GitHub y paquetes

En controladora:

```bash
git clone https://github.com/manuel-lazarte/aso-first-practice.git
cd aso-first-practice
git log -1 --oneline
ansible --version
ansible-galaxy collection install -r requirements.yml
```

Explicación: fuente única de roles y plantillas; el docente puede repetirla en cualquier VM limpia.

## 2. SSH/inventario (controladora)

Configurar `~/.ssh/config` con alias `aso-destino`, `HostName IP_ACTUAL_DESTINO`, `User ale`, `IdentityFile ~/.ssh/id_ed25519`, `StrictHostKeyChecking yes`. Verificar huella por canal confiable; ejecutar `ssh aso-destino` y luego:

```bash
ansible-inventory -i hosts --graph
ansible servidor -m ping
```

Explicación: claves privadas no publicadas; el inventario solo contiene alias.

## 3. Vault, red y certificado (controladora)

```bash
mkdir -p group_vars/all
cp examples/lab.example.yml group_vars/all/lab.yml
# editar lab.yml con CIDR privados actuales /24 a /32, zona e IP del destino
ansible-vault create group_vars/all/vault.yml
# agregar las cinco variables de examples/vault.example.yml con contraseñas reales
bash scripts/generate-postgres-lab-certs.sh aso-destino.local IP_ACTUAL_DESTINO
bash scripts/validate-postgres-certs.sh secrets/postgres/ca.crt secrets/postgres/server.crt secrets/postgres/server.key aso-destino.local IP_ACTUAL_DESTINO
```

Explicación: el secreto Vault y el certificado privado no entran en Git. La IP/DNS del certificado se comprueba en SAN; no se autogeneran claves durante despliegue.

## 4. Ejecución remota (controladora)

```bash
ansible-playbook -i hosts deploy.yml --syntax-check --ask-vault-pass
ansible-playbook -i hosts deploy.yml -K --ask-vault-pass | tee despliegue.log
```

Explicación: un playbook instala Apache, PHP, phpMyAdmin, MariaDB, Samba, FTP, PostgreSQL y firewall. Mostrar `PLAY RECAP` sin `failed` ni `unreachable`. Evitar registrar secretos en el log de demo; `no_log` protege tareas sensibles.

## 5. Estado local tras despliegue

```bash
ansible servidor -b -m script -a scripts/verify-deployment.sh
```

Mostrar servicios, cuentas del sistema, claves privadas restringidas y políticas SELinux. El script no modifica el servidor ni reemplaza las pruebas externas.

## 6. Pruebas desde cliente de laboratorio

```bash
curl -fsS http://IP_ACTUAL_DESTINO/
curl -fsS http://IP_ACTUAL_DESTINO/prueba.php
# en navegador: ingresar a phpMyAdmin y autenticar contra MariaDB
smbclient //IP_ACTUAL_DESTINO/compartido -U usuario_samba
# en smbclient: put archivo.txt; get archivo.txt; mkdir carpeta
curl -u usuario_ftp -T archivo.txt ftp://IP_ACTUAL_DESTINO/subidas/
curl -u usuario_ftp ftp://IP_ACTUAL_DESTINO/subidas/archivo.txt -o recibido.txt
cmp archivo.txt recibido.txt
bash scripts/check-postgres-tls.sh aso-destino.local
```

Guardar resultados: UID, modos octales para archivos Samba `0660` y directorios `0770` (las máscaras son máximos, no necesariamente exactos), rechazo de FTP anónimo, rechazo acceso SSH para usuario_ftp, SSL verificado y `hostnossl reject`. Mostrar `getenforce` y `firewall-cmd --zone=ZONA --list-all`.

## 7. Reinicio/idempotencia/snapshot

En ASO-Destino: `sudo reboot`; una vez accesible, repetir script. En controladora ejecutar el playbook otra vez y comprobar `changed=0` en tareas convergidas. Restaurar snapshot limpia y repetir instalación. Si falla cualquier paso, dejar evidencia y corregir el rol, nunca instalarlo manualmente solo para simular que funciona.
