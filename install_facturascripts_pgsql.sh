#!/bin/bash

# Script para instalar FacturaScripts y pgAdmin4 en Ubuntu usando PostgreSQL
# Incluye: Apache2, PHP, PostgreSQL, pgAdmin4 (web mode) y el núcleo de FacturaScripts.
# ¡IMPORTANTE!: Ejecuta este script con sudo: sudo bash install_facturascripts_pgsql.sh

# --- Configuración ---
DB_NAME="facturascripts_db"
DB_USER="facturascripts_user"
# ¡¡CAMBIA ESTA CONTRASEÑA POR UNA SEGURA!!
DB_PASSWORD="tu_contraseña_muy_segura"
INSTALL_DIR="/var/www/facturascripts" # Directorio final de instalación
APACHE_CONF_FILE="/etc/apache2/sites-available/facturascripts.conf"
PHP_VERSION="8.1" # Puedes ajustarla si necesitas otra versión compatible (>=7.4)
DOWNLOAD_URL="https://facturascripts.com/DownloadBuild/1/stable" # URL oficial de descarga

# --- Inicio del Script ---

# Detener en caso de error (excepto en la creación de DB/User si ya existen)
# set -e # Se comenta temporalmente o se manejan errores específicos

echo "--- Iniciando la instalación de FacturaScripts y pgAdmin4 con PostgreSQL ---"

# 1. Actualizar repositorios e instalar dependencias básicas
echo ">>> 1/10: Actualizando paquetes e instalando dependencias básicas..."
sudo apt update
# Asegúrate de que software-properties-common y curl están instalados
# Añadido imagemagick como dependencia para php-imagick
sudo apt install -y software-properties-common curl ca-certificates gnupg imagemagick

# 2. Añadir repositorio y clave GPG de PostgreSQL (Asegura la última versión)
echo ">>> 2/10: Configurando repositorio oficial de PostgreSQL..."
# Crear archivo de fuente si no existe
sudo sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'
# Importar la clave GPG del repositorio
wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -
sudo apt update # Actualizar de nuevo tras añadir el repo

# 3. Añadir repositorio y clave GPG de pgAdmin4
echo ">>> 3/10: Configurando repositorio oficial de pgAdmin4..."
# Importar clave GPG
curl -fsS https://www.pgadmin.org/static/packages_pgadmin_org.pub | sudo gpg --dearmor -o /usr/share/keyrings/packages-pgadmin-org.gpg
# Añadir repositorio
sudo sh -c 'echo "deb [signed-by=/usr/share/keyrings/packages-pgadmin-org.gpg] https://ftp.postgresql.org/pub/pgadmin/pgadmin4/apt/$(lsb_release -cs) pgadmin4 main" > /etc/apt/sources.list.d/pgadmin4.list'
sudo apt update # Actualizar de nuevo

# 4. Instalar paquetes principales (Apache, PHP, PostgreSQL, pgAdmin4)
echo ">>> 4/10: Instalando Apache, PHP, PostgreSQL y pgAdmin4..."
# --- CORRECCIÓN: Añadidas extensiones recomendadas php-imagick y php-apcu ---
sudo apt install -y apache2 postgresql postgresql-contrib \
    php${PHP_VERSION} libapache2-mod-php${PHP_VERSION} \
    php${PHP_VERSION}-cli php${PHP_VERSION}-common php${PHP_VERSION}-pgsql \
    php${PHP_VERSION}-zip php${PHP_VERSION}-gd php${PHP_VERSION}-mbstring \
    php${PHP_VERSION}-curl php${PHP_VERSION}-xml php${PHP_VERSION}-intl \
    php${PHP_VERSION}-bcmath php${PHP_VERSION}-imagick php${PHP_VERSION}-apcu \
    pgadmin4-web \
    wget unzip git # git se mantiene por si algún plugin lo necesita como dependencia
# -----------------------------------------------------------------------
echo ">>> Paquetes principales instalados."

# 5. Configurar PostgreSQL (Crear base de datos y usuario para FacturaScripts - Idempotente)
echo ">>> 5/10: Configurando PostgreSQL para FacturaScripts (comprobando existencia)..."

# Comprobar si la base de datos existe
DB_EXISTS=$(sudo -u postgres psql -tAc "SELECT 1 FROM pg_database WHERE datname='${DB_NAME}'")
if [ "$DB_EXISTS" = "1" ]; then
    echo ">>> La base de datos '${DB_NAME}' ya existe. Saltando creación."
else
    echo ">>> Creando base de datos '${DB_NAME}'..."
    sudo -u postgres psql -c "CREATE DATABASE ${DB_NAME};"
    echo ">>> Base de datos '${DB_NAME}' creada."
