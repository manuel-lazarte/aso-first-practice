# PostgreSQL para openSUSE Leap 16.0

Este rol conserva el despliegue del equipo, instala servidor/cliente, adaptador
Python y PHP PostgreSQL, activa TLS y añade reglas HBA por usuario y base.

## Requisitos privados

Antes de ejecutar: `group_vars/all/vault.yml` cifrado con
`vault_postgresql_admin_password` y `vault_postgresql_app_password`, y
`group_vars/all/lab.yml` con `postgresql_client_cidrs` reales y
`postgresql_server_name` y `postgresql_server_ip`. Generar la CA y el certificado SAN con
`scripts/generate-postgres-lab-certs.sh` desde la controladora. Los archivos
`secrets/postgres/*.key` deben permanecer excluidos del control de versiones.

## Aplicación

- Obtiene los parámetros con `SELECT current_setting('data_directory'),
  current_setting('hba_file')`, sin suponer rutas de Debian.
- Arranca la unidad `postgresql` empaquetada en openSUSE para el primer
  clúster. No ejecuta initdb destructivo si ya existen datos; exige PG_VERSION.
- Usa `community.postgresql.postgresql_alter_system` para configurar TLS,
  SCRAM y dirección de escucha, notificando reinicio solo cuando cambia algo.
- Crea `aso_user` sin privilegios administrativos y `aso_db`.
- Rechaza TCP sin TLS para el usuario gestionado, y admite conexiones TLS
  únicamente desde CIDR autorizados (más loopback para prueba local).
- Ejecuta comprobación local de `SHOW ssl`, sintaxis HBA, módulos PHP CLI y
  PDO TLS. Prueba extensiones PHP bajo Apache mediante archivo temporal que
  se elimina incluso cuando la prueba falla.

## Verificación desde un cliente de la red autorizada

Usar `.pgpass` privado con `chmod 600`, nunca contraseñas en línea de comandos:

```bash
bash scripts/check-postgres-tls.sh aso-destino.local
```

`sslmode=verify-full` debe autenticar certificado y nombre del servidor; el
script confirma `pg_stat_ssl.ssl = true` y prueba rechazo de SSL desactivado.
Para verificar cortafuegos revisar `firewall-cmd --list-all` en la zona activa.

**Pendiente:** comprobar con `zypper se -s` nombres de paquetes efectivos,
probar sobre la VM limpia, reiniciar y ejecutar dos veces (idempotencia).

## Validación predespliegue del certificado

Se llama `scripts/validate-postgres-certs.sh` ANTES de alterar PostgreSQL.
Valida vigencia, CA, SAN DNS/IP y correspondencia de clave pública/privada.
Rechaza llaves con permisos grupales o públicos. Ante cambio de IP/DNS,
regenerar certificados conscientemente (archivar los anteriores fuera del repo).
Una ejecución sin un certificado correcto se detiene antes de instalarlo.

La página `prueba.php` declarativa verifica PHP en Apache y las extensiones
`pgsql`/`pdo_pgsql` sin crear/borrar archivos temporales en cada ejecución.
