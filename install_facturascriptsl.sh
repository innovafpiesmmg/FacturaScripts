#!/bin/bash

# Script para instalar Docker, Docker Compose y FacturaScripts en sistemas Debian/Ubuntu.
# ADVERTENCIA: Ejecuta este script bajo tu propia responsabilidad.

# --- Configuración ---
INSTALL_DIR="$HOME/facturascripts_docker" # Directorio donde se guardarán los archivos de configuración
FACTURASCRIPTS_PORT="8000" # Puerto en el host para acceder a FacturaScripts

# --- Comprobaciones Previas ---

# 1. Comprobar si se ejecuta como root
if [ "$(id -u)" -ne 0 ]; then
  echo "Este script necesita ejecutarse con privilegios de superusuario (root)."
  echo "Intenta ejecutarlo con: sudo $0"
  exit 1
fi

# 2. Salir si ocurre un error
set -e

# --- Funciones Auxiliares ---
generate_password() {
  # Genera una contraseña aleatoria segura
  LC_ALL=C tr -dc 'A-Za-z0-9!"#$%&()*+,-./:;<=>?@[\]^_`{|}~' </dev/urandom | head -c 24
}

# --- Instalación de Dependencias y Docker ---

echo ">>> Actualizando lista de paquetes..."
apt-get update

echo ">>> Instalando paquetes necesarios para Docker..."
apt-get install -y ca-certificates curl gnupg lsb-release

# Comprobar si curl se instaló correctamente
if ! command -v curl &> /dev/null; then
    echo "Error: curl no se pudo instalar. Abortando."
    exit 1
fi

echo ">>> Añadiendo la clave GPG oficial de Docker..."
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

echo ">>> Configurando el repositorio de Docker..."
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

echo ">>> Actualizando lista de paquetes (después de añadir repo Docker)..."
apt-get update

# Verificar si Docker ya está instalado
if command -v docker &> /dev/null; then
    echo ">>> Docker ya está instalado. Saltando instalación."
else
    echo ">>> Instalando Docker Engine..."
    apt-get install -y docker-ce docker-ce-cli containerd.io
fi

# Verificar si Docker Compose (plugin) ya está instalado
if docker compose version &> /dev/null; then
    echo ">>> Docker Compose (plugin) ya está instalado. Saltando instalación."
else
    echo ">>> Instalando Docker Compose (plugin)..."
    apt-get install -y docker-compose-plugin
    # Comprobar si la instalación fue exitosa
    if ! docker compose version &> /dev/null; then
        echo "Error: No se pudo instalar Docker Compose (plugin) automáticamente."
        echo "Por favor, instálalo manualmente siguiendo la documentación oficial de Docker."
        exit 1
    fi
fi

echo ">>> Docker y Docker Compose instalados correctamente."

# --- Configuración de FacturaScripts ---

echo ">>> Creando directorio de configuración en $INSTALL_DIR..."
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"

echo ">>> Generando archivo .env con contraseñas aleatorias..."

# Generar contraseñas seguras
MYSQL_ROOT_PASSWORD=$(generate_password)
MYSQL_PASSWORD=$(generate_password)
MYSQL_USER="facturascripts_user"
MYSQL_DATABASE="facturascripts_db"

# Crear archivo .env
cat << EOF > .env
# Variables de entorno para la configuración de FacturaScripts y MySQL
# ¡GUARDA ESTAS CONTRASEÑAS EN UN LUGAR SEGURO!

# Contraseña root de MySQL (para administración interna del contenedor)
MYSQL_ROOT_PASSWORD=${MYSQL_ROOT_PASSWORD}

# Base de datos, usuario y contraseña para FacturaScripts
MYSQL_DATABASE=${MYSQL_DATABASE}
MYSQL_USER=${MYSQL_USER}
MYSQL_PASSWORD=${MYSQL_PASSWORD}
EOF

echo ">>> Archivo .env creado en $INSTALL_DIR/.env"
echo "    Usuario MySQL: ${MYSQL_USER}"
echo "    Base de datos MySQL: ${MYSQL_DATABASE}"
echo "    Contraseña Usuario MySQL: GUARDADA EN .env"
echo "    Contraseña Root MySQL: GUARDADA EN .env"
echo "    ¡IMPORTANTE! Guarda una copia de $INSTALL_DIR/.env en un lugar seguro."

