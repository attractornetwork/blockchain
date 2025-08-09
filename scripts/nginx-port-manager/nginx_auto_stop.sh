#!/bin/bash

# Script to stop automatic nginx port updates
# Stops and disables systemd services for automatic updates

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
Остановка автоматического обновления nginx портов для Kurtosis CDK

ИСПОЛЬЗОВАНИЕ:
    sudo $0 [ОПЦИИ]

ОПЦИИ:
    -h, --help      Показать эту справку
    -f, --force     Принудительная остановка без подтверждения
    --remove        Полностью удалить все файлы сервисов
    --keep-config   Оставить конфигурационные файлы nginx

ОПИСАНИЕ:
    Этот скрипт останавливает и отключает systemd сервисы автоматического 
    обновления nginx портов для Kurtosis CDK.

    По умолчанию сервисы только останавливаются и отключаются, но файлы
    остаются для возможности повторного запуска.

ПРИМЕРЫ:
    sudo $0                    # Обычная остановка
    sudo $0 --force            # Остановка без подтверждения
    sudo $0 --remove           # Полное удаление сервисов
    sudo $0 --remove --force   # Полное удаление без подтверждения

EOF
}

# Конфигурация
INSTALL_DIR="/opt/attractor/scripts"
SYSTEMD_DIR="/etc/systemd/system"
SERVICE_NAME="nginx-port-updater"
FORCE_STOP=false
REMOVE_FILES=false
KEEP_CONFIG=false

# Парсинг аргументов
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -f|--force)
            FORCE_STOP=true
            shift
            ;;
        --remove)
            REMOVE_FILES=true
            shift
            ;;
        --keep-config)
            KEEP_CONFIG=true
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
        log "ERROR" "Требуются права root для управления сервисами"
        log "INFO" "Попробуйте: sudo $0 $*"
        exit 1
    fi
}

# Проверка статуса сервисов
check_service_status() {
    local service_active=false
    local timer_active=false
    
    if systemctl is-active "${SERVICE_NAME}.service" >/dev/null 2>&1; then
        service_active=true
    fi
    
    if systemctl is-active "${SERVICE_NAME}.timer" >/dev/null 2>&1; then
        timer_active=true
    fi
    
    if [[ "$service_active" == "false" && "$timer_active" == "false" ]]; then
        if systemctl is-enabled "${SERVICE_NAME}.service" >/dev/null 2>&1 || systemctl is-enabled "${SERVICE_NAME}.timer" >/dev/null 2>&1; then
            log "INFO" "Сервисы отключены, но включены для автозапуска"
            return 1
        else
            log "INFO" "Сервисы автоматического обновления уже остановлены"
            return 2
        fi
    fi
    
    return 0
}

# Показать текущий статус
show_current_status() {
    log "INFO" "Проверка текущего статуса сервисов..."
    
    echo ""
    echo "=== Текущий статус ==="
    
    # Проверяем сервис
    if systemctl is-enabled "${SERVICE_NAME}.service" >/dev/null 2>&1; then
        local service_status=$(systemctl is-active "${SERVICE_NAME}.service" 2>/dev/null || echo "inactive")
        echo "  Сервис ${SERVICE_NAME}.service: включен ($service_status)"
    else
        echo "  Сервис ${SERVICE_NAME}.service: отключен"
    fi
    
    # Проверяем таймер
    if systemctl is-enabled "${SERVICE_NAME}.timer" >/dev/null 2>&1; then
        local timer_status=$(systemctl is-active "${SERVICE_NAME}.timer" 2>/dev/null || echo "inactive")
        echo "  Таймер ${SERVICE_NAME}.timer: включен ($timer_status)"
        
        # Показываем расписание таймера
        if [[ "$timer_status" == "active" ]]; then
            echo ""
            echo "=== Расписание таймера ==="
            systemctl list-timers "${SERVICE_NAME}.timer" --no-pager 2>/dev/null || true
        fi
    else
        echo "  Таймер ${SERVICE_NAME}.timer: отключен"
    fi
    
    echo ""
}