fi

# Comprobar si el usuario existe
USER_EXISTS=$(sudo -u postgres psql -tAc "SELECT 1 FROM pg_roles WHERE rolname='${DB_USER}'")
if [ "$USER_EXISTS" = "1" ]; then
    echo ">>> El usuario '${DB_USER}' ya existe. Saltando creación."
    # Opcional: podrías querer actualizar la contraseña si ya existe
    # sudo -u postgres psql -c "ALTER USER ${DB_USER} WITH PASSWORD '${DB_PASSWORD}';"
else
    echo ">>> Creando usuario '${DB_USER}'..."
    sudo -u postgres psql -c "CREATE USER ${DB_USER} WITH PASSWORD '${DB_PASSWORD}';"
    echo ">>> Usuario '${DB_USER}' creado."
fi

# Otorgar privilegios (generalmente seguro ejecutarlo múltiples veces)
echo ">>> Otorgando privilegios a '${DB_USER}' sobre '${DB_NAME}'..."
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE ${DB_NAME} TO ${DB_USER};"

# --- CORRECCIÓN: Modificar pg_hba.conf para insertar reglas md5 en el lugar correcto ---
echo ">>> Modificando pg_hba.conf para asegurar la autenticación md5 para ${DB_USER}..."
PG_HBA_CONF=$(sudo -u postgres psql -t -P format=unaligned -c 'show hba_file;')
NEEDS_RELOAD=0 # Flag para saber si necesitamos recargar postgresql

if [ -f "$PG_HBA_CONF" ]; then
    # Definir las líneas que queremos asegurar que estén presentes y en el lugar correcto
    MD5_LINE_IPV4="host    ${DB_NAME}    ${DB_USER}    127.0.0.1/32    md5"
    MD5_LINE_IPV6="host    ${DB_NAME}    ${DB_USER}    ::1/128         md5"
    # Línea de referencia antes de la cual queremos insertar
    REFERENCE_LINE="# IPv4 local connections:"

    # Comprobar si las líneas ya existen ANTES de la línea de referencia
    # (Esta comprobación es compleja y propensa a errores, optamos por eliminar/insertar)

    # 1. Eliminar cualquier instancia previa de estas líneas (para evitar duplicados o mala ubicación)
    # Usamos un delimitador diferente para sed por las barras en las IPs
    if sudo grep -q "$MD5_LINE_IPV4" "$PG_HBA_CONF"; then
        echo ">>> Encontrada regla IPv4 md5 existente para ${DB_USER}. Eliminando para reinsertar en orden."
        sudo sed -i "\|$MD5_LINE_IPV4|d" "$PG_HBA_CONF"
        NEEDS_RELOAD=1
    fi
     if sudo grep -q "$MD5_LINE_IPV6" "$PG_HBA_CONF"; then
        echo ">>> Encontrada regla IPv6 md5 existente para ${DB_USER}. Eliminando para reinsertar en orden."
        sudo sed -i "\|$MD5_LINE_IPV6|d" "$PG_HBA_CONF"
        NEEDS_RELOAD=1
    fi

    # 2. Insertar las líneas md5 justo antes de la línea de referencia
    # Comprobar si ya están insertadas correctamente (más simple que la comprobación anterior)
    if sudo grep -q "$MD5_LINE_IPV4" "$PG_HBA_CONF" && sudo grep -q "$MD5_LINE_IPV6" "$PG_HBA_CONF"; then
         # Podríamos hacer una comprobación más exhaustiva del orden aquí, pero por ahora asumimos
         # que si existen, fueron insertadas por una ejecución previa de esta lógica.
         echo ">>> Las reglas md5 para ${DB_USER} parecen estar ya presentes. Saltando inserción."
    else
        echo ">>> Insertando reglas md5 para ${DB_USER} antes de '${REFERENCE_LINE}'..."
        # Usamos sed para insertar antes de la línea de referencia. '\t' para tabuladores.
        sudo sed -i "/^${REFERENCE_LINE}/i ${MD5_LINE_IPV6}\n${MD5_LINE_IPV4}\n" "$PG_HBA_CONF"
        # Verificar si la inserción fue exitosa (comprobación básica)
        if sudo grep -q "$MD5_LINE_IPV4" "$PG_HBA_CONF"; then
            echo ">>> Reglas md5 insertadas correctamente."
            NEEDS_RELOAD=1
        else
            echo ">>> ¡Error! No se pudieron insertar las reglas md5 automáticamente. Revisa ${PG_HBA_CONF} manualmente."
            # Podríamos decidir detener el script aquí si es crítico
            # exit 1
        fi
    fi

    # Recargar configuración de PostgreSQL solo si se hicieron cambios
    if [ "$NEEDS_RELOAD" = "1" ]; then
        echo ">>> Recargando configuración de PostgreSQL debido a cambios en pg_hba.conf..."
        sudo systemctl reload postgresql
    else
        echo ">>> La configuración de pg_hba.conf no necesitó cambios."
    fi