echo ">>> Creando archivo docker-compose.yml..."

cat << EOF > docker-compose.yml
version: '3.9'

services:
  facturascripts:
    image: facturascripts/facturascripts:latest
    container_name: facturascripts
    restart: unless-stopped
    ports:
      - "${FACTURASCRIPTS_PORT}:80" # Puerto host:puerto contenedor
    volumes:
      - facturascripts_data:/var/www/html
    depends_on:
      - mysql
    environment:
      - APP_ENV=prod
      - DB_TYPE=mysql
      - DB_HOST=mysql # Nombre del servicio de la base de datos definido abajo
      - DB_PORT=3306
      - DB_NAME=\${MYSQL_DATABASE} # Lee la variable del archivo .env
      - DB_USER=\${MYSQL_USER}     # Lee la variable del archivo .env
      - DB_PASS=\${MYSQL_PASSWORD} # Lee la variable del archivo .env
      # Opcional: Configuración de correo (descomentar y configurar si es necesario)
      # - MAILER_URL=smtp://user:pass@smtp.example.com:587
    networks:
      - facturascripts_net

  mysql:
    image: mysql:8.0 # Usar una versión específica es recomendable
    container_name: facturascripts_mysql
    restart: unless-stopped
    environment:
      MYSQL_ROOT_PASSWORD: \${MYSQL_ROOT_PASSWORD} # Lee la variable del archivo .env
      MYSQL_DATABASE: \${MYSQL_DATABASE}         # Lee la variable del archivo .env
      MYSQL_USER: \${MYSQL_USER}                 # Lee la variable del archivo .env
      MYSQL_PASSWORD: \${MYSQL_PASSWORD}         # Lee la variable del archivo .env
    volumes:
      - mysql_data:/var/lib/mysql # Volumen para persistencia de datos MySQL
    networks:
      - facturascripts_net
    # Opcional: Añadir healthcheck para asegurar que MySQL esté listo antes que FacturaScripts
    # healthcheck:
    #   test: ["CMD", "mysqladmin" ,"ping", "-h", "localhost", "-u", "$MYSQL_USER", "-p$MYSQL_PASSWORD"]
    #   interval: 10s
    #   timeout: 5s
    #   retries: 5

volumes:
  facturascripts_data: # Volumen para persistencia de datos de FacturaScripts (plugins, etc.)
  mysql_data:          # Volumen para persistencia de la base de datos

networks:
  facturascripts_net:
    driver: bridge     # Red interna para que los contenedores se comuniquen
EOF

echo ">>> Archivo docker-compose.yml creado."

# --- Lanzar Contenedores ---

echo ">>> Descargando imágenes y iniciando contenedores de FacturaScripts..."
# Usamos 'docker compose' (con espacio), que es la sintaxis moderna
docker compose up -d

echo ""
echo "------------------------------------------------------------------"
echo "¡Instalación completada!"
echo ""
echo "Puedes acceder a FacturaScripts en tu navegador web:"
# Intenta obtener la IP pública (puede no funcionar en todas las configuraciones)
SERVER_IP=$(curl -s ifconfig.me || hostname -I | awk '{print $1}')
echo "   URL: http://${SERVER_IP}:${FACTURASCRIPTS_PORT}"
echo "   (Si la IP anterior no es correcta, usa la IP pública de tu servidor)"
echo ""
echo "Los archivos de configuración se encuentran en: $INSTALL_DIR"
echo "Las contraseñas generadas están en: $INSTALL_DIR/.env"
echo "¡ASEGÚRATE DE GUARDAR EL ARCHIVO .env EN UN LUGAR SEGURO!"
echo ""
echo "Para detener FacturaScripts, ve al directorio $INSTALL_DIR y ejecuta: sudo docker compose down"
echo "Para reiniciar FacturaScripts, ve al directorio $INSTALL_DIR y ejecuta: sudo docker compose restart"
echo "------------------------------------------------------------------"

exit 0