# Подтверждение действия
confirm_action() {
    if [[ "$FORCE_STOP" == "true" ]]; then
        return 0
    fi
    
    local action_type="остановить"
    if [[ "$REMOVE_FILES" == "true" ]]; then
        action_type="полностью удалить"
    fi
    
    echo "❓ Вы действительно хотите $action_type автоматическое обновление nginx портов?"
    if [[ "$REMOVE_FILES" == "true" ]]; then
        echo "⚠️  Это действие нельзя будет отменить!"
    fi
    echo ""
    
    read -p "Продолжить? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log "INFO" "Операция отменена пользователем"
        exit 0
    fi
}

# Остановка сервисов
stop_services() {
    log "INFO" "Остановка и отключение сервисов..."
    
    # Останавливаем таймер
    if systemctl is-active "${SERVICE_NAME}.timer" >/dev/null 2>&1; then
        systemctl stop "${SERVICE_NAME}.timer"
        log "SUCCESS" "Таймер ${SERVICE_NAME}.timer остановлен"
    fi
    
    # Отключаем таймер
    if systemctl is-enabled "${SERVICE_NAME}.timer" >/dev/null 2>&1; then
        systemctl disable "${SERVICE_NAME}.timer"
        log "SUCCESS" "Таймер ${SERVICE_NAME}.timer отключен"
    fi
    
    # Останавливаем сервис
    if systemctl is-active "${SERVICE_NAME}.service" >/dev/null 2>&1; then
        systemctl stop "${SERVICE_NAME}.service"
        log "SUCCESS" "Сервис ${SERVICE_NAME}.service остановлен"
    fi
    
    # Отключаем сервис
    if systemctl is-enabled "${SERVICE_NAME}.service" >/dev/null 2>&1; then
        systemctl disable "${SERVICE_NAME}.service"
        log "SUCCESS" "Сервис ${SERVICE_NAME}.service отключен"
    fi
    
    # Перезагружаем systemd
    systemctl daemon-reload
    log "SUCCESS" "systemd daemon перезагружен"
}

# Удаление файлов
remove_files() {
    if [[ "$REMOVE_FILES" == "false" ]]; then
        return 0
    fi
    
    log "INFO" "Удаление файлов сервисов..."
    
    # Удаляем systemd файлы
    if [[ -f "$SYSTEMD_DIR/${SERVICE_NAME}.service" ]]; then
        rm -f "$SYSTEMD_DIR/${SERVICE_NAME}.service"
        log "SUCCESS" "Удален файл ${SERVICE_NAME}.service"
    fi
    
    if [[ -f "$SYSTEMD_DIR/${SERVICE_NAME}.timer" ]]; then
        rm -f "$SYSTEMD_DIR/${SERVICE_NAME}.timer"
        log "SUCCESS" "Удален файл ${SERVICE_NAME}.timer"
    fi
    
    # Удаляем скрипт обновления
    if [[ -f "$INSTALL_DIR/nginx_update_ports.sh" ]]; then
        rm -f "$INSTALL_DIR/nginx_update_ports.sh"
        log "SUCCESS" "Удален скрипт nginx_update_ports.sh"
    fi
    
    # Удаляем старый скрипт если есть
    if [[ -f "$INSTALL_DIR/update_nginx_ports.sh" ]]; then
        rm -f "$INSTALL_DIR/update_nginx_ports.sh"
        log "SUCCESS" "Удален старый скрипт update_nginx_ports.sh"
    fi
    
    # Удаляем директорию если она пустая
    if [[ -d "$INSTALL_DIR" ]] && [[ -z "$(ls -A "$INSTALL_DIR" 2>/dev/null)" ]]; then
        rmdir "$INSTALL_DIR"
        log "SUCCESS" "Удалена пустая директория $INSTALL_DIR"
    fi
    
    # Перезагружаем systemd после удаления файлов
    systemctl daemon-reload
    log "SUCCESS" "systemd daemon перезагружен после удаления файлов"
}