else
    echo ">>> Advertencia: No se pudo encontrar automáticamente el archivo pg_hba.conf. La autenticación podría requerir ajuste manual."
fi
# ---------------------------------------------------------------------------------
echo ">>> Configuración de PostgreSQL para '${DB_NAME}' y '${DB_USER}' completada."


# Reactivar set -e si se comentó antes, o continuar sin él
# set -e

# 6. Configurar PHP (Ajustes recomendados)
echo ">>> 6/10: Configurando PHP..."
PHP_INI_PATH=$(php -i | grep /.+/php.ini -oE)
if [ -f "$PHP_INI_PATH" ]; then
    sudo sed -i 's/memory_limit = .*/memory_limit = 256M/' "$PHP_INI_PATH"
    sudo sed -i 's/upload_max_filesize = .*/upload_max_filesize = 64M/' "$PHP_INI_PATH"
    sudo sed -i 's/post_max_size = .*/post_max_size = 64M/' "$PHP_INI_PATH"
    sudo sed -i 's/max_execution_time = .*/max_execution_time = 300/' "$PHP_INI_PATH"
    echo ">>> Archivo php.ini actualizado en $PHP_INI_PATH."
else
    echo ">>> Advertencia: No se pudo encontrar el archivo php.ini principal automáticamente. Revisa la configuración manualmente."
    COMMON_PHP_INI="/etc/php/${PHP_VERSION}/apache2/php.ini"
    if [ -f "$COMMON_PHP_INI" ]; then
        sudo sed -i 's/memory_limit = .*/memory_limit = 256M/' "$COMMON_PHP_INI"
        sudo sed -i 's/upload_max_filesize = .*/upload_max_filesize = 64M/' "$COMMON_PHP_INI"
        sudo sed -i 's/post_max_size = .*/post_max_size = 64M/' "$COMMON_PHP_INI"
        sudo sed -i 's/max_execution_time = .*/max_execution_time = 300/' "$COMMON_PHP_INI"
        echo ">>> Archivo php.ini actualizado en $COMMON_PHP_INI."
    else
         echo ">>> Advertencia: No se encontró php.ini en $COMMON_PHP_INI tampoco."
    fi
fi

# 7. Descargar y preparar FacturaScripts usando wget
echo ">>> 7/10: Descargando y preparando FacturaScripts desde la URL oficial..."
# Crear el directorio de instalación si no existe
sudo mkdir -p ${INSTALL_DIR}
# Descargar el archivo zip a un directorio temporal
cd /tmp
sudo wget "${DOWNLOAD_URL}" -O facturascripts.zip
# Descomprimir en el directorio de instalación final
sudo unzip -oq facturascripts.zip -d ${INSTALL_DIR} # -o para sobrescribir sin preguntar si ya existe
# Limpiar el archivo zip descargado
sudo rm facturascripts.zip
echo ">>> FacturaScripts descargado y descomprimido en ${INSTALL_DIR}."

# 8. Configurar Apache para FacturaScripts
echo ">>> 8/10: Configurando Apache para FacturaScripts..."
# Crear archivo de configuración del Virtual Host para FacturaScripts
sudo tee ${APACHE_CONF_FILE} > /dev/null <<EOF
<VirtualHost *:80>
    ServerAdmin webmaster@localhost
    DocumentRoot ${INSTALL_DIR}
    # ServerName tu_dominio.com # Descomenta y ajusta si tienes un dominio

    <Directory ${INSTALL_DIR}>
        Options Indexes FollowSymLinks MultiViews
        AllowOverride All
        Require all granted
    </Directory>

    ErrorLog \${APACHE_LOG_DIR}/facturascripts_error.log
    CustomLog \${APACHE_LOG_DIR}/facturascripts_access.log combined
</VirtualHost>
EOF
# Habilitar el sitio de FacturaScripts y el módulo rewrite
sudo a2ensite facturascripts.conf
sudo a2enmod rewrite
# Deshabilitar el sitio por defecto si aún está activo
if [ -f /etc/apache2/sites-enabled/000-default.conf ]; then
    sudo a2dissite 000-default.conf
fi
echo ">>> Configuración de Apache para FacturaScripts creada y sitio habilitado."

