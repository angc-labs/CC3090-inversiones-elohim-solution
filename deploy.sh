#!/usr/bin/env bash
# Script de Despliegue en Producción (Build optimizado, Nginx y SSL)
set -euo pipefail

cd "$(dirname "$0")"

DOMINIO="${NEXT_PUBLIC_MAIN_DOMAIN:-dmhub.fun}"
EMAIL="${CERTBOT_EMAIL:-admin@${DOMINIO}}"

echo "=========================================="
echo "==> Entorno: Production"
echo "==> Modo: Build compilado de Next.js (standalone) + ASP.NET Core (Release)"
echo "==> Dominio: ${DOMINIO}"
echo "==> Compose: docker-compose.yml (sin override de desarrollo)"
echo "=========================================="

# 1. Asegurar archivo de variables de entorno (.env)
if [[ ! -f .env && -f .env.example ]]; then
  echo "==> Creando .env desde .env.example"
  cp .env.example .env
fi

# 2. Forzar variables de entorno para producción
export NODE_ENV=production
export ASPNETCORE_ENVIRONMENT=Production
export COMPOSE_FILE=docker-compose.yml
export NGINX_HTTP_PORT="${NGINX_HTTP_PORT:-80}"
export NGINX_HTTPS_PORT="${NGINX_HTTPS_PORT:-443}"

# 3. Preparar directorios y certificados SSL mínimos para arranque seguro de Nginx
CERT_DIR="./certbot/conf/live/${DOMINIO}"
DMHUB_CERT_DIR="./certbot/conf/live/dmhub.fun"
mkdir -p "${CERT_DIR}" "${DMHUB_CERT_DIR}" "./certbot/www"

# Si no existen certificados, generar certificados autofirmados de respaldo
for dir in "${CERT_DIR}" "${DMHUB_CERT_DIR}"; do
  if [[ ! -f "${dir}/fullchain.pem" || ! -f "${dir}/privkey.pem" ]]; then
    echo "==> Generando certificado SSL temporal de prueba en ${dir} para Nginx..."
    openssl req -x509 -nodes -newkey rsa:2048 -days 365 \
      -keyout "${dir}/privkey.pem" \
      -out "${dir}/fullchain.pem" \
      -subj "/CN=${DOMINIO}" 2>/dev/null || true
  fi
done

# 4. Determinar argumentos de ejecución
# Si el usuario no especificó argumentos, desplegar en segundo plano (-d) por defecto
DOCKER_ARGS=()
if [[ $# -eq 0 ]]; then
  DOCKER_ARGS=("-d")
else
  DOCKER_ARGS=("$@")
fi

echo "==> Compilando imágenes y desplegando servicios de producción con Docker Compose..."
if ! docker compose --profile production up --build --remove-orphans "${DOCKER_ARGS[@]}"; then
  echo "==> Conflicto detectado en redes o contenedores previos de Docker (stale network/endpoints)."
  echo "==> Limpiando estado de contenedores previos y reintentando..."
  docker compose --profile production down --remove-orphans || true
  docker network prune -f 2>/dev/null || true
  docker compose --profile production up --build --remove-orphans "${DOCKER_ARGS[@]}"
fi


# 5. Si se encuentra en un entorno con dominio público, gestionar certificado Let's Encrypt
if [[ "${DOMINIO}" != "localhost" && "${DOMINIO}" != *"lvh.me"* && "${DOMINIO}" != *"127.0.0.1"* ]]; then
  IS_SELF_SIGNED=false
  if openssl x509 -in "${CERT_DIR}/fullchain.pem" -issuer -noout 2>/dev/null | grep -qi "${DOMINIO}"; then
    IS_SELF_SIGNED=true
  fi

  # Solo ejecutar Certbot si el certificado actual es autofirmado o si se fuerza la renovación
  if [[ "${IS_SELF_SIGNED}" == "true" || "${FORCE_CERTBOT:-false}" == "true" ]]; then
    echo "==> Solicitando certificado SSL Let's Encrypt con Certbot para ${DOMINIO}..."
    if command -v certbot &> /dev/null; then
      certbot certonly --webroot -w ./certbot/www \
        -d "${DOMINIO}" -d "www.${DOMINIO}" \
        --agree-tos --email "${EMAIL}" --non-interactive \
        --keep-until-expiring 2>/dev/null || true

      if [[ -d "/etc/letsencrypt/live/${DOMINIO}" ]]; then
        cp -rL /etc/letsencrypt/live/${DOMINIO}/* "${CERT_DIR}/" 2>/dev/null || true
        cp -rL /etc/letsencrypt/live/${DOMINIO}/* "${DMHUB_CERT_DIR}/" 2>/dev/null || true
      fi
    else
      echo "==> Ejecutando Certbot vía contenedor Docker..."
      docker run --rm \
        -v "$(pwd)/certbot/conf:/etc/letsencrypt" \
        -v "$(pwd)/certbot/www:/var/www/certbot" \
        certbot/certbot certonly --webroot -w /var/www/certbot \
        -d "${DOMINIO}" -d "www.${DOMINIO}" \
        --agree-tos --email "${EMAIL}" --non-interactive \
        --keep-until-expiring 2>/dev/null || true
    fi

    # Recargar Nginx de forma no interactiva
    echo "==> Recargando Nginx para aplicar certificados SSL..."
    docker compose --profile production exec -T nginx nginx -s reload 2>/dev/null || true
  fi
fi

echo "=========================================="
echo "==> Despliegue de producción completado con éxito!"
echo "=========================================="
docker compose --profile production ps
