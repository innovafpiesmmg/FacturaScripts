# Instalación Automatizada de FacturaScripts y pgAdmin4 en Ubuntu con PostgreSQL

Este script automatiza la instalación del sistema de gestión empresarial FacturaScripts y la herramienta de administración de bases de datos pgAdmin4 en un servidor Ubuntu (versiones LTS recomendadas como 20.04, 22.04). Configura un entorno completo con Apache, PHP (versión 8.1 por defecto), PostgreSQL como base de datos, pgAdmin4 en modo web, y descarga la última versión estable de FacturaScripts.

## Características

* Instala Apache2, PHP 8.1 (y extensiones necesarias), PostgreSQL (usando el repositorio oficial para versiones actualizadas).
* Instala pgAdmin4 (modo web) desde su repositorio oficial.
* Crea una base de datos y un usuario dedicado en PostgreSQL para FacturaScripts.
* Intenta configurar la autenticación `md5` en PostgreSQL para conexiones locales del usuario de FacturaScripts.
* Ajusta la configuración de PHP (`memory_limit`, `upload_max_filesize`, etc.).
* Descarga la última versión estable de FacturaScripts desde GitHub.
* Configura un Virtual Host básico en Apache para FacturaScripts.
* Establece los permisos de archivo necesarios para la aplicación web FacturaScripts.
* Reinicia los servicios necesarios (Apache, PostgreSQL).

## Requisitos Previos

* Un servidor con **Ubuntu** (preferiblemente LTS 20.04 o 22.04).
* Acceso al servidor con un usuario que tenga privilegios `sudo`.
* Conexión a internet en el servidor para descargar paquetes, claves GPG y FacturaScripts.

## Uso

1.  **Clonar el Repositorio (o Descargar el Script)**
    ```bash
    git clone <URL_DE_TU_REPOSITORIO_GIT>
    cd <NOMBRE_DEL_DIRECTORIO>
    ```
    O descarga el archivo `install_facturascripts_pgsql.sh` directamente.

2.  **¡IMPORTANTE! Editar la Contraseña de la Base de Datos**
    Abre el script `install_facturascripts_pgsql.sh` con un editor de texto (como `nano`) y **cambia la contraseña por defecto** en la variable `DB_PASSWORD`.
    ```bash
    nano install_facturascripts_pgsql.sh
    ```
    Busca la línea `DB_PASSWORD="tu_contraseña_muy_segura"` y reemplázala por una contraseña fuerte. Guarda los cambios (Ctrl+O, Enter, Ctrl+X en `nano`).

3.  **Dar Permisos de Ejecución**
    ```bash
    chmod +x install_facturascripts_pgsql.sh
    ```

4.  **Ejecutar el Script Principal con `sudo`**
    ```bash
    sudo bash install_facturascripts_pgsql.sh
    ```
    El script instalará todo el software necesario y configurará el entorno base. Espera a que finalice completamente.

5.  **Configurar pgAdmin4 (Post-Script)**
    Una vez que el script anterior haya terminado, ejecuta el siguiente comando para configurar el acceso web a pgAdmin4. Se te pedirá un email y una contraseña, que serán tus credenciales para entrar a pgAdmin.
    ```bash
    sudo /usr/pgadmin4/bin/setup-web.sh
    ```
    Sigue las instrucciones en pantalla. Cuando pregunte sobre configurar el servidor web, responde afirmativamente (`y`) para integrar pgAdmin con Apache.

6.  **Completar la Instalación Web de FacturaScripts**
    Abre tu navegador web y navega a la dirección IP de tu servidor (ej. `http://<IP_DEL_SERVIDOR>`).
    Sigue las instrucciones del asistente de instalación de FacturaScripts:
    * Selecciona **PostgreSQL** como tipo de base de datos.
    * Introduce los detalles de la base de datos configurados en el script:
        * Base de datos: `facturascripts_db`
        * Usuario: `facturascripts_user`
        * Contraseña: **La contraseña segura que estableciste en el paso 2.**
        * Host: `localhost`
        * Puerto: `5432`
    * Completa el resto de los pasos del asistente (creación del usuario administrador, etc.).

## Post-Instalación

* **Acceso a pgAdmin4:**
    * Accede a pgAdmin4 en tu navegador: `http://<IP_DEL_SERVIDOR>/pgadmin4`.
    * Inicia sesión con el email y contraseña que creaste durante el `setup-web.sh`.
    * Dentro de pgAdmin, necesitas añadir manually la conexión a tu servidor PostgreSQL local:
        * Click derecho en "Servers" -> Create -> Server...
        * Pestaña 'General': Dale un nombre (ej. `Local PostgreSQL`).
        * Pestaña 'Connection':
            * Host name/address: `localhost`
            * Port: `5432`
            * Maintenance database: `postgres` (o `facturascripts_db`)
            * Username: `facturascripts_user`
            * Password: **La contraseña segura que estableciste en el paso 2.**
        * Guarda la conexión. Ahora podrás administrar la base de datos de FacturaScripts desde pgAdmin.

* **Plugins de FacturaScripts:** Accede a tu instalación de FacturaScripts (`http://<IP_DEL_SERVIDOR>`) y utiliza el Marketplace integrado para instalar los plugins gratuitos o de pago que necesites.

* **Seguridad de PostgreSQL:** Revisa la configuración de `pg_hba.conf` para asegurarte de que los métodos de autenticación son los adecuados para tu entorno más allá de la configuración básica realizada por el script.

* **Configuración de Apache:** Si tienes un nombre de dominio, edita el archivo `/etc/apache2/sites-available/facturascripts.conf`, descomenta y ajusta la línea `ServerName`. Considera configurar HTTPS/SSL (Let's Encrypt es una buena opción gratuita) para asegurar tanto FacturaScripts como pgAdmin4. Reinicia Apache después de los cambios (`sudo systemctl restart apache2`).

## Contribuciones

Si encuentras errores o tienes sugerencias de mejora para el script, por favor abre un *Issue* o envía un *Pull Request*.

## Licencia

[Especifica aquí la licencia bajo la cual distribuyes el script, por ejemplo, MIT, GPL, etc. Si no estás seguro, MIT es una opción permisiva común.]
