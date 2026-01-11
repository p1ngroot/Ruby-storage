#!/bin/bash

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Определение директории проекта
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Очистка экрана и вывод логотипа
clear
echo -e "${PURPLE}${BOLD}"
cat << "EOF"
╔════════════════════════════════════════════════════════════════╗
║                                                                ║
║       ____        __             _____ __                      ║
║      / __ \__  __/ /_  __  __   / ___// /_____  _________ ___ ║
║     / /_/ / / / / __ \/ / / /   \__ \/ __/ __ \/ ___/ __ `__ \║
║    / _, _/ /_/ / /_/ / /_/ /   ___/ / /_/ /_/ / /  / / / / / /║
║   /_/ |_|\__,_/_.___/\__, /   /____/\__/\____/_/  /_/ /_/ /_/ ║
║                     /____/                                     ║
║                                                                ║
║              Автоматический деплой на сервер                  ║
║                                                                ║
╚════════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}\n"

# Функция для ввода с валидацией
input_required() {
    local prompt="$1"
    local var_name="$2"
    local value=""
    
    while [ -z "$value" ]; do
        read -p "$(echo -e ${CYAN}${prompt}${NC})" value
        if [ -z "$value" ]; then
            echo -e "${RED}Это поле обязательно для заполнения!${NC}"
        fi
    done
    
    eval "$var_name='$value'"
}

# Функция для ввода пароля
input_password() {
    local prompt="$1"
    local var_name="$2"
    local value=""
    
    while [ -z "$value" ]; do
        read -s -p "$(echo -e ${CYAN}${prompt}${NC})" value
        echo
        if [ -z "$value" ]; then
            echo -e "${RED}Пароль не может быть пустым!${NC}"
        fi
    done
    
    eval "$var_name='$value'"
}

# Функция для выбора да/нет
input_yes_no() {
    local prompt="$1"
    local default="$2"
    local response=""
    
    while true; do
        if [ "$default" = "yes" ]; then
            read -p "$(echo -e ${YELLOW}${prompt}' (yes/no) [yes]: '${NC})" response
            response=${response:-yes}
        else
            read -p "$(echo -e ${YELLOW}${prompt}' (yes/no) [no]: '${NC})" response
            response=${response:-no}
        fi
        
        case "$response" in
            yes|y|Y|YES) return 0 ;;
            no|n|N|NO) return 1 ;;
            *) echo -e "${RED}Пожалуйста, введите 'yes' или 'no'${NC}" ;;
        esac
    done
}

# ============================================================================
# Шаг 0: Выбор директории проекта
# ============================================================================
echo -e "${GREEN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}${BOLD}  ШАГ 0: Выбор директории проекта${NC}"
echo -e "${GREEN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

# Определение текущей директории
CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo -e "${CYAN}Текущая директория скрипта:${NC} ${YELLOW}$CURRENT_DIR${NC}\n"
echo -e "${CYAN}Примеры путей:${NC}"
echo -e "  • ${BLUE}/home/username/Документы/ruby-storage${NC} (Linux)"
echo -e "  • ${BLUE}/home/username/Documents/ruby-storage${NC} (English locale)"
echo -e "  • ${BLUE}/root/projects/ruby-storage${NC}"
echo -e "  • ${BLUE}$(pwd)${NC} (текущая директория)\n"

read -p "$(echo -e ${CYAN}'Путь к директории проекта ['${CURRENT_DIR}']: '${NC})" PROJECT_DIR
PROJECT_DIR=${PROJECT_DIR:-$CURRENT_DIR}

# Проверка существования директории
if [ ! -d "$PROJECT_DIR" ]; then
    echo -e "${RED}✗ Ошибка: Директория не существует!${NC}"
    exit 1
fi

# Проверка наличия необходимых файлов
if [ ! -f "$PROJECT_DIR/app.py" ] || [ ! -f "$PROJECT_DIR/requirements.txt" ]; then
    echo -e "${RED}✗ Ошибка: Не найдены файлы проекта (app.py, requirements.txt)${NC}"
    echo -e "${YELLOW}Убедитесь что указана правильная директория проекта Ruby Storage${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Директория проекта найдена:${NC} ${YELLOW}$PROJECT_DIR${NC}\n"

# ============================================================================
# Шаг 1: Данные для подключения к серверу
# ============================================================================
echo -e "${GREEN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}${BOLD}  ШАГ 1: Данные для подключения к серверу${NC}"
echo -e "${GREEN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

input_required "IP адрес сервера: " SERVER_IP
read -p "$(echo -e ${CYAN}'SSH порт [22]: '${NC})" SSH_PORT
SSH_PORT=${SSH_PORT:-22}
input_required "Имя пользователя (root): " SERVER_USER

echo
echo -e "${YELLOW}Выберите метод аутентификации:${NC}"
echo -e "  1) Пароль"
echo -e "  2) SSH ключ"
read -p "$(echo -e ${CYAN}'Ваш выбор [1]: '${NC})" AUTH_METHOD
AUTH_METHOD=${AUTH_METHOD:-1}

if [ "$AUTH_METHOD" = "1" ]; then
    USE_SSH_KEY=false
    input_password "Пароль пользователя: " SERVER_PASSWORD
    
    # Проверка установки sshpass
    if ! command -v sshpass &> /dev/null; then
        echo -e "\n${RED}Ошибка: sshpass не установлен!${NC}"
        echo -e "${YELLOW}Установите его командой: sudo apt install sshpass${NC}"
        exit 1
    fi
else
    USE_SSH_KEY=true
    read -p "$(echo -e ${CYAN}'Путь к SSH ключу [~/.ssh/id_rsa]: '${NC})" SSH_KEY_PATH
    SSH_KEY_PATH=${SSH_KEY_PATH:-~/.ssh/id_rsa}
    SSH_KEY_PATH="${SSH_KEY_PATH/#\~/$HOME}"
    
    if [ ! -f "$SSH_KEY_PATH" ]; then
        echo -e "\n${RED}Ошибка: SSH ключ не найден по пути $SSH_KEY_PATH${NC}"
        exit 1
    fi
fi

echo

# Проверка подключения
echo -e "${BLUE}Проверка подключения к серверу...${NC}"

# Очистка старых SSH ключей для этого хоста
echo -e "${YELLOW}Очистка старых SSH ключей...${NC}"
ssh-keygen -R "$SERVER_IP" 2>/dev/null
if [ "$SSH_PORT" != "22" ]; then
    ssh-keygen -R "[$SERVER_IP]:$SSH_PORT" 2>/dev/null
fi

if [ "$USE_SSH_KEY" = true ]; then
    SSH_CMD="ssh -i $SSH_KEY_PATH -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10 -p $SSH_PORT $SERVER_USER@$SERVER_IP"
    if $SSH_CMD "echo 'OK'" 2>/dev/null; then
        echo -e "${GREEN}✓ Подключение успешно установлено!${NC}\n"
    else
        echo -e "${RED}✗ Не удалось подключиться к серверу!${NC}"
        echo -e "${YELLOW}Попытка подключения с выводом ошибок:${NC}\n"
        $SSH_CMD "echo 'OK'"
        echo
        echo -e "${YELLOW}Убедитесь что:${NC}"
        echo -e "  • Сервер доступен: ping $SERVER_IP"
        echo -e "  • SSH порт открыт: nc -zv $SERVER_IP $SSH_PORT"
        echo -e "  • SSH ключ правильный и добавлен на сервер"
        echo -e "  • Пользователь $SERVER_USER существует\n"
        exit 1
    fi
else
    if sshpass -p "$SERVER_PASSWORD" ssh -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10 -p $SSH_PORT $SERVER_USER@$SERVER_IP "echo 'OK'" 2>/dev/null; then
        echo -e "${GREEN}✓ Подключение успешно установлено!${NC}\n"
    else
        echo -e "${RED}✗ Не удалось подключиться к серверу!${NC}"
        echo -e "${YELLOW}Попытка подключения с выводом ошибок:${NC}\n"
        sshpass -p "$SERVER_PASSWORD" ssh -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10 -p $SSH_PORT $SERVER_USER@$SERVER_IP "echo 'OK'"
        echo
        echo -e "${YELLOW}Возможные причины:${NC}"
        echo -e "  • Сервер недоступен: ping $SERVER_IP"
        echo -e "  • SSH порт закрыт: nc -zv $SERVER_IP $SSH_PORT"
        echo -e "  • Неверный логин или пароль"
        echo -e "  • Аутентификация по паролю отключена (попробуйте SSH ключ)"
        echo -e "  • Файрвол блокирует подключение\n"
        echo -e "${CYAN}Для включения аутентификации по паролю на сервере:${NC}"
        echo -e "  1. ${BLUE}nano /etc/ssh/sshd_config${NC}"
        echo -e "  2. Найдите и измените: ${BLUE}PasswordAuthentication yes${NC}"
        echo -e "  3. Перезапустите SSH: ${BLUE}systemctl restart sshd${NC}\n"
        exit 1
    fi
fi

# ============================================================================
# Шаг 2: Настройка учетных данных для входа в хранилище
# ============================================================================
echo -e "${GREEN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}${BOLD}  ШАГ 2: Настройка входа в хранилище${NC}"
echo -e "${GREEN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

echo -e "${CYAN}Настройте логин и пароль для доступа к веб-интерфейсу Ruby Storage${NC}\n"

input_required "Логин для входа в хранилище: " STORAGE_USERNAME
input_password "Пароль для входа в хранилище: " STORAGE_PASSWORD

# Подтверждение пароля
while true; do
    input_password "Повторите пароль: " STORAGE_PASSWORD_CONFIRM
    
    if [ "$STORAGE_PASSWORD" = "$STORAGE_PASSWORD_CONFIRM" ]; then
        echo -e "${GREEN}✓ Пароли совпадают${NC}\n"
        break
    else
        echo -e "${RED}✗ Пароли не совпадают! Попробуйте еще раз.${NC}\n"
        input_password "Пароль для входа в хранилище: " STORAGE_PASSWORD
    fi
done

# Генерация SHA256 хеша пароля
STORAGE_PASSWORD_HASH=$(echo -n "$STORAGE_PASSWORD" | sha256sum | awk '{print $1}')

echo -e "${CYAN}Учетные данные для входа:${NC}"
echo -e "  • Логин: ${YELLOW}$STORAGE_USERNAME${NC}"
echo -e "  • Пароль: ${YELLOW}********${NC} (скрыт)"
echo -e "  • Hash: ${YELLOW}${STORAGE_PASSWORD_HASH:0:16}...${NC}\n"

# ============================================================================
# Шаг 3: Настройка домена и SSL (было Шаг 2)
# ============================================================================
echo -e "${GREEN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}${BOLD}  ШАГ 3: Настройка домена и SSL${NC}"
echo -e "${GREEN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

input_required "Доменное имя (например, storage.example.com): " DOMAIN

if input_yes_no "У вас уже есть SSL сертификат?" "no"; then
    USE_EXISTING_SSL=true
    input_required "Путь к файлу сертификата (cert.pem) на сервере: " SSL_CERT_PATH
    input_required "Путь к приватному ключу (key.pem) на сервере: " SSL_KEY_PATH
else
    USE_EXISTING_SSL=false
    input_required "Email для получения Let's Encrypt сертификата: " LETSENCRYPT_EMAIL
fi

echo

# ============================================================================
# Шаг 4: Настройка приложения (было Шаг 3)
# ============================================================================
echo -e "${GREEN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}${BOLD}  ШАГ 4: Настройка приложения${NC}"
echo -e "${GREEN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

read -p "$(echo -e ${CYAN}'Директория установки на сервере [/opt/ruby-storage]: '${NC})" INSTALL_DIR
INSTALL_DIR=${INSTALL_DIR:-/opt/ruby-storage}

echo

# ============================================================================
# Шаг 5: Подтверждение (было Шаг 4)
# ============================================================================
echo -e "${GREEN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}${BOLD}  ШАГ 5: Подтверждение${NC}"
echo -e "${GREEN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

echo -e "${CYAN}Проверьте введённые данные:${NC}\n"
echo -e "  ${BOLD}Проект:${NC}"
echo -e "    • Директория: ${YELLOW}$PROJECT_DIR${NC}"
echo
echo -e "  ${BOLD}Сервер:${NC}"
echo -e "    • IP: ${YELLOW}$SERVER_IP${NC}"
echo -e "    • Порт: ${YELLOW}$SSH_PORT${NC}"
echo -e "    • Пользователь: ${YELLOW}$SERVER_USER${NC}"
echo -e "    • Директория установки: ${YELLOW}$INSTALL_DIR${NC}"
echo
echo -e "  ${BOLD}Вход в хранилище:${NC}"
echo -e "    • Логин: ${YELLOW}$STORAGE_USERNAME${NC}"
echo -e "    • Пароль: ${YELLOW}********${NC}"
echo
echo -e "  ${BOLD}Домен и SSL:${NC}"
echo -e "    • Домен: ${YELLOW}$DOMAIN${NC}"
if [ "$USE_EXISTING_SSL" = true ]; then
    echo -e "    • SSL: ${YELLOW}Использовать существующий${NC}"
    echo -e "    • Сертификат: ${YELLOW}$SSL_CERT_PATH${NC}"
    echo -e "    • Ключ: ${YELLOW}$SSL_KEY_PATH${NC}"
else
    echo -e "    • SSL: ${YELLOW}Получить Let's Encrypt${NC}"
    echo -e "    • Email: ${YELLOW}$LETSENCRYPT_EMAIL${NC}"
fi
echo

if ! input_yes_no "Начать установку?" "yes"; then
    echo -e "${YELLOW}Установка отменена.${NC}"
    exit 0
fi

echo

# Начало установки
echo -e "${GREEN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}${BOLD}  Начинаем установку...${NC}"
echo -e "${GREEN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

# Функция для выполнения команд на сервере
run_remote() {
    if [ "$USE_SSH_KEY" = true ]; then
        ssh -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=accept-new -p $SSH_PORT $SERVER_USER@$SERVER_IP "$1"
    else
        sshpass -p "$SERVER_PASSWORD" ssh -o StrictHostKeyChecking=accept-new -p $SSH_PORT $SERVER_USER@$SERVER_IP "$1"
    fi
}

# Функция для копирования файлов
scp_remote() {
    local source="$1"
    local dest="$2"
    
    if [ "$USE_SSH_KEY" = true ]; then
        scp -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=accept-new -P $SSH_PORT "$source" $SERVER_USER@$SERVER_IP:"$dest"
    else
        sshpass -p "$SERVER_PASSWORD" scp -o StrictHostKeyChecking=accept-new -P $SSH_PORT "$source" $SERVER_USER@$SERVER_IP:"$dest"
    fi
}

# Шаг 5: Копирование файлов
echo -e "${BLUE}[1/8] Копирование файлов на сервер...${NC}"

# Проверка существующей установки
echo -e "${BLUE}Проверка существующей установки...${NC}\n"

if [ "$USE_SSH_KEY" = true ]; then
    EXISTING_INSTALL=$(ssh -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=accept-new -p $SSH_PORT $SERVER_USER@$SERVER_IP "[ -d '/opt/ruby-storage' ] && echo 'exists' || echo 'new'" 2>/dev/null)
else
    EXISTING_INSTALL=$(sshpass -p "$SERVER_PASSWORD" ssh -o StrictHostKeyChecking=accept-new -p $SSH_PORT $SERVER_USER@$SERVER_IP "[ -d '/opt/ruby-storage' ] && echo 'exists' || echo 'new'" 2>/dev/null)
fi

if [ "$EXISTING_INSTALL" = "exists" ]; then
    echo -e "${YELLOW}⚠ Обнаружена существующая установка Ruby Storage!${NC}\n"
    echo -e "${CYAN}Выберите действие:${NC}"
    echo -e "  ${BOLD}1)${NC} Обновить (сохранить данные и настройки)"
    echo -e "  ${BOLD}2)${NC} Переустановить (удалить всё и установить заново)"
    echo -e "  ${BOLD}3)${NC} Отмена"
    echo
    read -p "$(echo -e ${CYAN}'Ваш выбор [1]: '${NC})" INSTALL_MODE
    INSTALL_MODE=${INSTALL_MODE:-1}
    
    case "$INSTALL_MODE" in
        1)
            echo -e "${GREEN}Режим обновления выбран${NC}\n"
            UPDATE_MODE=true
            ;;
        2)
            echo -e "${YELLOW}Режим переустановки выбран${NC}"
            if input_yes_no "Вы уверены? Все данные будут удалены!" "no"; then
                echo -e "${RED}Удаление старой установки...${NC}"
                run_remote "systemctl stop ruby-storage 2>/dev/null || true"
                run_remote "systemctl disable ruby-storage 2>/dev/null || true"
                run_remote "rm -rf /opt/ruby-storage"
                run_remote "rm -f /etc/systemd/system/ruby-storage.service"
                run_remote "rm -f /etc/nginx/sites-enabled/ruby-storage"
                run_remote "rm -f /etc/nginx/sites-available/ruby-storage"
                echo -e "${GREEN}✓ Старая установка удалена${NC}\n"
                UPDATE_MODE=false
            else
                echo -e "${YELLOW}Отмена переустановки${NC}"
                exit 0
            fi
            ;;
        3)
            echo -e "${YELLOW}Установка отменена${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}Неверный выбор${NC}"
            exit 1
            ;;
    esac
else
    UPDATE_MODE=false
fi

if [ "$UPDATE_MODE" = true ]; then
    echo -e "${YELLOW}  Создание резервной копии uploads...${NC}"
    run_remote "[ -d '$INSTALL_DIR/uploads' ] && cp -r $INSTALL_DIR/uploads /tmp/ruby-storage-backup-uploads || true"
fi

run_remote "mkdir -p $INSTALL_DIR"

# Создание архива проекта
cd "$PROJECT_DIR"

# Создаем static директорию если не существует
mkdir -p static

# Создаем favicon.svg если не существует
if [ ! -f "static/favicon.svg" ]; then
    cat > static/favicon.svg << 'EOFFAVICON'
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
  <defs>
    <linearGradient id="rubyGrad" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" style="stop-color:#e74c3c;stop-opacity:1" />
      <stop offset="50%" style="stop-color:#c0392b;stop-opacity:1" />
      <stop offset="100%" style="stop-color:#8e2d23;stop-opacity:1" />
    </linearGradient>
    <linearGradient id="shine" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" style="stop-color:#ffffff;stop-opacity:0.4" />
      <stop offset="100%" style="stop-color:#ffffff;stop-opacity:0" />
    </linearGradient>
  </defs>
  <path d="M 50 10 L 70 30 L 80 50 L 50 90 L 20 50 L 30 30 Z" fill="url(#rubyGrad)" stroke="#5a1a13" stroke-width="2"/>
  <path d="M 50 10 L 50 90" stroke="#8e2d23" stroke-width="1.5" opacity="0.5"/>
  <path d="M 30 30 L 80 50" stroke="#8e2d23" stroke-width="1.5" opacity="0.3"/>
  <path d="M 70 30 L 20 50" stroke="#8e2d23" stroke-width="1.5" opacity="0.3"/>
  <path d="M 50 10 L 70 30 L 50 40 Z" fill="url(#shine)"/>
  <circle cx="45" cy="25" r="6" fill="#ffffff" opacity="0.6"/>
  <circle cx="58" cy="35" r="4" fill="#ffffff" opacity="0.4"/>
</svg>
EOFFAVICON
fi

# Настройка учетных данных в app.py
echo -e "${YELLOW}  Настройка учетных данных...${NC}"

# Создаём модифицированный app.py напрямую
cat > /tmp/app.py << EOFAPPPY
from flask import Flask, render_template, request, jsonify, send_file, session, redirect, url_for, send_from_directory
from werkzeug.utils import secure_filename
import os
import shutil
import hashlib
from datetime import datetime
from functools import wraps

app = Flask(__name__)
app.secret_key = 'ruby_secret_key_change_in_production'
app.config['UPLOAD_FOLDER'] = 'uploads'
app.config['MAX_CONTENT_LENGTH'] = 16 * 1024 * 1024 * 1024

os.makedirs(app.config['UPLOAD_FOLDER'], exist_ok=True)
os.makedirs('static', exist_ok=True)

USERNAME = '$STORAGE_USERNAME'
PASSWORD_HASH = '$STORAGE_PASSWORD_HASH'

def login_required(f):
    @wraps(f)
    def decorated_function(*args, **kwargs):
        if 'logged_in' not in session:
            return redirect(url_for('login'))
        return f(*args, **kwargs)
    return decorated_function

@app.route('/login', methods=['GET', 'POST'])
def login():
    if request.method == 'POST':
        username = request.form.get('username')
        password = request.form.get('password')
        password_hash = hashlib.sha256(password.encode()).hexdigest()
        
        if username == USERNAME and password_hash == PASSWORD_HASH:
            session['logged_in'] = True
            return redirect(url_for('index'))
        return render_template('login.html', error='Неверный логин или пароль')
    
    if 'logged_in' in session:
        return redirect(url_for('index'))
    return render_template('login.html')

@app.route('/logout')
def logout():
    session.pop('logged_in', None)
    return redirect(url_for('login'))

@app.route('/')
@login_required
def index():
    return render_template('index.html')

@app.route('/favicon.ico')
def favicon():
    return send_from_directory('static', 'favicon.svg', mimetype='image/svg+xml')

@app.route('/static/<path:filename>')
def serve_static(filename):
    return send_from_directory('static', filename)

@app.route('/api/files', methods=['GET'])
@login_required
def get_files():
    path = request.args.get('path', '')
    full_path = os.path.join(app.config['UPLOAD_FOLDER'], path)
    
    if not os.path.exists(full_path):
        return jsonify({'error': 'Path not found'}), 404
    
    items = []
    for item in os.listdir(full_path):
        item_path = os.path.join(full_path, item)
        relative_path = os.path.join(path, item)
        
        stat = os.stat(item_path)
        items.append({
            'name': item,
            'path': relative_path,
            'is_dir': os.path.isdir(item_path),
            'size': stat.st_size if not os.path.isdir(item_path) else 0,
            'modified': datetime.fromtimestamp(stat.st_mtime).strftime('%Y-%m-%d %H:%M:%S')
        })
    
    return jsonify({'items': sorted(items, key=lambda x: (not x['is_dir'], x['name']))})

@app.route('/api/upload', methods=['POST'])
@login_required
def upload_file():
    if 'file' not in request.files:
        return jsonify({'error': 'No file'}), 400
    
    file = request.files['file']
    path = request.form.get('path', '')
    
    if file.filename == '':
        return jsonify({'error': 'No filename'}), 400
    
    filename = secure_filename(file.filename)
    upload_path = os.path.join(app.config['UPLOAD_FOLDER'], path)
    os.makedirs(upload_path, exist_ok=True)
    
    file.save(os.path.join(upload_path, filename))
    return jsonify({'success': True})

@app.route('/api/create_folder', methods=['POST'])
@login_required
def create_folder():
    data = request.json
    path = data.get('path', '')
    folder_name = secure_filename(data.get('name', ''))
    
    if not folder_name:
        return jsonify({'error': 'Invalid folder name'}), 400
    
    folder_path = os.path.join(app.config['UPLOAD_FOLDER'], path, folder_name)
    os.makedirs(folder_path, exist_ok=True)
    
    return jsonify({'success': True})

@app.route('/api/delete', methods=['POST'])
@login_required
def delete_item():
    data = request.json
    path = data.get('path', '')
    
    full_path = os.path.join(app.config['UPLOAD_FOLDER'], path)
    
    if not os.path.exists(full_path):
        return jsonify({'error': 'Not found'}), 404
    
    if os.path.isdir(full_path):
        shutil.rmtree(full_path)
    else:
        os.remove(full_path)
    
    return jsonify({'success': True})

@app.route('/api/download/<path:filepath>')
@login_required
def download_file(filepath):
    full_path = os.path.join(app.config['UPLOAD_FOLDER'], filepath)
    
    if not os.path.exists(full_path) or os.path.isdir(full_path):
        return jsonify({'error': 'File not found'}), 404
    
    return send_file(full_path, as_attachment=True)

@app.route('/api/storage_info')
@login_required
def storage_info():
    total, used, free = shutil.disk_usage('/')
    
    upload_size = 0
    for dirpath, dirnames, filenames in os.walk(app.config['UPLOAD_FOLDER']):
        for filename in filenames:
            filepath = os.path.join(dirpath, filename)
            upload_size += os.path.getsize(filepath)
    
    return jsonify({
        'total': total,
        'used': used,
        'free': free,
        'upload_size': upload_size
    })

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=False)
EOFAPPPY

# Создание архива БЕЗ app.py
tar -czf /tmp/ruby-storage-base.tar.gz \
    --exclude='venv' \
    --exclude='uploads' \
    --exclude='.git' \
    --exclude='*.pyc' \
    --exclude='app.py' \
    .

# Распаковываем базовый архив во временную директорию
mkdir -p /tmp/ruby-deploy
cd /tmp/ruby-deploy
tar -xzf /tmp/ruby-storage-base.tar.gz

# Копируем модифицированный app.py
cp /tmp/app.py ./app.py

# Создаём финальный архив
tar -czf /tmp/ruby-storage.tar.gz .

# Очистка
cd "$PROJECT_DIR"
rm -rf /tmp/ruby-deploy
rm /tmp/ruby-storage-base.tar.gz

# Копирование на сервер
scp_remote /tmp/ruby-storage.tar.gz "$INSTALL_DIR/"
run_remote "cd $INSTALL_DIR && tar -xzf ruby-storage.tar.gz && rm ruby-storage.tar.gz"

# ВАЖНО: Проверяем что app.py правильно создался
echo -e "${YELLOW}  Проверка app.py на сервере...${NC}"
APP_CHECK=$(run_remote "[ -f '$INSTALL_DIR/app.py' ] && wc -l < '$INSTALL_DIR/app.py' || echo '0'")

if [ "$APP_CHECK" -gt "10" ]; then
    echo -e "${GREEN}  ✓ app.py найден ($APP_CHECK строк)${NC}"
else
    echo -e "${RED}  ✗ app.py не найден или пустой!${NC}"
    echo -e "${YELLOW}  Создаю app.py напрямую на сервере...${NC}"
    
    # Создаём app.py напрямую на сервере если что-то пошло не так
    run_remote "cat > $INSTALL_DIR/app.py << 'EOFREMOTEAPP'
from flask import Flask, render_template, request, jsonify, send_file, session, redirect, url_for, send_from_directory
from werkzeug.utils import secure_filename
import os
import shutil
import hashlib
from datetime import datetime
from functools import wraps

app = Flask(__name__)
app.secret_key = 'ruby_secret_key_change_in_production'
app.config['UPLOAD_FOLDER'] = 'uploads'
app.config['MAX_CONTENT_LENGTH'] = 16 * 1024 * 1024 * 1024

os.makedirs(app.config['UPLOAD_FOLDER'], exist_ok=True)
os.makedirs('static', exist_ok=True)

USERNAME = '$STORAGE_USERNAME'
PASSWORD_HASH = '$STORAGE_PASSWORD_HASH'

def login_required(f):
    @wraps(f)
    def decorated_function(*args, **kwargs):
        if 'logged_in' not in session:
            return redirect(url_for('login'))
        return f(*args, **kwargs)
    return decorated_function

@app.route('/login', methods=['GET', 'POST'])
def login():
    if request.method == 'POST':
        username = request.form.get('username')
        password = request.form.get('password')
        password_hash = hashlib.sha256(password.encode()).hexdigest()
        
        if username == USERNAME and password_hash == PASSWORD_HASH:
            session['logged_in'] = True
            return redirect(url_for('index'))
        return render_template('login.html', error='Неверный логин или пароль')
    
    if 'logged_in' in session:
        return redirect(url_for('index'))
    return render_template('login.html')

@app.route('/logout')
def logout():
    session.pop('logged_in', None)
    return redirect(url_for('login'))

@app.route('/')
@login_required
def index():
    return render_template('index.html')

@app.route('/favicon.ico')
def favicon():
    return send_from_directory('static', 'favicon.svg', mimetype='image/svg+xml')

@app.route('/static/<path:filename>')
def serve_static(filename):
    return send_from_directory('static', filename)

@app.route('/api/files', methods=['GET'])
@login_required
def get_files():
    path = request.args.get('path', '')
    full_path = os.path.join(app.config['UPLOAD_FOLDER'], path)
    
    if not os.path.exists(full_path):
        return jsonify({'error': 'Path not found'}), 404
    
    items = []
    for item in os.listdir(full_path):
        item_path = os.path.join(full_path, item)
        relative_path = os.path.join(path, item)
        
        stat = os.stat(item_path)
        items.append({
            'name': item,
            'path': relative_path,
            'is_dir': os.path.isdir(item_path),
            'size': stat.st_size if not os.path.isdir(item_path) else 0,
            'modified': datetime.fromtimestamp(stat.st_mtime).strftime('%Y-%m-%d %H:%M:%S')
        })
    
    return jsonify({'items': sorted(items, key=lambda x: (not x['is_dir'], x['name']))})

@app.route('/api/upload', methods=['POST'])
@login_required
def upload_file():
    if 'file' not in request.files:
        return jsonify({'error': 'No file'}), 400
    
    file = request.files['file']
    path = request.form.get('path', '')
    
    if file.filename == '':
        return jsonify({'error': 'No filename'}), 400
    
    filename = secure_filename(file.filename)
    upload_path = os.path.join(app.config['UPLOAD_FOLDER'], path)
    os.makedirs(upload_path, exist_ok=True)
    
    file.save(os.path.join(upload_path, filename))
    return jsonify({'success': True})

@app.route('/api/create_folder', methods=['POST'])
@login_required
def create_folder():
    data = request.json
    path = data.get('path', '')
    folder_name = secure_filename(data.get('name', ''))
    
    if not folder_name:
        return jsonify({'error': 'Invalid folder name'}), 400
    
    folder_path = os.path.join(app.config['UPLOAD_FOLDER'], path, folder_name)
    os.makedirs(folder_path, exist_ok=True)
    
    return jsonify({'success': True})

@app.route('/api/delete', methods=['POST'])
@login_required
def delete_item():
    data = request.json
    path = data.get('path', '')
    
    full_path = os.path.join(app.config['UPLOAD_FOLDER'], path)
    
    if not os.path.exists(full_path):
        return jsonify({'error': 'Not found'}), 404
    
    if os.path.isdir(full_path):
        shutil.rmtree(full_path)
    else:
        os.remove(full_path)
    
    return jsonify({'success': True})

@app.route('/api/download/<path:filepath>')
@login_required
def download_file(filepath):
    full_path = os.path.join(app.config['UPLOAD_FOLDER'], filepath)
    
    if not os.path.exists(full_path) or os.path.isdir(full_path):
        return jsonify({'error': 'File not found'}), 404
    
    return send_file(full_path, as_attachment=True)

@app.route('/api/storage_info')
@login_required
def storage_info():
    total, used, free = shutil.disk_usage('/')
    
    upload_size = 0
    for dirpath, dirnames, filenames in os.walk(app.config['UPLOAD_FOLDER']):
        for filename in filenames:
            filepath = os.path.join(dirpath, filename)
            upload_size += os.path.getsize(filepath)
    
    return jsonify({
        'total': total,
        'used': used,
        'free': free,
        'upload_size': upload_size
    })

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=False)
EOFREMOTEAPP
"
fi

# Проверяем templates
run_remote "ls -la $INSTALL_DIR/templates/ 2>/dev/null || echo 'Templates missing!'"

rm /tmp/ruby-storage.tar.gz
rm /tmp/app.py

# Шаг 6: Обновление системы
echo -e "${BLUE}[2/8] Обновление системы...${NC}"
run_remote "apt update && apt upgrade -y" > /dev/null 2>&1
echo -e "${GREEN}✓ Система обновлена${NC}\n"

# Шаг 7: Установка зависимостей
echo -e "${BLUE}[3/8] Установка зависимостей...${NC}"

# Остановка существующих веб-серверов
echo -e "${YELLOW}  Проверка запущенных веб-серверов...${NC}"
run_remote "systemctl stop nginx 2>/dev/null || true"
run_remote "systemctl stop apache2 2>/dev/null || true"
run_remote "systemctl stop httpd 2>/dev/null || true"

# Проверка и освобождение портов 80 и 443
run_remote "fuser -k 80/tcp 2>/dev/null || true"
run_remote "fuser -k 443/tcp 2>/dev/null || true"

if [ "$USE_EXISTING_SSL" = false ]; then
    run_remote "DEBIAN_FRONTEND=noninteractive apt install -y python3 python3-pip python3-venv nginx certbot python3-certbot-nginx" > /dev/null 2>&1
else
    run_remote "DEBIAN_FRONTEND=noninteractive apt install -y python3 python3-pip python3-venv nginx" > /dev/null 2>&1
fi
echo -e "${GREEN}✓ Зависимости установлены${NC}\n"

# Шаг 8: Создание виртуального окружения
echo -e "${BLUE}[4/8] Настройка Python окружения...${NC}"
run_remote "cd $INSTALL_DIR && python3 -m venv venv && source venv/bin/activate && pip install --upgrade pip > /dev/null 2>&1 && pip install -r requirements.txt > /dev/null 2>&1"
run_remote "mkdir -p $INSTALL_DIR/uploads"
echo -e "${GREEN}✓ Python окружение настроено${NC}\n"

# Шаг 9: Создание systemd сервиса
echo -e "${BLUE}[5/8] Создание systemd сервиса...${NC}"
run_remote 'cat > /etc/systemd/system/ruby-storage.service << "EOFSERVICE"
[Unit]
Description=Ruby Storage Application
After=network.target

[Service]
User=root
WorkingDirectory='"$INSTALL_DIR"'
Environment="PATH='"$INSTALL_DIR"'/venv/bin"
ExecStart='"$INSTALL_DIR"'/venv/bin/gunicorn --workers 4 --bind 127.0.0.1:5000 app:app

[Install]
WantedBy=multi-user.target
EOFSERVICE'
echo -e "${GREEN}✓ Сервис создан${NC}\n"

# Шаг 10: Настройка Nginx
echo -e "${BLUE}[6/8] Настройка Nginx...${NC}"
run_remote "systemctl stop nginx 2>/dev/null || true"

if [ "$USE_EXISTING_SSL" = true ]; then
    run_remote 'cat > /etc/nginx/sites-available/ruby-storage << "EOFNGINX"
server {
    listen 80;
    server_name '"$DOMAIN"';
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name '"$DOMAIN"';

    ssl_certificate '"$SSL_CERT_PATH"';
    ssl_certificate_key '"$SSL_KEY_PATH"';
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;

    client_max_body_size 16G;

    location / {
        proxy_pass http://127.0.0.1:5000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_read_timeout 300s;
        proxy_connect_timeout 300s;
    }
}
EOFNGINX'
else
    run_remote 'cat > /etc/nginx/sites-available/ruby-storage << "EOFNGINX"
server {
    listen 80;
    server_name '"$DOMAIN"';

    client_max_body_size 16G;

    location / {
        proxy_pass http://127.0.0.1:5000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_read_timeout 300s;
        proxy_connect_timeout 300s;
    }
}
EOFNGINX'
fi

run_remote "rm -f /etc/nginx/sites-enabled/*"
run_remote "ln -sf /etc/nginx/sites-available/ruby-storage /etc/nginx/sites-enabled/"

if run_remote "nginx -t" 2>&1 | grep -q "successful"; then
    echo -e "${GREEN}✓ Nginx настроен${NC}\n"
else
    echo -e "${RED}✗ Ошибка конфигурации Nginx${NC}"
    run_remote "nginx -t"
    exit 1
fi

# Шаг 11: SSL сертификат
if [ "$USE_EXISTING_SSL" = false ]; then
    echo -e "${BLUE}[7/8] Получение SSL сертификата...${NC}"
    
    # Запуск Nginx для certbot
    run_remote "systemctl start nginx"
    sleep 2
    
    # Проверка что домен указывает на сервер
    echo -e "${YELLOW}  Проверка DNS записи для $DOMAIN...${NC}"
    DOMAIN_IP=$(dig +short $DOMAIN | tail -n1)
    
    if [ "$DOMAIN_IP" != "$SERVER_IP" ]; then
        echo -e "${YELLOW}  ⚠ Внимание: Домен $DOMAIN указывает на $DOMAIN_IP, а не на $SERVER_IP${NC}"
        echo -e "${YELLOW}  Certbot может не пройти валидацию. Убедитесь что DNS настроен правильно.${NC}"
        
        if ! input_yes_no "Продолжить получение сертификата?" "yes"; then
            echo -e "${YELLOW}  Пропуск получения SSL сертификата${NC}\n"
        else
            run_remote "certbot --nginx -d $DOMAIN --non-interactive --agree-tos -m $LETSENCRYPT_EMAIL --redirect" 2>&1 | grep -v "Saving debug log"
        fi
    else
        echo -e "${GREEN}  ✓ DNS настроен правильно${NC}"
        run_remote "certbot --nginx -d $DOMAIN --non-interactive --agree-tos -m $LETSENCRYPT_EMAIL --redirect" 2>&1 | grep -v "Saving debug log"
    fi
    
    echo -e "${GREEN}✓ SSL процесс завершен${NC}\n"
else
    echo -e "${BLUE}[7/8] Использование существующего SSL...${NC}"
    echo -e "${GREEN}✓ SSL настроен${NC}\n"
fi

# Шаг 12: Запуск сервисов
echo -e "${BLUE}[8/8] Запуск сервисов...${NC}"
run_remote "systemctl daemon-reload && systemctl enable ruby-storage && systemctl restart ruby-storage"

# Перезапуск Nginx
run_remote "systemctl restart nginx"

# Проверка статуса сервисов
if run_remote "systemctl is-active ruby-storage" | grep -q "active"; then
    echo -e "${GREEN}  ✓ Ruby Storage запущен${NC}"
else
    echo -e "${RED}  ✗ Ruby Storage не запустился${NC}"
    echo -e "${YELLOW}  Логи: ${NC}"
    run_remote "journalctl -u ruby-storage -n 20 --no-pager"
fi

if run_remote "systemctl is-active nginx" | grep -q "active"; then
    echo -e "${GREEN}  ✓ Nginx запущен${NC}"
else
    echo -e "${RED}  ✗ Nginx не запустился${NC}"
    echo -e "${YELLOW}  Логи: ${NC}"
    run_remote "nginx -t"
fi

# Настройка firewall
if run_remote "command -v ufw" > /dev/null 2>&1; then
    run_remote "ufw --force allow 'Nginx Full' && ufw --force allow OpenSSH && ufw --force enable" > /dev/null 2>&1
fi

echo -e "${GREEN}✓ Сервисы запущены${NC}\n"

# Финальное сообщение
clear
echo -e "${PURPLE}${BOLD}"
cat << "EOF"
╔════════════════════════════════════════════════════════════════╗
║                                                                ║
║                   ✓ Установка завершена!                      ║
║                                                                ║
╚════════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}\n"

echo -e "${CYAN}${BOLD}Ваше файлохранилище доступно по адресу:${NC}"
echo -e "${GREEN}${BOLD}    https://$DOMAIN${NC}\n"

echo -e "${CYAN}${BOLD}Данные для входа:${NC}"
echo -e "    ${YELLOW}Логин:${NC} $STORAGE_USERNAME"
echo -e "    ${YELLOW}Пароль:${NC} $STORAGE_PASSWORD\n"

echo -e "${PURPLE}${BOLD}⚠ ВАЖНО: Сохраните эти данные в безопасном месте!${NC}\n"

echo -e "${CYAN}${BOLD}Полезные команды для управления:${NC}"
echo -e "    ${BLUE}# Подключение к серверу:${NC}"
echo -e "    ssh -p $SSH_PORT $SERVER_USER@$SERVER_IP\n"
echo -e "    ${BLUE}# Статус сервиса:${NC}"
echo -e "    systemctl status ruby-storage\n"
echo -e "    ${BLUE}# Перезапуск:${NC}"
echo -e "    systemctl restart ruby-storage\n"
echo -e "    ${BLUE}# Просмотр логов:${NC}"
echo -e "    journalctl -u ruby-storage -f\n"
echo -e "    ${BLUE}# Изменить пароль:${NC}"
echo -e "    nano $INSTALL_DIR/app.py\n"

echo -e "${GREEN}${BOLD}Готово! 💎${NC}\n"
