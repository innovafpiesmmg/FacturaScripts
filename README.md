# Instalación Automatizada de FacturaScripts con Docker y Docker Compose

Este script automatiza la instalación de Docker, Docker Compose y la configuración inicial de FacturaScripts utilizando Docker en sistemas operativos basados en Debian/Ubuntu (como Ubuntu 20.04/22.04, Debian 11/12).

**ADVERTENCIA:** Ejecuta este script bajo tu propia responsabilidad. Asegúrate de entender lo que hace antes de ejecutarlo en un sistema de producción.

## ¿Qué hace este script?

1.  **Verifica Privilegios:** Comprueba si se ejecuta con permisos de superusuario (`sudo`).
2.  **Actualiza el Sistema:** Ejecuta `apt-get update`.
3.  **Instala Dependencias:** Instala paquetes necesarios como `curl`, `gnupg`, `ca-certificates`, `lsb-release`.
4.  **Instala Docker:** Añade el repositorio oficial de Docker e instala Docker Engine (`docker-ce`, `docker-ce-cli`, `containerd.io`) si no está ya instalado.
5.  **Instala Docker Compose:** Instala el plugin `docker-compose-plugin` si no está ya instalado.
6.  **Crea Directorio:** Genera un directorio `facturascripts_docker` en el directorio `$HOME` del usuario que ejecuta el script con `sudo` (normalmente `/root/facturascripts_docker` si se ejecuta directamente como root, o `$HOME_DEL_USUARIO/facturascripts_docker` si se usa `sudo` desde un usuario normal).
7.  **Genera Archivo `.env`:** Crea un archivo `.env` dentro del directorio de instalación con contraseñas aleatorias y seguras para la base de datos MySQL. **¡Es crucial guardar este archivo!**
8.  **Crea `docker-compose.yml`:** Genera el archivo `docker-compose.yml` necesario para levantar los servicios de FacturaScripts y MySQL, leyendo la configuración de la base de datos desde el archivo `.env`.
9.  **Inicia Contenedores:** Ejecuta `docker compose up -d` para descargar las imágenes necesarias (FacturaScripts y MySQL) y lanzar los contenedores en segundo plano.
10. **Muestra Información Final:** Informa sobre la URL de acceso, la ubicación de los archivos de configuración y las contraseñas, y comandos básicos para gestionar los contenedores.

## Prerrequisitos

* Un sistema operativo basado en Debian/Ubuntu (ej. Ubuntu 20.04+, Debian 11+).
* Acceso a internet para descargar paquetes e imágenes Docker.
* Acceso `sudo` o como usuario `root`.

## Cómo Usar

1.  **Descarga el Script:** Guarda el contenido del script en un archivo, por ejemplo, `install_facturascripts.sh`.
    ```bash
    wget [URL_DEL_SCRIPT_SI_ESTA_ONLINE] -O install_facturascripts.sh
    # O copia y pega el contenido en un archivo nuevo
    # nano install_facturascripts.sh
    ```
2.  **Da Permisos de Ejecución:**
    ```bash
    chmod +x install_facturascripts.sh
    ```
3.  **Ejecuta con `sudo`:**
    ```bash
    sudo ./install_facturascripts.sh
    ```
4.  **Sigue las Instrucciones:** El script mostrará el progreso. Presta atención a la salida final.

## Post-Instalación

* **Acceso a FacturaScripts:** Abre tu navegador web y ve a la dirección IP de tu servidor seguida del puerto `8000` (o el puerto que hayas configurado en la variable `FACTURASCRIPTS_PORT` del script). Ejemplo: `http://TU_DIRECCION_IP:8000`.
* **Archivos de Configuración:** Los archivos `docker-compose.yml` y `.env` en `/root/facturascripts_docker/.env` se encuentran en el directorio de instalación (por defecto `$HOME/facturascripts_docker`).
* **Contraseñas:** Las contraseñas generadas para la base de datos MySQL (`MYSQL_ROOT_PASSWORD` y `MYSQL_PASSWORD`) se encuentran en el archivo `.env`. **¡GUARDA ESTE ARCHIVO EN UN LUGAR SEGURO!** Si lo pierdes, no podrás reconfigurar fácilmente la conexión a la base de datos.
* **Persistencia de Datos:** Los datos de FacturaScripts (plugins, archivos subidos) y de la base de datos MySQL se guardan en volúmenes de Docker (`facturascripts_data` y `mysql_data`), por lo que persistirán aunque detengas o reinicies los contenedores.

## Gestión de los Contenedores

Para gestionar los contenedores, navega al directorio de instalación (`cd $HOME/facturascripts_docker`) y usa los siguientes comandos `docker compose`:

* **Ver estado y logs:**
    ```bash
    sudo docker compose ps
    sudo docker compose logs -f # Muestra logs en tiempo real (Ctrl+C para salir)
    sudo docker compose logs facturascripts # Logs solo de FacturaScripts
    sudo docker compose logs mysql # Logs solo de MySQL
    ```
* **Detener los servicios:**
    ```bash
    sudo docker compose down
    ```
* **Iniciar los servicios (en segundo plano):**
    ```bash
    sudo docker compose up -d
    ```
* **Reiniciar los servicios:**
    ```bash
    sudo docker compose restart
    ```
* **Actualizar la imagen de FacturaScripts (cuando haya nuevas versiones):**
    ```bash
    sudo docker compose pull facturascripts # Descarga la última imagen
    sudo docker compose up -d --remove-orphans # Reinicia usando la nueva imagen
    ```

## Notas Importantes

* **Firewall:** Asegúrate de que el puerto especificado (`FACTURASCRIPTS_PORT`, por defecto 8000) esté abierto en el firewall de tu servidor para permitir conexiones entrantes. Por ejemplo, usando `ufw`: `sudo ufw allow 8000/tcp`.
* **Correo Electrónico:** La configuración para el envío de correos desde FacturaScripts está comentada en el archivo `docker-compose.yml`. Si necesitas esta funcionalidad, descomenta la línea `MAILER_URL` dentro de la sección `environment` del servicio `facturascripts`, edítala con tus datos SMTP y reinicia los contenedores (`sudo docker compose down && sudo docker compose up -d`).
* **Seguridad del `.env`:** El archivo `.env` contiene información sensible (contraseñas). Asegúrate de que los permisos del archivo sean restrictivos y guarda una copia de seguridad en un lugar seguro.


## Contribuciones

Si encuentras errores o tienes sugerencias de mejora para el script, por favor abre un *Issue* o envía un *Pull Request* en el repositorio [https://github.com/innovafpiesmmg/FacturaScripts](https://github.com/innovafpiesmmg/FacturaScripts).

## Licencia

Este proyecto se distribuye bajo la Licencia MIT. Consulta el archivo `LICENSE` para más detalles (o visita [https://opensource.org/licenses/MIT](https://opensource.org/licenses/MIT)).
