#!/bin/bash

# Script to start automatic nginx port updates
# Installs and activates systemd services for automatic updates

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Функция логирования
log() {
    local level="$1"
    shift
    local message="$*"
    
    case "$level" in
        "INFO")
            echo -e "${BLUE}ℹ️  $message${NC}"
            ;;
        "SUCCESS")
            echo -e "${GREEN}✅ $message${NC}"
            ;;
        "WARNING")
            echo -e "${YELLOW}⚠️  $message${NC}"
            ;;
        "ERROR")
            echo -e "${RED}❌ $message${NC}"
            ;;
    esac
}

# Показать помощь
show_help() {
    cat << EOF
Запуск автоматического обновления nginx портов для Kurtosis CDK

ИСПОЛЬЗОВАНИЕ:
    sudo $0 [ОПЦИИ]

ОПЦИИ:
    -h, --help      Показать эту справку
    -f, --force     Принудительная переустановка сервисов
    --no-timer      Не запускать таймер (только разовый запуск при загрузке)
    --interval=N    Интервал проверки в минутах (по умолчанию: 5)

ОПИСАНИЕ:
    Этот скрипт устанавливает и активирует systemd сервисы для автоматического 
    обновления nginx конфигурации при изменении портов Kurtosis энклава.

    Автоматическое обновление будет выполняться:
    - При загрузке системы (через 2 минуты)
    - Периодически каждые N минут (по умолчанию 5)

ПРИМЕРЫ:
    sudo $0                           # Стандартная установка
    sudo $0 --force                   # Переустановка сервисов
    sudo $0 --no-timer                # Только при загрузке системы
    sudo $0 --interval=10             # Проверка каждые 10 минут

EOF
}

# Конфигурация
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="/opt/attractor/scripts"
SYSTEMD_DIR="/etc/systemd/system"
SERVICE_NAME="nginx-port-updater"
FORCE_INSTALL=false
ENABLE_TIMER=true
CHECK_INTERVAL=5

# Парсинг аргументов
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -f|--force)
            FORCE_INSTALL=true
            shift
            ;;
        --no-timer)
            ENABLE_TIMER=false
            shift
            ;;
        --interval=*)
            CHECK_INTERVAL="${1#*=}"
            shift
            ;;
        -*)
            log "ERROR" "Неизвестная опция: $1"
            exit 1
            ;;
        *)
            log "ERROR" "Неожиданный аргумент: $1"
            exit 1
            ;;
    esac
done

# Проверка прав root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log "ERROR" "Требуются права root для установки сервисов"
        log "INFO" "Попробуйте: sudo $0 $*"
        exit 1
    fi
}

# Проверка зависимостей
check_dependencies() {
    log "INFO" "Проверка зависимостей..."
    
    # Проверяем наличие kurtosis
    if ! command -v kurtosis >/dev/null 2>&1; then
        log "ERROR" "Kurtosis не установлен или не найден в PATH"
        exit 1
    fi
    
    # Проверяем наличие nginx
    if ! command -v nginx >/dev/null 2>&1; then
        log "ERROR" "Nginx не установлен или не найден в PATH"
        exit 1
    fi
    
    # Проверяем наличие systemctl
    if ! command -v systemctl >/dev/null 2>&1; then
        log "ERROR" "systemctl не найден (требуется systemd)"
        exit 1
    fi
    
    log "SUCCESS" "Все зависимости найдены"
}

# Остановка существующих сервисов
stop_existing_services() {
    log "INFO" "Остановка существующих сервисов..."
    
    # Останавливаем и отключаем существующие сервисы
    systemctl stop "${SERVICE_NAME}.timer" 2>/dev/null || true
    systemctl stop "${SERVICE_NAME}.service" 2>/dev/null || true
    systemctl disable "${SERVICE_NAME}.timer" 2>/dev/null || true
    systemctl disable "${SERVICE_NAME}.service" 2>/dev/null || true
    
    log "SUCCESS" "Существующие сервисы остановлены"
}