# Очистка логов (опционально)
clean_logs() {
    if [[ "$REMOVE_FILES" == "false" ]]; then
        return 0
    fi
    
    read -p "Удалить также логи автоматического обновления? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        # Очищаем журнал systemd
        journalctl --vacuum-time=1s --unit="${SERVICE_NAME}.service" >/dev/null 2>&1 || true
        journalctl --vacuum-time=1s --unit="${SERVICE_NAME}.timer" >/dev/null 2>&1 || true
        
        # Удаляем лог файл
        if [[ -f "/var/log/nginx-port-updater.log" ]]; then
            rm -f "/var/log/nginx-port-updater.log"
            log "SUCCESS" "Лог файл /var/log/nginx-port-updater.log удален"
        fi
        
        log "SUCCESS" "Логи очищены"
    fi
}

# Показать информацию о восстановлении
show_restore_info() {
    echo ""
    log "SUCCESS" "Автоматическое обновление nginx портов остановлено!"
    echo ""
    
    if [[ "$REMOVE_FILES" == "true" ]]; then
        echo "🗑️  ФАЙЛЫ УДАЛЕНЫ:"
        echo "  Все файлы сервисов полностью удалены из системы."
        echo ""
        echo "🔄 ДЛЯ ПОВТОРНОГО ВКЛЮЧЕНИЯ:"
        echo "  Вам потребуется заново запустить установку:"
        echo "  sudo ./nginx_auto_start.sh"
    else
        echo "💾 ФАЙЛЫ СОХРАНЕНЫ:"
        echo "  Файлы сервисов сохранены для возможности повторного запуска."
        echo ""
        echo "🔄 ДЛЯ ПОВТОРНОГО ВКЛЮЧЕНИЯ:"
        echo "  sudo systemctl enable ${SERVICE_NAME}.service"
        echo "  sudo systemctl enable ${SERVICE_NAME}.timer"
        echo "  sudo systemctl start ${SERVICE_NAME}.timer"
        echo ""
        echo "  Или запустите: sudo ./nginx_auto_start.sh"
    fi
    echo ""
    
    echo "📝 РУЧНОЕ ОБНОВЛЕНИЕ ПОРТОВ:"
    echo "  sudo ./nginx_update_ports.sh"
    echo ""
    
    echo "📋 ПРОВЕРКА СТАТУСА:"
    echo "  sudo systemctl status ${SERVICE_NAME}.service"
    echo "  sudo systemctl status ${SERVICE_NAME}.timer"
    echo ""
}

# Проверка финального статуса
check_final_status() {
    log "INFO" "Проверка финального статуса..."
    
    local all_stopped=true
    
    if systemctl is-enabled "${SERVICE_NAME}.service" >/dev/null 2>&1; then
        all_stopped=false
    fi
    
    if systemctl is-enabled "${SERVICE_NAME}.timer" >/dev/null 2>&1; then
        all_stopped=false
    fi
    
    if systemctl is-active "${SERVICE_NAME}.service" >/dev/null 2>&1; then
        all_stopped=false
    fi
    
    if systemctl is-active "${SERVICE_NAME}.timer" >/dev/null 2>&1; then
        all_stopped=false
    fi
    
    if [[ "$all_stopped" == "true" ]]; then
        log "SUCCESS" "Все сервисы успешно остановлены и отключены"
    else
        log "WARNING" "Некоторые сервисы могут быть еще активны"
        show_current_status
    fi
}

# Основная функция
main() {
    echo "🛑 Остановка автоматического обновления nginx портов"
    echo "=================================================="
    
    # Проверки
    check_root
    
    # Проверяем статус
    show_current_status
    
    local status_check
    check_service_status
    status_check=$?
    
    if [[ $status_check -eq 2 ]]; then
        if [[ "$REMOVE_FILES" == "false" ]]; then
            log "INFO" "Нечего останавливать"
            exit 0
        else
            log "INFO" "Сервисы уже остановлены, но файлы все еще существуют"
        fi
    fi
    
    # Подтверждение
    confirm_action
    
    # Остановка
    stop_services
    
    # Удаление файлов (если нужно)
    remove_files
    
    # Очистка логов (если нужно)
    clean_logs
    
    # Проверка результата
    check_final_status
    
    # Информация о восстановлении
    show_restore_info
    
    log "SUCCESS" "Операция завершена успешно!"
}

# Запуск скрипта
main "$@" 
