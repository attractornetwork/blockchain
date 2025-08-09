#!/bin/bash

# Script for one-time nginx configuration update with ports from Kurtosis enclave
# Usage: sudo ./nginx_update_ports.sh [ENCLAVE_NAME]

set -e

# Configuration
ENCLAVE_NAME="${1:-${ENCLAVE_NAME:-cdk}}"
NGINX_CONF_DIR="${NGINX_CONF_DIR:-/opt/attractor/nginx/conf.d}"
BACKUP_DIR="${BACKUP_DIR:-/opt/attractor/nginx/conf.d/backup}"
LOG_FILE="${LOG_FILE:-/var/log/nginx-port-updater.log}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp="[$(date '+%Y-%m-%d %H:%M:%S')]"
    
    case "$level" in
        "INFO")
            echo -e "${BLUE}ℹ️  $message${NC}"
            echo "$timestamp [INFO] $message" >> "$LOG_FILE"
            ;;
        "SUCCESS")
            echo -e "${GREEN}✅ $message${NC}"
            echo "$timestamp [SUCCESS] $message" >> "$LOG_FILE"
            ;;
        "WARNING")
            echo -e "${YELLOW}⚠️  $message${NC}"
            echo "$timestamp [WARNING] $message" >> "$LOG_FILE"
            ;;
        "ERROR")
            echo -e "${RED}❌ $message${NC}"
            echo "$timestamp [ERROR] $message" >> "$LOG_FILE"
            ;;
    esac
}

# Показать помощь
show_help() {
    cat << EOF
Обновление портов nginx для Kurtosis CDK

ИСПОЛЬЗОВАНИЕ:
    sudo $0 [ОПЦИИ] [ENCLAVE_NAME]

АРГУМЕНТЫ:
    ENCLAVE_NAME    Имя Kurtosis энклава (по умолчанию: cdk)

ОПЦИИ:
    -h, --help      Показать эту справку
    -v, --verbose   Подробный вывод
    -d, --dry-run   Показать что будет сделано без применения изменений
    --no-backup     Не создавать бэкап (не рекомендуется)

ПЕРЕМЕННЫЕ ОКРУЖЕНИЯ:
    NGINX_CONF_DIR  Путь к конфигурациям nginx (по умолчанию: /opt/attractor/nginx/conf.d)
    BACKUP_DIR      Путь для бэкапов (по умолчанию: /opt/attractor/nginx/conf.d/backup)
    LOG_FILE        Файл логов (по умолчанию: /var/log/nginx-port-updater.log)

ПРИМЕРЫ:
    sudo $0                         # Обновить порты для энклава 'cdk'
    sudo $0 my-enclave             # Обновить порты для энклава 'my-enclave'
    sudo $0 --dry-run              # Показать что будет сделано
    sudo $0 --verbose cdk          # Подробный вывод для энклава 'cdk'

EOF
}

# Парсинг аргументов
VERBOSE=false
DRY_RUN=false
NO_BACKUP=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -d|--dry-run)
            DRY_RUN=true
            shift
            ;;
        --no-backup)
            NO_BACKUP=true
            shift
            ;;
        -*)
            log "ERROR" "Неизвестная опция: $1"
            exit 1
            ;;
        *)
            ENCLAVE_NAME="$1"
            shift
            ;;
    esac
done