# 9. Establecer Permisos para FacturaScripts
echo ">>> 9/10: Estableciendo permisos para FacturaScripts..."
# --- CORRECCIÓN: Crear directorios MyFiles y tmp si no existen ---
sudo mkdir -p ${INSTALL_DIR}/MyFiles
sudo mkdir -p ${INSTALL_DIR}/tmp
# -----------------------------------------------------------------
# Asegurar que el propietario sea www-data
sudo chown -R www-data:www-data ${INSTALL_DIR}
# Permisos generales (seguridad)
sudo find ${INSTALL_DIR} -type d -exec chmod 755 {} \;
sudo find ${INSTALL_DIR} -type f -exec chmod 644 {} \;
# Permisos de escritura necesarios para directorios específicos (ahora sí deberían existir)
sudo chmod -R 775 ${INSTALL_DIR}/MyFiles
sudo chmod -R 775 ${INSTALL_DIR}/tmp
# Asegurar que el usuario www-data pueda escribir en la configuración si es necesario durante la instalación web
if [ -f "${INSTALL_DIR}/config.php" ]; then
    sudo chmod 664 ${INSTALL_DIR}/config.php
fi
# Si existe .env, darle permisos adecuados (aunque normalmente se crea vía web)
if [ -f "${INSTALL_DIR}/.env" ]; then
    sudo chmod 664 ${INSTALL_DIR}/.env
fi
echo ">>> Permisos establecidos para FacturaScripts."

# 10. Reiniciar Servicios e Instrucciones Finales
echo ">>> 10/10: Reiniciando Apache y PostgreSQL..."
sudo systemctl restart apache2
# Nota: PostgreSQL ya se recarga en el paso 5 si fue necesario
if [ "$NEEDS_RELOAD" != "1" ]; then
    # Si no se recargó antes, reiniciar ahora podría ser una opción,
    # aunque reload suele ser suficiente si el servicio ya está corriendo.
    # Considerar si es necesario reiniciar vs recargar aquí.
    # Por seguridad, un restart asegura que todo está fresco.
    sudo systemctl restart postgresql
fi
echo ">>> Servicios reiniciados/recargados."
echo ""
echo "--------------------------------------------------"
echo "--- ¡INSTALACIÓN BÁSICA COMPLETADA! ---"
echo "--------------------------------------------------"
echo ""
echo "PASOS SIGUIENTES:"
echo ""
echo "1. CONFIGURAR pgAdmin4 (si no lo has hecho ya):"
echo "   Ejecuta el siguiente comando e introduce un email y contraseña"
echo "   cuando se te soliciten. Estas serán tus credenciales para acceder a pgAdmin."
echo "   sudo /usr/pgadmin4/bin/setup-web.sh"
echo "   (Presiona 'y' para confirmar la configuración del servidor web Apache cuando pregunte)."
echo ""
echo "2. COMPLETAR INSTALACIÓN WEB DE FACTURASCRIPTS (si no lo has hecho ya):"
echo "   Abre tu navegador y ve a: http://<IP_DEL_SERVIDOR>"
echo "   Sigue el asistente de FacturaScripts. Usa los siguientes datos para la BD:"
echo "   - Tipo:          PostgreSQL"
echo "   - Base de datos: ${DB_NAME}"
echo "   - Usuario:       ${DB_USER}"
echo "   - Contraseña:    ${DB_PASSWORD}"
echo "   - Host:          localhost"
echo "   - Puerto:        5432"
echo ""
echo "3. ACCEDER A pgAdmin4:"
echo "   Una vez configurado, accede a pgAdmin en: http://<IP_DEL_SERVIDOR>/pgadmin4"
echo "   Usa el email y contraseña que creaste en el paso 1."
echo "   Dentro de pgAdmin, necesitarás añadir una conexión al servidor PostgreSQL local:"
echo "   - Click derecho en 'Servers' -> Create -> Server..."
echo "   - Pestaña 'General': Dale un nombre (ej. 'Local PostgreSQL')."
echo "   - Pestaña 'Connection':"
echo "     - Host name/address: localhost"
echo "     - Port: 5432"
echo "     - Maintenance database: postgres (o ${DB_NAME})"
echo "     - Username: ${DB_USER}"
echo "     - Password: ${DB_PASSWORD}"
echo "   - Guarda la conexión."
echo ""
echo "4. INSTALAR PLUGINS DE FACTURASCRIPTS:"
echo "   Accede a tu FacturaScripts y usa el Marketplace para instalar plugins."
echo ""
echo "5. SEGURIDAD ADICIONAL (Recomendado):"
echo "   - Revisa la configuración de pg_hba.conf para ajustar la seguridad de PostgreSQL."
echo "   - Considera configurar HTTPS/SSL para Apache (Let's Encrypt)."
echo "--------------------------------------------------"
echo "--- Fin del script ---"

