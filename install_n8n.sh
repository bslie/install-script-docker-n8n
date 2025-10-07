#!/bin/bash
set -e

echo "🚀 Установка n8n + PostgreSQL + Nginx + Let's Encrypt"

# === Загрузка .env ===
if [ -f "./.env" ]; then
  export $(grep -v '^#' .env | xargs)
else
  echo "❌ Не найден файл .env. Создайте его рядом со скриптом (см. пример в README)."
  exit 1
fi

# === Проверка обязательных переменных ===
REQUIRED_VARS=(DOMAIN EMAIL BASE_DIR POSTGRES_USER POSTGRES_PASSWORD POSTGRES_DB)
for VAR in "${REQUIRED_VARS[@]}"; do
  if [ -z "${!VAR}" ]; then
    echo "❌ Переменная $VAR не указана в .env"
    exit 1
  fi
done

# === Проверка портов ===
N8N_HTTP_PORT=${N8N_HTTP_PORT:-80}
N8N_HTTPS_PORT=${N8N_HTTPS_PORT:-443}

if ss -tln | grep -q ":80 "; then
  echo "⚠️ Порт 80 уже используется. Переключаем на 8080."
  N8N_HTTP_PORT=8080
fi
if ss -tln | grep -q ":443 "; then
  echo "⚠️ Порт 443 уже используется. Переключаем на 8443."
  N8N_HTTPS_PORT=8443
fi

# === Проверка Docker ===
if ! command -v docker &> /dev/null; then
  echo "🐳 Docker не найден. Устанавливаю..."
  sudo apt-get update -y
  sudo apt-get install -y ca-certificates curl gnupg lsb-release
  sudo mkdir -p /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
    $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
  sudo apt-get update -y
  sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  sudo usermod -aG docker $USER
  echo "✅ Docker установлен. Перезапустите SSH-сессию и повторите запуск."
  exit 0
fi

if ! docker compose version &> /dev/null; then
  echo "📦 Устанавливаю docker-compose-plugin..."
  sudo apt-get install -y docker-compose-plugin
fi

# === Создание структуры ===
mkdir -p $BASE_DIR/{data/n8n,data/postgres,logs/nginx,logs/letsencrypt}
mkdir -p $BASE_DIR/config/{n8n,postgres}
mkdir -p $BASE_DIR/config/nginx/{conf.d,www,ssl}
mkdir -p $BASE_DIR/config/nginx/www/.well-known/acme-challenge

# === docker-compose.yml ===
cat > $BASE_DIR/docker-compose.yml <<EOF
services:
  postgres:
    image: postgres:16-alpine
    restart: unless-stopped
    env_file:
      - ./config/postgres/postgres.env
    volumes:
      - ./data/postgres:/var/lib/postgresql/data
    networks: [backend]

  n8n:
    image: n8nio/n8n:latest
    restart: unless-stopped
    depends_on: [postgres]
    env_file:
      - ./config/n8n/n8n.env
    volumes:
      - ./data/n8n:/home/node/.n8n
    networks: [backend]
    expose: ["${N8N_PORT:-5678}"]

  nginx:
    image: nginx:1.27-alpine
    restart: unless-stopped
    depends_on: [n8n]
    ports:
      - "${N8N_HTTP_PORT}:80"
      - "${N8N_HTTPS_PORT}:443"
    volumes:
      - ./config/nginx/nginx.conf:/etc/nginx/nginx.conf:ro
      - ./config/nginx/conf.d:/etc/nginx/conf.d:ro
      - ./config/nginx/ssl:/etc/letsencrypt
      - ./config/nginx/www:/var/www/certbot
      - ./logs/nginx:/var/log/nginx
    networks: [backend,frontend]

  certbot:
    image: certbot/certbot:latest
    volumes:
      - ./config/nginx/ssl:/etc/letsencrypt
      - ./logs/letsencrypt:/var/log/letsencrypt
      - ./config/nginx/www:/var/www/certbot
    networks: [frontend]

networks:
  backend: {driver: bridge}
  frontend: {driver: bridge}
EOF