# Функция для создания бэкапа конфигов
backup_configs() {
    if [[ "$NO_BACKUP" == "true" ]]; then
        log "WARNING" "Пропуск создания бэкапа (--no-backup)"
        return 0
    fi
    
    log "INFO" "Создание бэкапа nginx конфигураций..."
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log "INFO" "[DRY-RUN] Создал бы бэкап в: $BACKUP_DIR"
        return 0
    fi
    
    mkdir -p "$BACKUP_DIR"
    cp "$NGINX_CONF_DIR"/*.conf "$BACKUP_DIR/" 2>/dev/null || true
    log "SUCCESS" "Бэкап создан в $BACKUP_DIR"
}

# Функция для получения портов из Kurtosis
get_service_ports() {
    local service_name="$1"
    local port_type="$2"
    
    if [[ "$VERBOSE" == "true" ]]; then
        log "INFO" "Поиск порта для сервиса: $service_name, тип: $port_type"
    fi
    
    local port=$(kurtosis enclave inspect "$ENCLAVE_NAME" 2>/dev/null | \
        grep -A 10 "$service_name" | \
        grep "$port_type" | \
        grep -o '127\.0\.0\.1:[0-9]\+' | \
        cut -d':' -f2 | \
        head -1)
    
    echo "$port"
}

# Функция для получения всех портов
extract_ports() {
    log "INFO" "Извлечение портов из энклава '$ENCLAVE_NAME'..."
    
    # RPC сервис (cdk-erigon-sequencer)
    RPC_HTTP_PORT=$(get_service_ports "cdk-erigon-sequencer" "rpc")
    RPC_WS_PORT=$(get_service_ports "cdk-erigon-sequencer" "ws-rpc")
    
    # Explorer сервисы
    EXPLORER_FRONTEND_PORT=$(get_service_ports "bs-frontend" "frontend")
    EXPLORER_API_PORT=$(get_service_ports "bs-backend" "backend")
    EXPLORER_STATS_PORT=$(get_service_ports "bs-stats" "stats")
    EXPLORER_SOCKET_PORT="$RPC_WS_PORT"  # Используем тот же WS порт
    
    # Bridge UI
    BRIDGE_UI_PORT=$(get_service_ports "zkevm-bridge-ui" "web-ui")
    
    # DAC сервис
    DAC_PORT=$(get_service_ports "zkevm-dac" "dac")
    
    # Faucet (если есть)
    FAUCET_PORT=$(get_service_ports "faucet" "web")
    
    # Показываем найденные порты
    log "SUCCESS" "Найденные порты:"
    echo "  RPC HTTP: ${RPC_HTTP_PORT:-не найден}"
    echo "  RPC WebSocket: ${RPC_WS_PORT:-не найден}"
    echo "  Explorer Frontend: ${EXPLORER_FRONTEND_PORT:-не найден}"
    echo "  Explorer API: ${EXPLORER_API_PORT:-не найден}"
    echo "  Explorer Stats: ${EXPLORER_STATS_PORT:-не найден}"
    echo "  Bridge UI: ${BRIDGE_UI_PORT:-не найден}"
    echo "  DAC: ${DAC_PORT:-не найден}"
    echo "  Faucet: ${FAUCET_PORT:-не найден}"
}

# Функция для создания конфигурации
create_config() {
    local service_name="$1"
    local config_file="$2"
    local template="$3"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log "INFO" "[DRY-RUN] Создал бы конфигурацию: $config_file"
        return 0
    fi
    
    echo "$template" > "$config_file.tmp"
    mv "$config_file.tmp" "$config_file"
    log "SUCCESS" "$service_name конфигурация обновлена"
}

# Функция для обновления RPC конфигурации
update_rpc_config() {
    local config_file="$NGINX_CONF_DIR/rpc.testnet.attra.me.conf"
    
    if [[ -z "$RPC_HTTP_PORT" || -z "$RPC_WS_PORT" ]]; then
        log "ERROR" "Не удалось найти порты для RPC сервиса"
        return 1
    fi
    
    log "INFO" "Обновление RPC конфигурации (HTTP: $RPC_HTTP_PORT, WS: $RPC_WS_PORT)..."
    
    local template="map \$http_upgrade \$connection_upgrade {
    default   Upgrade;
    ''        close;
}

map \$http_upgrade \$backend {
    default              http://127.0.0.1:$RPC_HTTP_PORT;
    websocket            http://127.0.0.1:$RPC_WS_PORT;
}

server {
    listen 443 ssl http2;
    server_name rpc.testnet.attra.me;

    ssl_certificate     /etc/letsencrypt/live/da.testnet.attra.me/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/da.testnet.attra.me/privkey.pem;

    location / {
        proxy_pass              \$backend;
        proxy_set_header        Host               \$host;
        proxy_set_header        X-Real-IP          \$remote_addr;
        proxy_set_header        X-Forwarded-For    \$proxy_add_x_forwarded_for;
        proxy_set_header        X-Forwarded-Proto  \$scheme;
        proxy_http_version      1.1;
        proxy_set_header        Upgrade            \$http_upgrade;
        proxy_set_header        Connection         \$connection_upgrade;
        proxy_read_timeout      300s;
        proxy_send_timeout      300s;
        proxy_connect_timeout   75s;
    }
}

server {
    listen 80;
    server_name rpc.testnet.attra.me;
    
    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }

    location / {
        proxy_pass              \$backend;
        proxy_set_header        Host               \$host;
        proxy_set_header        X-Real-IP          \$remote_addr;
        proxy_set_header        X-Forwarded-For    \$proxy_add_x_forwarded_for;
        proxy_set_header        X-Forwarded-Proto  \$scheme;
        proxy_http_version      1.1;
        proxy_set_header        Upgrade            \$http_upgrade;
        proxy_set_header        Connection         \$connection_upgrade;
        proxy_read_timeout      300s;
        proxy_send_timeout      300s;
        proxy_connect_timeout   75s;
    }
}"

    create_config "RPC" "$config_file" "$template"
}

# Функция для обновления Explorer конфигурации
update_explorer_config() {
    local config_file="$NGINX_CONF_DIR/explorer.testnet.attra.me.conf"
    
    if [[ -z "$EXPLORER_FRONTEND_PORT" || -z "$EXPLORER_API_PORT" || -z "$EXPLORER_STATS_PORT" ]]; then
        log "ERROR" "Не удалось найти порты для Explorer сервиса"
        return 1
    fi
    
    log "INFO" "Обновление Explorer конфигурации (Frontend: $EXPLORER_FRONTEND_PORT, API: $EXPLORER_API_PORT, Stats: $EXPLORER_STATS_PORT)..."
    
    local template="map \$request_uri \$explorer_backend_port {
    ~^/api/            $EXPLORER_API_PORT;
    ~^/stats-api/      $EXPLORER_STATS_PORT;
    ~^/socket/         $EXPLORER_SOCKET_PORT;
    default            $EXPLORER_FRONTEND_PORT;
}

map \$http_upgrade \$connection_upgrade {
    default   Upgrade;
    ''        close;
}

server {
    listen 443 ssl http2;
    server_name explorer.testnet.attra.me;

    ssl_certificate     /etc/letsencrypt/live/da.testnet.attra.me/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/da.testnet.attra.me/privkey.pem;

    location / {
        proxy_pass              http://127.0.0.1:\$explorer_backend_port\$request_uri;
        proxy_set_header        Host               \$host;
        proxy_set_header        X-Real-IP          \$remote_addr;
        proxy_set_header        X-Forwarded-For    \$proxy_add_x_forwarded_for;
        proxy_set_header        X-Forwarded-Proto  \$scheme;
        proxy_http_version      1.1;
        proxy_set_header        Upgrade            \$http_upgrade;
        proxy_set_header        Connection         \$connection_upgrade;
    }
}

server {
    listen 80;
    server_name explorer.testnet.attra.me;

    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }

    location / {
        proxy_pass              http://127.0.0.1:\$explorer_backend_port\$request_uri;
        proxy_set_header        Host               \$host;
        proxy_set_header        X-Real-IP          \$remote_addr;
        proxy_set_header        X-Forwarded-For    \$proxy_add_x_forwarded_for;
        proxy_set_header        X-Forwarded-Proto  \$scheme;
        proxy_http_version      1.1;
        proxy_set_header        Upgrade            \$http_upgrade;
        proxy_set_header        Connection         \$connection_upgrade;
    }
}"

    create_config "Explorer" "$config_file" "$template"
}

# Функция для обновления Bridge конфигурации
update_bridge_config() {
    local config_file="$NGINX_CONF_DIR/bridge.testnet.attra.me.conf"
    
    if [[ -z "$BRIDGE_UI_PORT" ]]; then
        log "WARNING" "Не удалось найти порт для Bridge UI, пропускаем"
        return 0
    fi
    
    log "INFO" "Обновление Bridge конфигурации (Port: $BRIDGE_UI_PORT)..."
    
    local template="server {
    listen 443 ssl http2;
    server_name bridge.testnet.attra.me;

    ssl_certificate     /etc/letsencrypt/live/da.testnet.attra.me/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/da.testnet.attra.me/privkey.pem;

    location / {
        proxy_pass              http://127.0.0.1:$BRIDGE_UI_PORT;
        proxy_set_header        Host               \$host;
        proxy_set_header        X-Real-IP          \$remote_addr;
        proxy_set_header        X-Forwarded-For    \$proxy_add_x_forwarded_for;
        proxy_set_header        X-Forwarded-Proto  \$scheme;
        proxy_http_version      1.1;
        proxy_set_header        Upgrade            \$http_upgrade;
        proxy_set_header        Connection         \"upgrade\";
    }
}

server {
    listen 80;
    server_name bridge.testnet.attra.me;

    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }

    location / {
        proxy_pass              http://127.0.0.1:$BRIDGE_UI_PORT;
        proxy_set_header        Host               \$host;
        proxy_set_header        X-Real-IP          \$remote_addr;
        proxy_set_header        X-Forwarded-For    \$proxy_add_x_forwarded_for;
        proxy_set_header        X-Forwarded-Proto  \$scheme;
        proxy_http_version      1.1;
        proxy_set_header        Upgrade            \$http_upgrade;
        proxy_set_header        Connection         \"upgrade\";
    }
}"

    create_config "Bridge" "$config_file" "$template"
}

# Функция для обновления DAC конфигурации
update_dac_config() {
    local config_file="$NGINX_CONF_DIR/da.testnet.attra.me.conf"
    
    if [[ -z "$DAC_PORT" ]]; then
        log "WARNING" "Не удалось найти порт для DAC сервиса, пропускаем"
        return 0
    fi
    
    log "INFO" "Обновление DAC конфигурации (Port: $DAC_PORT)..."
    
    local template="server {
    listen 443 ssl http2;
    server_name da.testnet.attra.me;

    ssl_certificate     /etc/letsencrypt/live/da.testnet.attra.me/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/da.testnet.attra.me/privkey.pem;

    location / {
        proxy_pass              http://127.0.0.1:$DAC_PORT;
        proxy_set_header        Host               \$host;
        proxy_set_header        X-Real-IP          \$remote_addr;
        proxy_set_header        X-Forwarded-For    \$proxy_add_x_forwarded_for;
        proxy_set_header        X-Forwarded-Proto  \$scheme;
        proxy_http_version      1.1;
    }
}

server {
    listen 80;
    server_name da.testnet.attra.me;

    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }

    location / {
        proxy_pass              http://127.0.0.1:$DAC_PORT;
        proxy_set_header        Host               \$host;
        proxy_set_header        X-Real-IP          \$remote_addr;
        proxy_set_header        X-Forwarded-For    \$proxy_add_x_forwarded_for;
        proxy_set_header        X-Forwarded-Proto  \$scheme;
        proxy_http_version      1.1;
    }
}"

    create_config "DAC" "$config_file" "$template"
}

# Функция для обновления Faucet конфигурации
update_faucet_config() {
    local config_file="$NGINX_CONF_DIR/faucet.testnet.attra.me.conf"
    
    if [[ -z "$FAUCET_PORT" ]]; then
        log "INFO" "Faucet сервис не найден, пропускаем"
        return 0
    fi
    
    log "INFO" "Обновление Faucet конфигурации (Port: $FAUCET_PORT)..."
    
    local template="server {
    listen 443 ssl http2;
    server_name faucet.testnet.attra.me;

    ssl_certificate     /etc/letsencrypt/live/da.testnet.attra.me/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/da.testnet.attra.me/privkey.pem;

    location / {
        proxy_pass              http://127.0.0.1:$FAUCET_PORT;
        proxy_set_header        Host               \$host;
        proxy_set_header        X-Real-IP          \$remote_addr;
        proxy_set_header        X-Forwarded-For    \$proxy_add_x_forwarded_for;
        proxy_set_header        X-Forwarded-Proto  \$scheme;
        proxy_http_version      1.1;
    }
}

server {
    listen 80;
    server_name faucet.testnet.attra.me;

    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }

    location / {
        proxy_pass              http://127.0.0.1:$FAUCET_PORT;
        proxy_set_header        Host               \$host;
        proxy_set_header        X-Real-IP          \$remote_addr;
        proxy_set_header        X-Forwarded-For    \$proxy_add_x_forwarded_for;
        proxy_set_header        X-Forwarded-Proto  \$scheme;
        proxy_http_version      1.1;
    }
}"

    create_config "Faucet" "$config_file" "$template"
}

# Функция для проверки nginx конфигурации
test_nginx_config() {
    log "INFO" "Проверка nginx конфигурации..."
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log "INFO" "[DRY-RUN] Проверил бы nginx конфигурацию"
        return 0
    fi
    
    if nginx -t >/dev/null 2>&1; then
        log "SUCCESS" "Nginx конфигурация корректна"
        return 0
    else
        log "ERROR" "Nginx конфигурация содержит ошибки:"
        nginx -t
        return 1
    fi
}

# Функция для перезагрузки nginx
reload_nginx() {
    log "INFO" "Перезагрузка nginx..."
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log "INFO" "[DRY-RUN] Перезагрузил бы nginx"
        return 0
    fi
    
    if systemctl reload nginx; then
        log "SUCCESS" "Nginx успешно перезагружен"
        return 0
    else
        log "ERROR" "Не удалось перезагрузить nginx"
        return 1
    fi
}

# Функция для восстановления из бэкапа
restore_from_backup() {
    if [[ "$NO_BACKUP" == "true" ]]; then
        log "ERROR" "Бэкап не был создан (--no-backup), восстановление невозможно"
        return 1
    fi
    
    log "WARNING" "Восстановление конфигураций из бэкапа..."
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log "INFO" "[DRY-RUN] Восстановил бы конфигурации из бэкапа"
        return 0
    fi
    
    cp "$BACKUP_DIR"/*.conf "$NGINX_CONF_DIR/" 2>/dev/null || true
    systemctl reload nginx
    log "SUCCESS" "Конфигурации восстановлены из бэкапа"
}

# Основная функция
main() {
    log "INFO" "Запуск обновления nginx портов для энклава '$ENCLAVE_NAME'"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log "INFO" "Режим DRY-RUN: изменения не будут применены"
    fi
    
    # Проверяем права root
    if [[ $EUID -ne 0 && "$DRY_RUN" == "false" ]]; then
        log "ERROR" "Требуются права root для изменения конфигураций nginx"
        log "INFO" "Попробуйте: sudo $0 $*"
        exit 1
    fi
    
    # Проверяем, что энклав запущен
    if ! kurtosis enclave inspect "$ENCLAVE_NAME" >/dev/null 2>&1; then
        log "ERROR" "Энклав '$ENCLAVE_NAME' не найден или не запущен"
        log "INFO" "Доступные энклавы:"
        kurtosis enclave ls 2>/dev/null || log "ERROR" "Ошибка получения списка энклавов"
        exit 1
    fi
    
    # Создаем лог файл если нужно
    mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || true
    
    # Создаем бэкап
    backup_configs
    
    # Извлекаем порты
    extract_ports
    
    # Обновляем конфигурации
    local configs_updated=0
    
    if update_rpc_config; then
        ((configs_updated++))
    fi
    
    if update_explorer_config; then
        ((configs_updated++))
    fi
    
    if update_bridge_config; then
        ((configs_updated++))
    fi
    
    if update_dac_config; then
        ((configs_updated++))
    fi
    
    if update_faucet_config; then
        ((configs_updated++))
    fi
    
    if [[ $configs_updated -eq 0 ]]; then
        log "WARNING" "Ни одна конфигурация не была обновлена"
        exit 1
    fi
    
    # Проверяем конфигурацию
    if test_nginx_config; then
        # Перезагружаем nginx
        if reload_nginx; then
            log "SUCCESS" "Обновление портов завершено успешно! Обновлено конфигураций: $configs_updated"
        else
            restore_from_backup
            exit 1
        fi
    else
        restore_from_backup
        exit 1
    fi
}

# Запуск скрипта
main "$@" 
