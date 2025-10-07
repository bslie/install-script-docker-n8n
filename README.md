# n8n + PostgreSQL + Nginx + Let's Encrypt Installer

## 🇬🇧 English

This repository provides a **universal installation script** for [n8n](https://n8n.io), PostgreSQL, Nginx, and Let's Encrypt.
It works out of the box on any Ubuntu 22.04–24.04 server and is designed to be safe, flexible, and easy to use.

---

### 🧰 What the script does

- Installs **Docker** and **Docker Compose** if missing
- Sets up **n8n**, **PostgreSQL**, **Nginx**, and **Certbot**
- Automatically requests a **Let's Encrypt SSL certificate**
- Handles **port conflicts** (80/443 → fallback to 8080/8443)
- Creates a **self-contained directory structure** under `/opt/n8n` (configurable)
- Configures **automatic SSL renewal** every 12 hours

---

### 📦 Prerequisites

- Ubuntu 22.04 or 24.04
- Root or sudo access
- A valid domain pointing to your server

---

### ⚙️ Setup instructions

1. Clone or download this repository:

   ```bash
   git clone https://github.com/yourname/n8n-installer.git
   cd n8n-installer
   ```

2. Create a `.env` file based on the example below:

   ```bash
   DOMAIN=n8n.example.com
   EMAIL=admin@example.com
   BASE_DIR=/opt/n8n

   N8N_PORT=5678
   N8N_HTTP_PORT=80
   N8N_HTTPS_PORT=443

   POSTGRES_USER=n8n
   POSTGRES_PASSWORD=supersecurepassword
   POSTGRES_DB=n8n
   ```

3. Run the installer:

   ```bash
   chmod +x install_n8n.sh
   ./install_n8n.sh
   ```

4. If Docker was newly installed, **log out and log back in**, then rerun the script.

---

### 🔗 Accessing n8n

Once installation is complete, open:

```
https://your-domain.com
```

If ports 8080/8443 were used instead of 80/443, adjust the URL accordingly:

```
https://your-domain.com:8443
```

---

### 🔄 SSL Certificate Renewal

The containerized Certbot runs continuously and renews certificates automatically every 12 hours.
After each renewal, Nginx reloads automatically — no manual intervention required.

---

### 🧹 Uninstallation

To remove everything:

```bash
cd /opt/n8n
docker compose down -v
rm -rf /opt/n8n
```

---

## 🇷🇺 Русская версия

Этот проект предоставляет **универсальный установочный скрипт** для [n8n](https://n8n.io), PostgreSQL, Nginx и Let's Encrypt.  
Он полностью автоматизирует установку и подходит для любых серверов Ubuntu 22.04–24.04.

---

### 🧰 Что делает скрипт

- Проверяет и при необходимости устанавливает **Docker** и **Compose**
- Разворачивает **n8n**, **PostgreSQL**, **Nginx** и **Certbot**
- Автоматически получает **SSL-сертификат Let's Encrypt**
- Проверяет, заняты ли порты **80/443** и при необходимости использует **8080/8443**
- Создаёт изолированную структуру каталогов в `/opt/n8n`
- Настраивает **автообновление SSL каждые 12 часов**

---

### 📦 Требования

- Ubuntu 22.04 или 24.04
- Права root или sudo
- Доменное имя, указывающее на сервер

---

### ⚙️ Пошаговая установка

1. Склонируйте репозиторий или скачайте скрипт:

   ```bash
   git clone https://github.com/yourname/n8n-installer.git
   cd n8n-installer
   ```

2. Создайте файл `.env` по примеру:

   ```bash
   DOMAIN=n8n.example.com
   EMAIL=admin@example.com
   BASE_DIR=/opt/n8n

   N8N_PORT=5678
   N8N_HTTP_PORT=80
   N8N_HTTPS_PORT=443

   POSTGRES_USER=n8n
   POSTGRES_PASSWORD=supersecurepassword
   POSTGRES_DB=n8n
   ```

3. Запустите установку:

   ```bash
   chmod +x install_n8n.sh
   ./install_n8n.sh
   ```

4. Если Docker был установлен впервые — выйдите из сессии SSH и войдите снова, затем повторите запуск.

---

### 🔗 Доступ к n8n

После установки откройте в браузере:

```
https://ваш-домен
```

Если используются порты 8080/8443:

```
https://ваш-домен:8443
```

---

### 🔄 Автообновление сертификатов

Certbot работает внутри контейнера и автоматически продлевает сертификаты каждые 12 часов.  
После продления nginx автоматически перезапускается — без участия пользователя.

---

### 🧹 Удаление

Для полного удаления:

```bash
cd /opt/n8n
docker compose down -v
rm -rf /opt/n8n
```

---

### 📜 Лицензия

MIT License — свободно используйте и модифицируйте.