# === nginx.conf ===
cat > $BASE_DIR/config/nginx/nginx.conf <<'EOF'
user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log warn;
pid /var/run/nginx.pid;
events { worker_connections 1024; }
http {
  include /etc/nginx/mime.types;
  default_type application/octet-stream;
  access_log /var/log/nginx/access.log;
  sendfile on;
  keepalive_timeout 65;
  include /etc/nginx/conf.d/*.conf;
}
EOF

# === Временный конфиг для выдачи challenge ===
cat > $BASE_DIR/config/nginx/conf.d/n8n.conf <<EOF
server {
  listen 80;
  server_name $DOMAIN;
  location /.well-known/acme-challenge/ {
    alias /var/www/certbot/.well-known/acme-challenge/;
  }
  location / {
    return 200 'nginx ready';
    add_header Content-Type text/plain;
  }
}
EOF

# === postgres.env ===
cat > $BASE_DIR/config/postgres/postgres.env <<EOF
POSTGRES_USER=$POSTGRES_USER
POSTGRES_PASSWORD=$POSTGRES_PASSWORD
POSTGRES_DB=$POSTGRES_DB
EOF

# === n8n.env ===
cat > $BASE_DIR/config/n8n/n8n.env <<EOF
N8N_PORT=${N8N_PORT:-5678}
N8N_PROTOCOL=https
WEBHOOK_URL=https://$DOMAIN/
N8N_HOST=$DOMAIN
DB_TYPE=postgresdb
DB_POSTGRESDB_HOST=postgres
DB_POSTGRESDB_PORT=5432
DB_POSTGRESDB_DATABASE=$POSTGRES_DB
DB_POSTGRESDB_USER=$POSTGRES_USER
DB_POSTGRESDB_PASSWORD=$POSTGRES_PASSWORD
EXECUTIONS_PROCESS=main
EXECUTIONS_MODE=regular
N8N_DIAGNOSTICS_ENABLED=false
N8N_PERSONALIZATION_ENABLED=false
EOF

cd $BASE_DIR
echo "▶️ Поднимаем временный nginx..."
docker compose up -d postgres n8n nginx
sleep 3

# === Проверка challenge ===
echo "hello" > $BASE_DIR/config/nginx/www/.well-known/acme-challenge/test.txt
if ! curl -s http://$DOMAIN/.well-known/acme-challenge/test.txt | grep -q hello; then
  echo "❌ Challenge не доступен по http://$DOMAIN/.well-known/acme-challenge/test.txt"
  echo "Проверьте DNS и открытость порта ${N8N_HTTP_PORT}."
  exit 1
fi
echo "✅ Challenge доступен, получаем сертификат..."

docker compose run --rm certbot certonly --webroot -w /var/www/certbot \
  -d $DOMAIN --email $EMAIL --agree-tos --non-interactive

# === Финальный nginx.conf с SSL ===
cat > $BASE_DIR/config/nginx/conf.d/n8n.conf <<EOF
server {
  listen 80;
  server_name $DOMAIN;
  location /.well-known/acme-challenge/ {
    alias /var/www/certbot/.well-known/acme-challenge/;
  }
  location / {
    return 301 https://\$host\$request_uri;
  }
}

server {
  listen 443 ssl;
  server_name $DOMAIN;
  ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
  ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;

  client_max_body_size 32m;

  location / {
    proxy_pass http://n8n:${N8N_PORT:-5678};
    proxy_http_version 1.1;
    proxy_set_header Host \$host;
    proxy_set_header X-Real-IP \$remote_addr;
    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto \$scheme;
    proxy_set_header Upgrade \$http_upgrade;
    proxy_set_header Connection "upgrade";
  }
}
EOF

docker compose restart nginx

# === Автообновление SSL ===
cat > $BASE_DIR/docker-compose.override.yml <<EOF
services:
  certbot:
    entrypoint: sh -c 'trap exit TERM; while :; do certbot renew --webroot -w /var/www/certbot --quiet && docker exec n8n-nginx-1 nginx -s reload; sleep 12h & wait \\\$!; done'
EOF

docker compose up -d certbot

echo "🎉 Готово!"
echo "🔗 Открой https://${DOMAIN} (если порты 8080/8443, добавь их в URL)"
