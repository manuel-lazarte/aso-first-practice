# Auditoría adicional — ASO Tasks 3, 4 y 5

**Base consultada:** `manuel-lazarte/aso-first-practice`, `main` @ `5f2fb51d0fdd0d510d4828cb008d5468fd64748c`.

## Problemas observados y solución preparada (parche no publicado)

| Componente | Problema en base | Cambio en parche |
|---|---|---|
| Samba | `failed_when: false` sobre `pdbedit` confunde base corrupta con usuario ausente | Listado completo con retorno obligatorio; alta solo si falta; habilitar solo si bandera D |
| Firewall | Borra permisos generales que podrían pertenecer a terceros; usa `is_private` insuficiente | Comprobar exclusivamente redes RFC1918, no borrar reglas preexistentes; impedir despliegue si hay servicios globalmente publicados en zona |
| PostgreSQL | No verifica SAN/vigencia/firma/coincidencia de clave antes de copiar | Prevalidación local del certificado con OpenSSL y DNS/IP explícitos |
| PHP | Prueba HTTP publica y borra página en cada ejecución | Página de prueba declarativa y petición HTTP sin cambios |
| Automatización | Sin workflow de validación ni verificador final en `main` | GitHub Actions estático, unittest CIDR, verificador local de lectura |
| Documentación | README previo mezclaba alias e IP y auditoría antigua | README principal + guía de defensa con comandos separados |

## Comprobaciones posibles fuera de VMware

- PyYAML: estructura de los YAML nuevos y editados.
- Jinja2: compilación de las expresiones y plantillas incluidas.
- Bash `bash -n` de scripts.
- Pruebas unitarias de las redes CIDR permitidas y rechazadas.
- Validador TLS contra CA/certificado de prueba generado localmente.
- Integridad del ZIP.

No confundir análisis estático con verificación en openSUSE Leap 16.0.

## Pendiente de VM limpia

- Comprobar paquetes con `zypper search -s`, ejecutar `ansible-playbook --syntax-check` y `ansible-lint`.
- Correr `deploy.yml` desde la controladora hacia `ASO-Destino`.
- Demostrar PHP/Apache/phpMyAdmin, MariaDB, Samba, FTP y PostgreSQL remotos reales.
- Revisar SELinux, firewalld y certificado activo, reiniciar, medir idempotencia.
- Restaurar snapshot limpia y repetir.

## Git

El archivo ZIP solo contiene archivos a superponer sobre el repositorio existente. No crea commit ni PR; confirmar integración y ejecución de GitHub Actions después de publicar. No hacer force push.
