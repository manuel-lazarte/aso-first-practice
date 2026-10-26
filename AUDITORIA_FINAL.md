# Auditoría técnica — corrección final ASO 3, 4 y 5

Base inspeccionada: `manuel-lazarte/aso-first-practice`, rama `main`,
commit `2f4a656a93b40138da26a1fd6b44aa0e79fef71c`.

## Cambios preparados (parche sobre repositorio existente)

| Archivo | Resultado |
|---|---|
| `hosts` | Host portable `aso-destino`, sin IP fija ni secreto |
| `examples/lab.example.yml` | Zona y CIDR configurables; ejemplo sin datos reales |
| `roles/firewall/tasks/main.yml` | Validación de CIDR privados, zona activa, SSH persistente, supresión de aperturas generales en zona gestionada |
| `roles/ftp/tasks/main.yml` | Cuenta nologin, PAM, SELinux correcto, etiquetas y escritura restringida |
| `roles/samba/tasks/main.yml` | Relabel al crear o actualizar el recurso compartido |
| `roles/postgresql/tasks/main.yml` | `postgresql_alter_system`, detección real del HBA, TLS/HBA, PHP/PDO y prueba HTTP efímera |
| `requirements.yml` | Rangos de colección compatibles, sin introducir módulos desactualizados |
| `scripts/check-postgres-tls.sh` | `verify-full` y rechazo sin SSL distinguiendo error HBA |
| `roles/postgresql/README.md`, `README.md` | Despliegue, seguridad y pruebas de defensa documentados |

## Matriz de aceptación

| Requisito | Estado |
|---|---|
| T3 LAMP y MariaDB | Implementado, pendiente de VM |
| T3 Samba, máscaras y FTP | Implementado, pendiente de transferencia real |
| T3 acceso SSH, firewall, SELinux | Revisado en código, pendiente de red/VM |
| T4 scripts, roles, templates, README | Preparado en parche; pendiente de commit/push |
| T5 PostgreSQL, usuario y BD | Implementado en código, pendiente de VM limpia |
| T5 acceso TLS y restricción HBA | Implementado, pendiente de conexión remota |
| T5 PHP PostgreSQL | Implementado en código, pendiente de acceso real HTTP/PDO |
| Reinicio e idempotencia | Pendiente de dos ejecuciones y snapshot limpia |

## Qué falta demostrar en la VM openSUSE16

1. Verificar versión real de Ansible, `ansible-galaxy` y paquetes Zypper.
2. Configurar `~/.ssh/config` con IP actual de ASO-Destino y llave SSH.
3. Crear `group_vars/all/lab.yml`, `vault.yml` cifrado y certificados TLS.
4. Ejecutar `ansible-playbook deploy.yml --syntax-check --ask-vault-pass`.
5. Ejecutar despliegue real y registrar `PLAY RECAP` sin fallos.
6. Comprobar HTML, PHP, phpMyAdmin, MariaDB y SMB/FTP con transferencia.
7. Verificar SSL con `scripts/check-postgres-tls.sh`, SQL y PHP/PDO.
8. Comprobar SELinux y zona firewalld, reiniciar, repetir playbook y snapshot.

## Bloqueos y límites

- Sin acceso SSH a VMware: **ningún despliegue funcional se ha ejecutado**.
- Sin Ansible instalado en el entorno de creación: `ansible-playbook --syntax-check`
  y `ansible-lint` se dejan para la controladora.
- La escritura de GitHub por conector ha devuelto 403; utilizar una rama local,
  `git add`, `git commit`, `git push`, PR y aprobación de equipo.
- FTP sin TLS debe permanecer únicamente en red de laboratorio aislada.
- La compatibilidad precisa con políticas SELinux y paquetes de Leap 16.0
  requiere comprobación de repositorios y políticas en la VM real.