# Установка файлов
install_files() {
    log "INFO" "Установка файлов..."
    
    # Создаем директории
    mkdir -p "$INSTALL_DIR"
    mkdir -p "/var/log"
    
    # Копируем основной скрипт обновления
    if [[ -f "$SCRIPT_DIR/nginx_update_ports.sh" ]]; then
        cp "$SCRIPT_DIR/nginx_update_ports.sh" "$INSTALL_DIR/"
        chmod +x "$INSTALL_DIR/nginx_update_ports.sh"
        log "SUCCESS" "Скрипт обновления установлен"
    else
        log "ERROR" "Не найден файл nginx_update_ports.sh в $SCRIPT_DIR"
        exit 1
    fi
    
    # Создаем systemd service файл
    cat > "$SYSTEMD_DIR/${SERVICE_NAME}.service" << EOF
[Unit]
Description=Nginx Port Updater for Kurtosis CDK
Documentation=https://github.com/attractor/attractor-cdk-test
Wants=network-online.target
After=network-online.target
After=docker.service
After=nginx.service
Requires=nginx.service

[Service]
Type=oneshot
RemainAfterExit=yes
User=root
Group=root
Environment=ENCLAVE_NAME=cdk
Environment=NGINX_CONF_DIR=/opt/attractor/nginx/conf.d
ExecStartPre=/bin/sleep 30
ExecStartPre=/bin/bash -c 'until kurtosis enclave inspect cdk >/dev/null 2>&1; do echo "Waiting for CDK enclave..."; sleep 10; done'
ExecStart=/bin/bash $INSTALL_DIR/nginx_update_ports.sh
StandardOutput=journal
StandardError=journal
TimeoutStartSec=300

[Install]
WantedBy=multi-user.target
EOF
    
    log "SUCCESS" "Systemd service файл создан"
    
    # Создаем systemd timer файл (если нужен)
    if [[ "$ENABLE_TIMER" == "true" ]]; then
        cat > "$SYSTEMD_DIR/${SERVICE_NAME}.timer" << EOF
[Unit]
Description=Nginx Port Updater Timer for Kurtosis CDK
Documentation=https://github.com/attractor/attractor-cdk-test
Requires=${SERVICE_NAME}.service

[Timer]
OnBootSec=2min
OnUnitActiveSec=${CHECK_INTERVAL}min
Persistent=true

[Install]
WantedBy=timers.target
EOF
        log "SUCCESS" "Systemd timer файл создан (интервал: ${CHECK_INTERVAL} минут)"
    fi
}

# Активация сервисов
activate_services() {
    log "INFO" "Активация systemd сервисов..."
    
    # Перезагружаем systemd
    systemctl daemon-reload
    
    # Включаем и запускаем сервис
    systemctl enable "${SERVICE_NAME}.service"
    log "SUCCESS" "Сервис ${SERVICE_NAME}.service включен"
    
    # Включаем и запускаем таймер (если нужен)
    if [[ "$ENABLE_TIMER" == "true" ]]; then
        systemctl enable "${SERVICE_NAME}.timer"
        systemctl start "${SERVICE_NAME}.timer"
        log "SUCCESS" "Таймер ${SERVICE_NAME}.timer запущен"
    fi
}

# Проверка статуса
check_status() {
    log "INFO" "Проверка статуса сервисов..."
    
    echo ""
    echo "=== Статус сервиса ==="
    systemctl status "${SERVICE_NAME}.service" --no-pager -l || true
    
    if [[ "$ENABLE_TIMER" == "true" ]]; then
        echo ""
        echo "=== Статус таймера ==="
        systemctl status "${SERVICE_NAME}.timer" --no-pager -l || true
        
        echo ""
        echo "=== Расписание таймера ==="
        systemctl list-timers "${SERVICE_NAME}.timer" --no-pager || true
    fi
}

