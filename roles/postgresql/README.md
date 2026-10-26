# Rol PostgreSQL para openSUSE Leap 16.0

Instala PostgreSQL, cliente, python313-psycopg2, php8-pgsql. Detecta el directorio
real de datos después del inicio con systemd; no ejecuta `initdb` sobre un cluster
existente ni elimina configuraciones de otros usuarios.

Crea `postgres` con contraseña protegida en Vault, `aso_user` y `aso_db`.
Activa TLS usando material generado en el controlador, y restringe el acceso en
pg_hba.conf a `postgresql_client_cidrs` por `hostssl ... scram-sha-256`.

Es obligatorio crear certificados locales en `secrets/postgres` (ignorado por
Git), con SAN que coincida con `postgresql_server_name` y la IP real. Ejecuta
`scripts/generate-postgres-lab-certs.sh aso-destino.local IP_ACTUAL`.

Se requiere demostrar desde otra máquina en el laboratorio:

```sh
PGPASSWORD='CLAVE_INTERACTIVA' psql 'host=aso-destino.local port=5432 dbname=aso_db user=aso_user sslmode=verify-full sslrootcert=secrets/postgres/ca.crt' -c 'SELECT ssl,version,cipher FROM pg_stat_ssl WHERE pid=pg_backend_pid();'
```

En ejecución real, no teclear secretos en comandos visibles ni guardarlos en el
historial: usar un `.pgpass` privado (0600) o `PGPASSWORD` leído de un gestor de
credenciales en el entorno de laboratorio.

El acceso TCP sin TLS se rechaza para la base/usuario manejados. El firewall
solo abre PostgreSQL desde CIDR privados declarados; no se admiten valores por
defecto. Se deben hacer pruebas reales en una VM limpia para completar Task 5.