# Тестовый запуск
test_run() {
    log "INFO" "Выполнение тестового запуска..."
    
    read -p "Хотите выполнить тестовый запуск обновления портов? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log "INFO" "Запуск тестового обновления..."
        systemctl start "${SERVICE_NAME}.service"
        
        echo ""
        log "INFO" "Результат тестового запуска:"
        journalctl -u "${SERVICE_NAME}.service" -n 20 --no-pager
        
        echo ""
        log "SUCCESS" "Тестовый запуск завершен. Проверьте результаты выше."
    fi
}

# Показать инструкции по использованию
show_usage_instructions() {
    echo ""
    log "SUCCESS" "Автоматическое обновление nginx портов успешно настроено!"
    echo ""
    
    echo "📋 ДОСТУПНЫЕ КОМАНДЫ:"
    echo "  Ручной запуск:              sudo systemctl start ${SERVICE_NAME}.service"
    echo "  Проверка статуса сервиса:   sudo systemctl status ${SERVICE_NAME}.service"
    if [[ "$ENABLE_TIMER" == "true" ]]; then
        echo "  Проверка статуса таймера:   sudo systemctl status ${SERVICE_NAME}.timer"
        echo "  Остановка автообновления:   sudo systemctl stop ${SERVICE_NAME}.timer"
        echo "  Отключение автообновления:  sudo systemctl disable ${SERVICE_NAME}.timer"
    fi
    echo "  Просмотр логов:             sudo journalctl -u ${SERVICE_NAME}.service -f"
    echo "  Просмотр логов скрипта:     sudo tail -f /var/log/nginx-port-updater.log"
    echo ""
    
    echo "⚙️  НАСТРОЙКИ:"
    echo "  Энклав:                     cdk"
    echo "  Путь к nginx конфигам:      /opt/attractor/nginx/conf.d"
    if [[ "$ENABLE_TIMER" == "true" ]]; then
        echo "  Интервал проверки:          каждые ${CHECK_INTERVAL} минут"
        echo "  Запуск при загрузке:        через 2 минуты после старта системы"
    else
        echo "  Режим:                      только при загрузке системы"
    fi
    echo ""
    
    if [[ "$ENABLE_TIMER" == "true" ]]; then
        echo "🔄 АВТОМАТИЧЕСКОЕ ОБНОВЛЕНИЕ:"
        echo "  Система будет автоматически проверять и обновлять порты nginx"
        echo "  при изменениях в Kurtosis энклаве каждые ${CHECK_INTERVAL} минут."
    else
        echo "🔄 ОБНОВЛЕНИЕ ПРИ ЗАГРУЗКЕ:"
        echo "  Система будет обновлять порты nginx только при загрузке сервера."
    fi
    echo ""
    
    echo "📝 ДЛЯ ОСТАНОВКИ АВТООБНОВЛЕНИЯ:"
    echo "  sudo ./nginx_auto_stop.sh"
    echo ""
}

# Основная функция
main() {
    echo "🚀 Установка автоматического обновления nginx портов"
    echo "============================================="
    
    # Проверки
    check_root
    check_dependencies
    
    # Проверяем, нужна ли переустановка
    if [[ "$FORCE_INSTALL" == "false" ]] && systemctl is-enabled "${SERVICE_NAME}.service" >/dev/null 2>&1; then
        log "WARNING" "Сервис уже установлен и активен"
        read -p "Хотите переустановить? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log "INFO" "Установка отменена"
            exit 0
        fi
        FORCE_INSTALL=true
    fi
    
    # Установка
    if [[ "$FORCE_INSTALL" == "true" ]]; then
        stop_existing_services
    fi
    
    install_files
    activate_services
    check_status
    test_run
    show_usage_instructions
    
    log "SUCCESS" "Установка завершена успешно!"
}

# Запуск скрипта
main "$@" 
